#include "Sketch_circle_ellipse_lt10.fxh"
#include "Sketch_ellipse10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_type_line10.fxh"

float get_ellipse_curve_dist_to_angle_0(float angle, float2 radius)
{
    while (angle >= TWO_PI)
        angle -= TWO_PI;

    float arc_len = 0.0f;

    float l_radius = max(radius.x, radius.y);

    float d_angle = 0.5f / l_radius;

    float a2 = radius.x * radius.x;
    float b2 = radius.y * radius.y;


    float cur_angle = 0.0f;

    for (cur_angle = 0.0f; cur_angle < angle; cur_angle += d_angle)
    {
        float s, c;
        sincos(cur_angle, s, c);

        arc_len += sqrt(a2 * s * s + b2 * c * c) * d_angle;
    }

    return arc_len;
}

void compute_ellipse_distance(float2 range, float2 radius, out float2 dist)
{
    if (is_closed_arc(range))
    {
        dist.x = 0.0f;
        dist.y = get_ellipse_curve_dist_to_angle_0(TWO_PI, radius);
    }
    else
    {
        dist.x = get_ellipse_curve_dist_to_angle_0(range.x, radius);
        dist.y = get_ellipse_curve_dist_to_angle_0(range.y, radius);
    }
}

// line type ellipse index texture
Texture2D<uint>   gEllipseLineTypeIndexTex : EllipseLineTypeIndexTexture;

// line type ellipse draw order texture for retain mode
Texture2D<float> gEllipticalArcLineTypeDashDrawOrderZTex : EllipticalArcLineTypeDashDrawOrderZTex;

uint load_lt_ellipse_prim_id(uint id)
{
    return load_prim_id_from_tex(gEllipseLineTypeIndexTex, id);
}

void Ellipse_Line_Type_VS(NullVertex_Input input, out VertexAttr_Ellipse verAttr_Ellipse, out VertexAttr_LineType_Arc verAttr_Linetype, out VertexAttr_LineType_DIST verAttr_Dist)
{
    // load primitive index
    uint primID = load_lt_ellipse_prim_id(input.InstanceID);

    // load ellipse information
    EllipseAttr_Dash ellipse_attr;
    EllipseAttr_LineType linetype_attr;
    load_ellipse_info_lt(primID, ellipse_attr, linetype_attr);

    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(input.InstanceID, gEllipticalArcLineTypeDashDrawOrderZTex, ellipse_attr.drawZ);
    }
    else
    {
        adjust_ellipse(ellipse_attr);
    }

    verAttr_Ellipse = output_vertex_attr_ellipse(input, ellipse_attr);

    // Merge lt_index and lt_dot
    if (linetype_attr.lt_dot > 0)
        linetype_attr.lt_index = linetype_attr.lt_index | PURE_DOT_MASK;

    // load linetype information
    float startSkipLen, endSkipLen, patternOffset, patternScale;
    load_line_type(primID, ellipse_attr.isLogical & linetype_attr.lt_logical, startSkipLen, endSkipLen, patternOffset, patternScale);
    set_line_type_properties(linetype_attr, float4(startSkipLen, endSkipLen, patternOffset, patternScale), verAttr_Linetype);

    verAttr_Dist.dist = float2(0, 0);
    // compute ellipse distance when radius rate > 10.0f
    if ((verAttr_Ellipse.radius.x / verAttr_Ellipse.radius.y > 10.0f) ||
        (verAttr_Ellipse.radius.y / verAttr_Ellipse.radius.x > 10.0f))
        compute_ellipse_distance(verAttr_Ellipse.range, verAttr_Ellipse.radius, verAttr_Dist.dist);
}

Texture2D<float> gEllipseDistTex : EllipseDistTexure;

static const uint ANGLE_NUM = 4096;
static const uint RATE_NUM = 1024;

