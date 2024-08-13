#include "Sketch_circle_ellipse_lt10.fxh"
#include "Sketch_ellipse_caps10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_type_line10.fxh"

struct VertexAttr_Caps_LT
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    linear float2 uv : UV;     // uv is used to compute gradient
    linear float4  ref : REF;   // xy reference point, zw reference dir

    nointerpolation  float2 radius : RADIUS;  // x long axis, y short axis
    nointerpolation  float2 range : RANGE;  // x start angle, y end angle
    nointerpolation  uint  color : COLOR0;  // line color
    nointerpolation  float weight : WEIGHT; // line weight

    nointerpolation  uint  glowColor : COLOR1; // glow color for highlights
    nointerpolation  uint  capType : TYPE; // cap type

    nointerpolation uint patternIndex : LTYPE; // line pattern index
    nointerpolation uint lt_dot : LTDOT;
    nointerpolation uint lt_inverted : LTINV;

    nointerpolation float4 patternProp : LTPROP; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset
    nointerpolation uint start_cap : STCAP;
};

Texture2D<uint>  gCircleLineTypeCapsIndexTex : CircleLineTypeCapsIndexTex;
Texture2D<float> gCircleLineTypeCapsDrawOrderZTex : CircleCapsDrawOrderZTex;

VertexAttr_Caps_LT LT_Ellipse_Caps_VS(NullVertex_Input input)
{
    // load primitive index
    uint primID = load_prim_id_from_tex(gCircleLineTypeCapsIndexTex, input.InstanceID);

    // load ellipse information
    EllipseAttr_Dash ellipse_attr;
    EllipseAttr_LineType linetype_attr;
    load_ellipse_info_lt(primID, ellipse_attr, linetype_attr);

    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(input.InstanceID, gCircleLineTypeCapsDrawOrderZTex, ellipse_attr.drawZ);
    }
    else
    {
        adjust_caps(ellipse_attr);
    }

    // initialize
    VertexAttr_Caps_LT output = (VertexAttr_Caps_LT)0;

    // update geometry info
    float2 center = float2(ellipse_attr.center.x, ellipse_attr.center.y);
    output.range = ellipse_attr.range;

    float2 adjusted_radius = ellipse_attr.radius;

    [branch] if (gRetainMode)
    {
        center = logic_to_ndc(center);
        center = ndc_to_screen(center);

        adjusted_radius = neutron_sketch_radius_to_screen(adjusted_radius);
    }
    else
    {
        if (ellipse_attr.isLogical)
        {
            center = logic_to_ndc(center);
            center = ndc_to_screen(center);

            adjusted_radius = neutron_sketch_radius_to_screen(adjusted_radius);
        }
        else
        {
            if (ellipse_attr.radius.x == 0) adjusted_radius.x = 1.0f;
            if (ellipse_attr.radius.y == 0) adjusted_radius.y = 1.0f;
        }
    }

    output.radius = adjusted_radius;

    float sin_rot, cos_rot;
    sincos(ellipse_attr.rotate, sin_rot, cos_rot);

    // expand range when have line weight
    float weight_expand = get_screen_weight_expand(ellipse_attr.weight);

    // get the radius
    output.position.xy = get_vertex_pos_caps(input.VertexID, output.range, output.radius.x, output.radius.y,
        weight_expand, center, sin_rot, cos_rot, output.uv, output.ref);

    // start cap
    output.start_cap = input.VertexID <= 4 ? 1 : 0;

    // update other properties
    output.weight = ellipse_attr.weight;
    output.position.z = ellipse_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.color = ellipse_attr.color; // move color assignment to last will fix an Intel compiler issue.
                                        // since the color assignment will affect position result on Intel cards.

    output.glowColor = ellipse_attr.glowColor;

    output.capType = ellipse_attr.capType;

    // load linetype information
    output.patternIndex = linetype_attr.lt_index;
    output.lt_dot = linetype_attr.lt_dot;
    output.lt_inverted = linetype_attr.lt_inverted;

    float startSkipLen, endSkipLen, patternOffset, patternScale;
    load_line_type(primID, ellipse_attr.isLogical & linetype_attr.lt_logical, startSkipLen, endSkipLen, patternOffset, patternScale);
    output.patternProp = float4(startSkipLen, endSkipLen, patternOffset, patternScale);

    return output;
}

bool valid_range_caps(VertexAttr_Caps_LT input)
{
    if (abs(input.radius.x - input.radius.y) < EPS)
        return valid_range(input.radius, input.uv, input.range);
    else
    {
        float dist = ellipse_distance(input.radius, input.uv);
        return valid_range_ellipse(input.radius, input.uv, input.range, dist);
    }
}

