#include "Sketch_circle10.fxh"
#include "Sketch_circle_ellipse_lt10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_type_line10.fxh"

// line type circle index texture
Texture2D<uint>  gCircleLineTypeIndexTex : CircleLineTypeIndexTex;

// line type circle draw order texture
Texture2D<float> gCircleLineTypeDrawOrderZTex : CircleLineTypeDrawOrderZTex;

void Circle_Line_Type_VS(NullVertex_Input input, out VertexAttr_Ellipse verAttr_Ellipse, out VertexAttr_LineType_Arc verAttr_Linetype)
{
    // load primitive index
    uint primID = load_prim_id_from_tex(gCircleLineTypeIndexTex, input.InstanceID);

    // load ellipse information
    EllipseAttr_Dash ellipse_attr;
    EllipseAttr_LineType linetype_attr;
    load_ellipse_info_lt(primID, ellipse_attr, linetype_attr);

    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(input.InstanceID, gCircleLineTypeDrawOrderZTex, ellipse_attr.drawZ);
    }
    else
    {
        adjust_circle(ellipse_attr);
    }

    adjust_circle_range(ellipse_attr.range, ellipse_attr.rotate);

    verAttr_Ellipse = output_vertex_attr_ellipse(input, ellipse_attr);

    // Merge lt_index and lt_dot
    if (linetype_attr.lt_dot > 0)
        linetype_attr.lt_index = linetype_attr.lt_index | PURE_DOT_MASK;

    // load linetype information
    float startSkipLen, endSkipLen, patternOffset, patternScale;
    load_line_type(primID, ellipse_attr.isLogical & linetype_attr.lt_logical, startSkipLen, endSkipLen, patternOffset, patternScale);
    set_line_type_properties(linetype_attr, float4(startSkipLen, endSkipLen, patternOffset, patternScale), verAttr_Linetype);
}

OIT_PS_HEADER_2(Circle_Line_Type_PS, VertexAttr_Ellipse, VertexAttr_LineType_Arc)
{
    // get current pixel's angle on circle
    float cur_angle = get_ellipse_angle(input.radius, input.uv);

    // discard out of angle range pixels
    if (!angle_is_in_range(cur_angle, input.range))
        discard;

    [branch] if (gNoAAMode != 0)
    {
        if (not_in_circle(input, input.weight))
            discard;
    }

    // adjust angle
    if (cur_angle < input.range.x)
        cur_angle = TWO_PI + cur_angle;

    bool is_dot;
    bool no_aa;
    float dot_dist;

    // get distance to start and end point
    float dist_to_start = input.radius.x * (cur_angle - input.range.x);
    float dist_to_end = input.radius.x * (input.range.y - cur_angle);
    if (input2.lt_inverted) {
        float tmp = dist_to_start;
        dist_to_start = dist_to_end;
        dist_to_end = tmp;
    }

    // get distance to circle
    float dist_to_circle = abs(sqrt(input.uv.x * input.uv.x + input.uv.y * input.uv.y) - input.radius.x);

    float4 color;

    // Handle arc with lineweight.
    if (input.weight > 1) {
        WideLinePatternResult left_attr;
        WideLinePatternResult right_attr;

        WideLinePatternAttr attr;
        attr.dist = dist_to_circle;
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
        info.isCircle = true;
        info.curAngle = 0.0f;

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
                bool in_sharp = !not_in_circle(input, width);
                color = compute_highlight_sharp_color(dist_to_circle, width, input.color, input.glowColor, in_sharp);
#else
                color = get_formatted_color(input.color, 1.0f);
#endif
            }
            else
            {
                color = compute_final_color(dist_to_circle, width, input.color, input.glowColor);
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
                    input.color, input.glowColor, input.uv, 2);

            }
            else
            {
                left_color = compute_wide_pattern_color(left_attr, width,
                    input.color, input.glowColor, input.uv, 2);

                right_color = compute_wide_pattern_color(right_attr, width,
                    input.color, input.glowColor, input.uv, 2);
            }

            color = (left_color.a >= right_color.a) ? left_color : right_color;

        }
    }
    // Handle arc without lineweight.
    else {
        SimpleLineTypeAttr attr = (SimpleLineTypeAttr)0;
        attr.startDist = dist_to_start;
        attr.endDist = dist_to_end;
        attr.startSkipLen = input2.patternProp.x;
        attr.endSkipLen = input2.patternProp.y;
        attr.patternScale = input2.patternProp.z;
        attr.patternOffset = input2.patternProp.w;
        attr.patternID = input2.patternIndex;
        attr.lineDir = normalize(float2(-input.uv.y, input.uv.x));
        attr.isClosed = is_closed_arc(input.range);
        attr.isCurve = true;

        SimpleLineTypeResult result;

        bool display = check_line_pattern(attr, result);

        if (!display)
            discard;

        if (result.isDot && !result.noDotAA)
        {
            float dist_to_dot_center = sqrt(dist_to_circle * dist_to_circle + result.dotDist * result.dotDist);

            [branch] if (gNoAAMode != 0)
            {
                color = compute_final_color_sharp(get_extended_dist_to_center(dist_to_dot_center), get_extended_line_type_dot_weight(input.weight), input.color, input.glowColor);
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
                color = compute_final_color_sharp(get_extended_dist_to_center(dist_to_circle), get_extended_line_weight(input.weight), input.color, input.glowColor);
            }
            else
            {
                color = compute_final_color(get_extended_dist_to_center(dist_to_circle), get_extended_line_weight(input.weight), input.color, input.glowColor);
            }
        }
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Circle_Line_Type
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Circle_Line_Type_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Circle_Line_Type_PS()));
    }
}