float get_ellipse_angle_distance_tex(float angle, float rate)
{
    float angle_step = HALF_PI / (ANGLE_NUM - 1);
    float angle_val = angle / angle_step;

    uint angle_index = (uint)angle_val;
    float angle_bias = angle_val - float(angle_index);

    //float rate_val = (rate - 1.0f)/rate*RATE_NUM;
    float rate_val = (rate - 1.0f) / 0.01f;

    uint rate_index = (uint)rate_val;
    float rate_bias = rate_val - float(rate_index);

    uint prev_angle, post_angle;

    if (angle_index >= ANGLE_NUM - 1)
    {
        prev_angle = angle_index;
        post_angle = angle_index;
        angle_bias = 0.0f;
    }
    else
    {
        prev_angle = angle_index;
        post_angle = angle_index + 1;
    }

    uint prev_rate, post_rate;
    if (rate_index >= RATE_NUM - 1)
    {
        prev_rate = rate_index;
        post_rate = rate_index;
        rate_bias = 0.0f;
    }
    else
    {
        prev_rate = rate_index;
        post_rate = rate_index + 1;
    }

    float prev_val0 = gEllipseDistTex.Load(int3(prev_angle, prev_rate, 0));
    float prev_val1 = gEllipseDistTex.Load(int3(prev_angle, post_rate, 0));

    float prev_val = lerp(prev_val0, prev_val1, rate_bias);

    float post_val0 = gEllipseDistTex.Load(int3(post_angle, prev_rate, 0));
    float post_val1 = gEllipseDistTex.Load(int3(post_angle, post_rate, 0));

    float post_val = lerp(post_val0, post_val1, rate_bias);

    return lerp(prev_val, post_val, angle_bias);
}

float get_ellipse_circum_div_4(float2 radius)
{
    bool horiz_ellipse = (radius.x >= radius.y);

    float rate;
    if (horiz_ellipse)
    {
        rate = radius.x / radius.y;
    }
    else
    {
        rate = radius.y / radius.x;
    }

    float dist = get_ellipse_angle_distance_tex(HALF_PI, rate);


    if (horiz_ellipse)
    {
        dist = dist * radius.y;
    }
    else
    {
        dist = dist * radius.x;
    }

    return dist;
}

float get_ellipse_cur_dist_to_angle_0_tex(float angle, float2 radius, float circum_div_4)
{
    while (angle >= TWO_PI)
        angle -= TWO_PI;

    // transform to uniform space
    bool horiz_ellipse = (radius.x >= radius.y);

    float org_angle = angle;

    float rate;
    if (horiz_ellipse)
    {
        rate = radius.x / radius.y;

        if (angle >= ONE_HALF_PI)
        {
            angle = TWO_PI - angle;
        }
        else if (angle >= PI)
        {
            angle = angle - PI;
        }
        else if (angle >= HALF_PI)
        {
            angle = PI - angle;
        }
    }
    else
    {
        rate = radius.y / radius.x;

        if (angle >= ONE_HALF_PI)
        {
            angle = angle - ONE_HALF_PI;
        }
        else if (angle >= PI)
        {
            angle = ONE_HALF_PI - angle;
        }
        else if (angle >= HALF_PI)
        {
            angle = angle - HALF_PI;
        }
        else
        {
            angle = HALF_PI - angle;
        }
    }

    float dist = get_ellipse_angle_distance_tex(angle, rate);

    // transform back to screen space
    if (horiz_ellipse)
    {
        dist = dist * radius.y;

        if (org_angle >= ONE_HALF_PI)
        {
            dist = circum_div_4 * 4.0f - dist;
        }
        else if (org_angle >= PI)
        {
            dist = circum_div_4 * 2.0f + dist;
        }
        else if (org_angle >= HALF_PI)
        {
            dist = circum_div_4 * 2.0f - dist;
        }
    }
    else
    {
        dist = dist * radius.x;

        if (org_angle >= ONE_HALF_PI)
        {
            dist = circum_div_4 * 3.0f + dist;
        }
        else if (org_angle >= PI)
        {
            dist = circum_div_4 * 3.0f - dist;
        }
        else if (org_angle >= HALF_PI)
        {
            dist = circum_div_4 + dist;
        }
        else
        {
            dist = circum_div_4 - dist;
        }
    }

    return dist;
}