OIT_PS_HEADER(LT_Ellipse_Caps_PS, VertexAttr_Caps_LT)
{
    // Check plinegen:
    // If current point is in start_cap, then check input.patternProp.x;
    // If current point is in end_cap, then check input.patternProp.y;
    // input.lt_inverted is true means line type is inverted, in this case exchange the checking target.
    bool isPlineGen = false;
    if ((input.start_cap && !input.lt_inverted) || (!input.start_cap && input.lt_inverted))
        isPlineGen = is_pline_gen(input.patternProp.x);
    else
        isPlineGen = is_pline_gen(input.patternProp.y);

    float2 delta = input.uv - input.ref.xy;
    float dis_to_ref = length(delta);
    float dir_to_border = dot(delta, input.ref.zw);
    float dis_to_border = abs(dir_to_border);

    if (close_to_caps_border(dis_to_border))// if close to border
    {
        if (valid_range_caps(input)) // if inside ellipse
            discard;
    }

    float dist = abs(dis_to_ref);


    if (input.weight <= 1)
        discard;

    // linetype
    bool is_dot;
    bool no_aa;
    float dot_dist;
    float arc_length = input.radius.x * abs(input.range.y - input.range.x);
    float dist_to_start = input.start_cap > 0 ? 0 : arc_length;
    float dist_to_end = input.start_cap > 0 ? arc_length : 0;

    if (input.lt_inverted) {
        float tmp = dist_to_start;
        dist_to_start = dist_to_end;
        dist_to_end = tmp;
    }

    float4 color;
    float width = adjust_line_width_wide_line(input.weight);

    // If it is not plinegen and first/last dash length are not zero, then draw cap directly.
    if ((!isPlineGen) && (input.patternProp.x != 0.0f) && (input.patternProp.y != 0.0f))
    {
        [branch] if (gNoAAMode != 0)
        {
            color = compute_sharp_caps_final_color(dist, width, input.color, input.glowColor,
                input.uv, input.ref.xy, input.ref.zw, input.capType);
        }
        else
        {
            color = compute_caps_final_color(dist, width, input.color, input.glowColor,
                input.uv, input.ref.xy, input.ref.zw, input.capType);
        }
    }
    else
    {
        WideLinePatternResult left_attr;
        WideLinePatternResult right_attr;

        WideLinePatternAttr attr;
        attr.dist = 0;
        attr.width = input.weight;
        attr.startDist = dist_to_start;
        attr.endDist = dist_to_end;
        attr.startSkipLen = input.patternProp.x;
        attr.endSkipLen = input.patternProp.y;
        attr.patternScale = input.patternProp.z;
        attr.patternOffset = input.patternProp.w;
        attr.patternIndex = input.patternIndex;

        WideEllipseInfo info;
        info.inverted = input.lt_inverted;
        info.radius = input.radius;
        info.range = input.range;
        info.hasPrevLine = false;
        info.hasPostLine = false;
        info.isCircle = true;
        info.curAngle = 0.0f;

        // Check the line pattern of start or end point.
        // If current point is near the start point, then check the start point's line pattern.
        // If current point is near the end point, then check the end point's line pattern.
        int res = check_widearc_line_pattern(attr, info, glowWidth(),
            left_attr,
            right_attr);

        // If the start(end) point is in pure space, discard current point directly.
        if (res == PURE_SPACE)
            discard;

        // If the start(end) point is in dash, draw the cap directly.
        if (res == PURE_DASH)
        {
            [branch] if (gNoAAMode != 0)
            {
                color = compute_sharp_caps_final_color(dist, width, input.color, input.glowColor,
                    input.uv, input.ref.xy, input.ref.zw, input.capType);
            }
            else
            {
                color = compute_caps_final_color(dist, width, input.color, input.glowColor,
                    input.uv, input.ref.xy, input.ref.zw, input.capType);
            }
        }
        else
        {
            // If start(end) point is in MIXED, which means it is in space, but it is in a cap or a dot region.
            float4 left_color = compute_wide_pattern_color(left_attr, width,
                input.color, input.glowColor, input.uv, 2);

            float4 right_color = compute_wide_pattern_color(right_attr, width,
                input.color, input.glowColor, input.uv, 2);;

            if (left_color.a > right_color.a || (left_color.a == right_color.a && left_attr.dist <= right_attr.dist))
            {
                if (left_color.a < EPS)
                    discard;

                float2 capCenter = input.ref.xy;
                // If it is in a cap region, then current point will share the same cap center as start(end) point.
                if (left_attr.is_caps)
                    capCenter = left_attr.caps_center;
                // If it is in a dot region, then we need adjust the capCenter for current point.
                else if (left_attr.dist > 0)
                    capCenter = input.ref.xy - input.ref.zw * left_attr.dist;

                left_attr.dist = length(input.uv - capCenter);
                color = compute_wide_pattern_color(left_attr, width,
                    input.color, input.glowColor, input.uv, input.capType);
            }
            else
            {
                if (right_color.a < EPS)
                    discard;

                float2 capCenter = input.ref.xy;
                // If it is in a cap region, then current point will share the same cap center as start(end) point.
                if (right_attr.is_caps)
                    capCenter = right_attr.caps_center;
                // If it is in a dot region, then we need adjust the capCenter for current point.
                else if (right_attr.dist > 0)
                    capCenter = input.ref.xy - input.ref.zw * right_attr.dist;

                right_attr.dist = length(input.uv - capCenter);
                color = compute_wide_pattern_color(right_attr, width,
                    input.color, input.glowColor, input.uv, input.capType);
            }
        }
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Circle_Line_Type_Caps
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, LT_Ellipse_Caps_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, LT_Ellipse_Caps_PS()));
    }
}
