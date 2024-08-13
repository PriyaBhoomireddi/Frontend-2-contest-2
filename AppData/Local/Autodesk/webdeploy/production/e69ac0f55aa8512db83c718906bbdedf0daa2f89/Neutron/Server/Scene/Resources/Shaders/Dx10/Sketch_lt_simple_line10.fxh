#ifndef _FX_HQ_LT_SIMPLE_LINE_H__
#define _FX_HQ_LT_SIMPLE_LINE_H__

#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_no_weight10.fxh"
#include "Sketch_line_type_line10.fxh"

// line type attribute for lines
struct LineTypeAttr
{
    float2 startPoint;
    float2 endPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint isLogical;

    uint  patternIndex;

    float startSkipLen;
    float endSkipLen;
    float patternOffset;
    float patternScale;
};

struct HatchLineAttr
{
    nointerpolation float2 startPoint : STARTPOINT;
    nointerpolation float2 endPoint : ENDPOINT;
};

struct VertexAttr_LineType
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    nointerpolation uint color : COLOR;  // line color
    nointerpolation uint glowColor : GLOW; // glow color

    nointerpolation uint patternIndex : LTYPE; // line pattern index
    nointerpolation uint reserved : RESV; // reserved

    nointerpolation float4 lineParams : PARAMS; // Func = lineParams.x * x + lineParams.y * y + lineParams.z

    nointerpolation float4 patternProp : LTPROP; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset

    linear float4 dist : DIST;     // x - distance to line, y distance to start, z distance to end, w reserved
};

// load line type info from texture 
void load_line_type_info(uint offset, uint line_index, uint line_flag, uint seg_index, out LineTypeAttr attr)
{
    uint caps_type, joint_type;
    uint logical_width, stipple_index, logical_lt;
    load_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);
    load_line_flag(line_flag, attr.flag);
    load_line_attributes(line_index, attr.color, attr.width, attr.patternIndex, attr.drawZ, attr.glowColor, caps_type, joint_type, attr.isLogical);
    load_line_attributes_neutron_sketch(line_index, logical_width, stipple_index, logical_lt);
    load_line_type(seg_index, attr.isLogical & logical_lt, attr.startSkipLen, attr.endSkipLen, attr.patternOffset, attr.patternScale);
}

// load line type info from texture 
void load_hatch_line_type_info(uint offset, uint line_index, uint line_flag, uint seg_index, out LineTypeAttr attr)
{
    uint caps_type, joint_type;
    load_hatch_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);
    load_line_flag(line_flag, attr.flag);
    load_hatch_line_attributes(line_index, attr.color, attr.width, attr.patternIndex, attr.drawZ, attr.glowColor, caps_type, joint_type, attr.isLogical);
    load_hatch_line_type(seg_index, attr.isLogical, attr.startSkipLen, attr.endSkipLen, attr.patternOffset, attr.patternScale);
}

// output line-type properties.
void set_line_type_properties(uint vid, LineTypeAttr line_attr, out VertexAttr_LineType output)
{
    float temp_dist = 0.0f;
    output.position.xy = get_line_envelope_pos(vid,
        line_attr.width, line_attr.startPoint, line_attr.endPoint, temp_dist);

    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;


    output.dist.x = temp_dist;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;

    // length on line
    set_line_pattern_dist(vid, line_attr.startPoint, line_attr.endPoint,
        output.dist.y, output.dist.z);
    output.dist.w = 0.0f; // reserved

    output.patternIndex = line_attr.patternIndex;
    output.reserved = 0;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);

    float2 startPoint = offset_screen_pos(line_attr.startPoint);
    float2 endPoint = offset_screen_pos(line_attr.endPoint);
    output.lineParams.x = startPoint.y - endPoint.y;
    output.lineParams.y = endPoint.x - startPoint.x;
    output.lineParams.z = startPoint.x * endPoint.y - endPoint.x * startPoint.y;
    output.lineParams.w = 0.0f;
}

// output line-type properties in logical space
void set_logical_line_type_properties(uint vid, LineTypeAttr line_attr, out VertexAttr_LineType output)
{
    float temp_dist = 0.0f;
    bool isDot = false;
    output.position.xy = get_logical_line_envelope_pos(vid, line_attr.flag,
        line_attr.width, line_attr.startPoint, line_attr.endPoint, temp_dist, isDot);

    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;


    output.dist.x = temp_dist;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;

    // length on line

    float2 screen_start = logic_to_screen(line_attr.startPoint);
    float2 screen_end = logic_to_screen(line_attr.endPoint);

    set_line_pattern_dist(vid, screen_start, screen_end,
        output.dist.y, output.dist.z);

    output.dist.w = 0.0f; // reserved

    output.patternIndex = line_attr.patternIndex;
    output.reserved = 0;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);

    output.lineParams.x = screen_start.y - screen_end.y;
    output.lineParams.y = screen_end.x - screen_start.x;
    output.lineParams.z = screen_start.x * screen_end.y - screen_end.x * screen_start.y;
    output.lineParams.w = 0.0f;
}

float4 getColorfromLTAttr(VertexAttr_LineType input, SimpleLineTypeResult result)
{
    float4 color;

    // if is dash or no aa dot, draw as line 
    if ((!result.isDot) || (result.noDotAA))
    {
        [branch]if (gNoAAMode != 0)
        {
            bool in_sharp = in_line_sharp(input.lineParams.xyz, float2(input.position.x, gScreenSize.y - input.position.y));
            color = in_sharp ? get_formatted_color(input.color, 1.0f) : float4(0.0f, 0.0f, 0.0f, 0.0f);
        }
        else
            color = compute_final_color(get_extended_dist_to_center(abs(input.dist.x)), get_extended_line_weight(SINGLE_LINE_WIDTH), input.color, input.glowColor);
        if (result.isOut)
            color.a *= result.outAlpha;
    }
    // other wise draw as anti-aliasing dot
    else
    {
        float dist = abs(input.dist.x);

        float new_dist = sqrt(dist * dist + result.dotDist *  result.dotDist);

        color = compute_final_color(get_extended_dist_to_center(new_dist), get_extended_line_type_dot_weight(SINGLE_LINE_WIDTH), input.color, input.glowColor);
    }
    return color;
}

VertexAttr_LineType outputLineType_VS(uint vid, LineTypeAttr line_attr)
{
    adjust_line_width_single_line(line_attr.width);

    VertexAttr_LineType output = (VertexAttr_LineType)0;
    if (line_attr.isLogical)
        set_logical_line_type_properties(vid, line_attr, output);
    else
        set_line_type_properties(vid, line_attr, output);

    return output;
}

#endif