float func(float s, float c, float r_a, float r_a2, float2 uv)
{
    return -r_a * uv.x * s + uv.y * c + (r_a2 - 1.0f) * s * c;
}

float compute_point_angle(float px, float py, float r_a)
{

    float angle = atan2(py, px / r_a);

    if (angle < 0.0)
        angle = 0.0;
    if (angle > HALF_PI)
        angle = HALF_PI;

    return angle;
}

float ellipse_distance_precise_uniform(float radius, float2 uv, out bool needAdjust)
{
    needAdjust = false;

    float r_a = radius;
    float r_a2 = r_a * r_a; // a^2

    float r_c2 = r_a2 - 1.0f;
    float r_c = sqrt(r_c2);

    float u2 = uv.x * uv.x;
    float v2 = uv.y * uv.y;

    // on y-axis
    if (abs(uv.x) < EPS)
    {
        return HALF_PI;
    }

    // on x-axis
    if (abs(uv.y) < EPS)
    {
        if (uv.x > r_a - 1.0 / r_a)
        {
            return 0.0f;
        }

        return acos(uv.x * r_a / (r_a2 - 1.0));
    }

    float uv_dist = u2 / r_a2 + v2;

    // point on the ellipse
    if (abs(uv_dist - 1.0) < 0.00001f)
    {
        needAdjust = true;
        return atan2(uv.y, uv.x / r_a);
    }

    // compute intersect point from origin to ellipse
    float o_len_rcp = rsqrt(u2 + r_a2 * v2);
    float o_x = uv.x * r_a * o_len_rcp;
    float o_y = uv.y * r_a * o_len_rcp;

    float angle_o = compute_point_angle(o_x, o_y, r_a);

    // compute intersect point between line x = u and ellipse
    float l_x;
    float l_y;

    if (uv.x < r_a)
    {
        l_x = uv.x;
        l_y = sqrt(r_a2 - u2) / r_a;
    }
    else
    {
        l_x = r_a;
        l_y = 0;
    }
    float angle_l = compute_point_angle(l_x, l_y, r_a);

    // compute intersec point from (c, 0) to elllipse
    float param_A = ((uv.x - r_c) * (uv.x - r_c) + r_a2 * uv.y * uv.y);
    float param_B = 2.0 * r_c * (uv.x - r_c);
    float param_C = -1.0;

    float b2_4ac = param_B * param_B - 4.0 * param_A * param_C;
    float t = (-param_B + sqrt(b2_4ac)) / (2.0 * param_A);

    float p_x = r_c + t * (uv.x - r_c);
    float p_y = t * uv.y;

    float angle_c = compute_point_angle(p_x, p_y, r_a);

    // choose the smallest range
    float max_angle;
    float min_angle;

    float max_x, max_y;
    float min_x, min_y;

    if (uv_dist < 1.0) // inside ellipse
    {
        min_angle = angle_o;
        min_x = o_x;
        min_y = o_y;

        if (angle_l < angle_c)
        {
            max_angle = angle_l;

            max_x = l_x;
            max_y = l_y;
        }
        else
        {
            max_angle = angle_c;

            max_x = p_x;
            max_y = p_y;
        }
    }
    else
    {
        max_angle = angle_o;
        max_x = o_x;
        max_y = o_y;

        if (angle_l > angle_c)
        {
            min_angle = angle_l;

            min_x = l_x;
            min_y = l_y;
        }
        else
        {
            min_angle = angle_c;

            min_x = p_x;
            min_y = p_y;
        }
    }

    if (abs(max_angle - min_angle) < EPS)
    {
        return max_angle;
    }

    float cur_angle;

    float diff = 999999.0f;

    static const uint MAX_ANGLE_STEP = 128;
    uint count = 0;

    float sin_max, cos_max;
    sincos(max_angle, sin_max, cos_max);

    float sin_min, cos_min;
    sincos(min_angle, sin_min, cos_min);

    float f_max = func(sin_max, cos_max, r_a, r_a2, uv);
    float f_min = func(sin_min, cos_min, r_a, r_a2, uv);

    float test_x = 0.0f;
    float test_y = 0.0f;

    while (abs(diff) > 0.001f)
    {
        float delta_x = max_x - min_x;
        float delta_y = max_y - min_y;
        float delta_len_rcp = rsqrt(delta_x * delta_x + delta_y * delta_y);

        float dir_x = delta_x * delta_len_rcp;
        float dir_y = delta_y * delta_len_rcp;

        float nrm_x = -dir_y;
        float nrm_y = dir_x;

        float test_angle = atan2(nrm_y / (-r_a), -nrm_x);

        if ((test_angle > max_angle - EPS) || (test_angle < min_angle + EPS))
        {
            test_angle = (max_angle + min_angle) * 0.5f;
        }

        float sin_test, cos_test;
        sincos(test_angle, sin_test, cos_test);

        float test_x = r_a * cos_test;
        float test_y = sin_test;

        float test_delta_x = uv.x - test_x;
        float test_delta_y = uv.y - test_y;
        float test_delta_len_rcp = rsqrt(test_delta_x * test_delta_x + test_delta_y * test_delta_y);

        float tan_test_x = -r_a * sin_test;
        float tan_test_y = cos_test;
        float tan_test_len_rcp = rsqrt(tan_test_x * tan_test_x + tan_test_y * tan_test_y);

        float tan_x = tan_test_x * tan_test_len_rcp;
        float tan_y = tan_test_y * tan_test_len_rcp;

        float f_test = func(sin_test, cos_test, r_a, r_a2, uv);

        cur_angle = test_angle;
        diff = test_delta_x * test_delta_len_rcp * tan_x + test_delta_y * test_delta_len_rcp * tan_y;

        count++;

        if (count > MAX_ANGLE_STEP)
        {
            break;
        }

        if (sign(f_test) != sign(f_min))
        {

            max_angle = test_angle;

            max_x = test_x;
            max_y = test_y;

            f_max = f_test;
        }
        else if (sign(f_test) != sign(f_max))
        {
            min_angle = test_angle;

            min_x = test_x;
            min_y = test_y;

            f_min = f_test;

        }
        else
        {
            float f_final_min = min(abs(f_test), min(abs(f_max), abs(f_min)));

            if (f_final_min == abs(f_test))
                return test_angle;
            else if (f_final_min == abs(f_max))
                return max_angle;
            else
                return min_angle;
        }
    }

    return cur_angle;
}

float ellipse_distance_precise3(float2 radius, float2 uv, out bool needAdjust)
{
    float hit_angle = 0.0f;

    // transform to uniform space
    bool horiz_ellipse = (radius.x >= radius.y);

    float radius_a;
    float2 new_uv;

    if (horiz_ellipse)
    {
        radius_a = radius.x / radius.y;
        new_uv = abs(uv / radius.y);
    }
    else
    {
        radius_a = radius.y / radius.x;

        new_uv = abs(uv / radius.x);
        new_uv = float2(new_uv.y, new_uv.x);
    }

    float new_hit_angle = ellipse_distance_precise_uniform(radius_a, new_uv, needAdjust);

    // transform back from uniform space
    if (horiz_ellipse)
    {
        if (uv.x >= 0.0f)
        {
            if (uv.y < 0.0f)
            {
                hit_angle = TWO_PI - new_hit_angle;
            }
            else
            {
                hit_angle = new_hit_angle;
            }
        }
        else
        {
            if (uv.y < 0.0f)
            {
                hit_angle = new_hit_angle + PI;
            }
            else
            {
                hit_angle = PI - new_hit_angle;
            }
        }
    }
    else
    {
        if (uv.x >= 0.0f)
        {
            if (uv.y < 0.0f)
            {
                hit_angle = ONE_HALF_PI + new_hit_angle;
            }
            else
            {
                hit_angle = HALF_PI - new_hit_angle;
            }
        }
        else
        {
            if (uv.y < 0.0f)
            {
                hit_angle = ONE_HALF_PI - new_hit_angle;
            }
            else
            {
                hit_angle = HALF_PI + new_hit_angle;
            }
        }
    }

    return hit_angle;
}

OIT_PS_HEADER_3(Ellipse_Line_Type_PS, VertexAttr_Ellipse, VertexAttr_LineType_Arc, VertexAttr_LineType_DIST)
{
    // get current angle on ellipse 
    bool needAdjust = false;
    float cur_angle = ellipse_distance_precise3(input.radius, input.uv, needAdjust);

    // compute distance to ellipse
    float sin_angle, cos_angle;
    sincos(cur_angle, sin_angle, cos_angle);

    float pos_x = input.radius.x * cos_angle;
    float pos_y = input.radius.y * sin_angle;

    float dist = length(input.uv - float2(pos_x, pos_y));

    // if above distance is not accurate, we need to adjust it with another method
    if (needAdjust)
    {
        dist = ellipse_distance(input.radius, input.uv);
    }

    // check if ellipse is in arc range
    if (!angle_is_in_range(cur_angle, input.range))
        discard;

    [branch] if (gNoAAMode != 0)
    {
        if (!in_lw_ellipse(input.weight, dist) && not_in_ellipse(input))
            discard;
    }

    // linetype
    bool is_dot;
    bool no_aa;
    float dot_dist;

    float dist_to_start;
    float dist_to_end;

    // compute ellipse distance
    float circum_div_4 = get_ellipse_circum_div_4(input.radius);
    float cur_dist_to_0;

    // if ellipse ratio > 10, we are using integration.
    if ((input.radius.x / input.radius.y > 10.0f) ||
        (input.radius.y / input.radius.x > 10.0f))
    {
        cur_dist_to_0 = get_ellipse_curve_dist_to_angle_0(cur_angle, input.radius);

        if (input3.dist.x < input3.dist.y)
        {
            dist_to_start = cur_dist_to_0 - input3.dist.x;
            dist_to_end = input3.dist.y - cur_dist_to_0;
        }
        else
        {
            if (cur_dist_to_0 > input3.dist.x)
                dist_to_start = cur_dist_to_0 - input3.dist.x;
            else
                dist_to_start = circum_div_4 * 4.0f - input3.dist.x + cur_dist_to_0;

            if (cur_dist_to_0 > input3.dist.y)
                dist_to_end = circum_div_4 * 4.0f - cur_dist_to_0 + input3.dist.y;
            else
                dist_to_end = input3.dist.y - cur_dist_to_0;

        }
    }
    // else we are using table searching for better performance
    else
    {
        cur_dist_to_0 = get_ellipse_cur_dist_to_angle_0_tex(cur_angle, input.radius, circum_div_4);
        float start_dist_to_0 = get_ellipse_cur_dist_to_angle_0_tex(input.range.x, input.radius, circum_div_4);
        float end_dist_to_0 = get_ellipse_cur_dist_to_angle_0_tex(input.range.y, input.radius, circum_div_4);

        if (start_dist_to_0 < end_dist_to_0)
        {
            dist_to_start = cur_dist_to_0 - start_dist_to_0;
            dist_to_end = end_dist_to_0 - cur_dist_to_0;
        }
        else
        {
            if (cur_dist_to_0 > start_dist_to_0)
                dist_to_start = cur_dist_to_0 - start_dist_to_0;
            else
                dist_to_start = circum_div_4 * 4.0f - start_dist_to_0 + cur_dist_to_0;

            if (cur_dist_to_0 > end_dist_to_0)
                dist_to_end = circum_div_4 * 4.0f - cur_dist_to_0 + end_dist_to_0;
            else
                dist_to_end = end_dist_to_0 - cur_dist_to_0;
        }
    }

    // revert distance result if necessary
    if (input2.lt_inverted)
    {
        float tmp = dist_to_start;
        dist_to_start = dist_to_end;
        dist_to_end = tmp;
    }

    float4 color;

    // for wide arc
    if (input.weight > 1)
    {
        WideLinePatternResult left_attr;
        WideLinePatternResult right_attr;

        WideLinePatternAttr attr;
        attr.dist = dist;
        attr.width = input.weight;
        attr.startDist = dist_to_start;
        attr.endDist = dist_to_end;
        attr.startSkipLen = input2.patternProp.x;
        attr.endSkipLen = input2.patternProp.y;
        attr.patternScale = input2.patternProp.z;
        attr.patternOffset = input2.patternProp.w;
        attr.patternIndex = input2.patternIndex;

        WideEllipseInfo info;
        info.inverted = input2.lt_inverted;
        info.radius = input.radius;
        info.range = input.range;
        info.hasPrevLine = false;
        info.hasPostLine = false;
        info.isCircle = false;
        info.curAngle = cur_angle;

        int res = check_widearc_line_pattern(attr, info, glowWidth(),
            left_attr,
            right_attr);

        if (res == PURE_SPACE)
            discard;

        float width = adjust_line_width_wide_line(input.weight);

        if (res == PURE_DASH)
        {
            [branch] if (gNoAAMode != 0)
            {
#ifdef ANALYTIC_HIGHLIGHT
                bool in_sharp = in_lw_ellipse(width, dist) || !not_in_ellipse(input);
                color = compute_highlight_sharp_color(dist, width, input.color, input.glowColor, in_sharp);
#else
                color = get_formatted_color(input.color, 1.0f);
#endif
            }
            else
            {
                color = compute_final_color(dist, width, input.color, input.glowColor);
            }
        }
        else
        {
            float4 left_color;
            float4 right_color;

            [branch] if (gNoAAMode != 0)
            {
                left_color = compute_wide_pattern_color_sharp_curve(left_attr, width,
                    input.color, input.glowColor, input.uv, 2);

                right_color = compute_wide_pattern_color_sharp_curve(right_attr, width,
                    input.color, input.glowColor, input.uv, 2);;
            }
            else
            {
                left_color = compute_wide_pattern_color(left_attr, width,
                    input.color, input.glowColor, input.uv, 2);

                right_color = compute_wide_pattern_color(right_attr, width,
                    input.color, input.glowColor, input.uv, 2);;
            }


            color = (left_color.a >= right_color.a) ? left_color : right_color;

        }
    }
    // for single arc
    else
    {
        SimpleLineTypeAttr attr = (SimpleLineTypeAttr)0;
        attr.startDist = dist_to_start;
        attr.endDist = dist_to_end;
        attr.startSkipLen = input2.patternProp.x;
        attr.endSkipLen = input2.patternProp.y;
        attr.patternScale = input2.patternProp.z;
        attr.patternOffset = input2.patternProp.w;
        attr.patternID = input2.patternIndex;
        attr.isClosed = is_closed_arc(input.range);
        attr.isCurve = true;

        [branch] if (gNoAAMode != 0)
            attr.lineDir = ellipse_dir(input);

        SimpleLineTypeResult result;
        bool display = check_line_pattern(attr, result);

        if (!display)
            discard;

        if (result.isDot && !result.noDotAA)
        {
            float dist_to_dot_center = sqrt(dist * dist + result.dotDist * result.dotDist);

            [branch] if (gNoAAMode != 0)
            {
#ifdef ANALYTIC_HIGHLIGHT
                color = compute_highlight_sharp_color(get_extended_dist_to_center(dist_to_dot_center), get_extended_line_type_dot_weight(input.weight), input.color, input.glowColor, true);
#else
                color = get_formatted_color(input.color, 1.0f);
#endif
            }
            else
            {
                color = compute_final_color(get_extended_dist_to_center(dist_to_dot_center), get_extended_line_type_dot_weight(input.weight), input.color, input.glowColor);
            }
        }
        else
        {
            [branch] if (gNoAAMode != 0)
            {
#ifdef ANALYTIC_HIGHLIGHT
                color = compute_highlight_sharp_color(get_extended_dist_to_center(dist), get_extended_line_type_dot_weight(input.weight), input.color, input.glowColor, true);
#else
                color = get_formatted_color(input.color, 1.0f);
#endif
            }
            else
            {
                color = compute_final_color(get_extended_dist_to_center(dist), get_extended_line_weight(input.weight), input.color, input.glowColor);
            }
        }
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Ellipse_Line_Type
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Ellipse_Line_Type_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Ellipse_Line_Type_PS()));
    }
}

