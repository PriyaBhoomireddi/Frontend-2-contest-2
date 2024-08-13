#ifndef _HQ_FX_LT_WIDE_LINE_H__
#define _HQ_FX_LT_WIDE_LINE_H__

#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_weight10.fxh"
#include "Sketch_line_type_line10.fxh"
#include "Sketch_lt_line_caps10.fxh"
#include "Sketch_lt_line_joint10.fxh"

#ifdef ANALYTIC_STIPPLE
  #include "Sketch_stipple_line_type10.fxh"
#endif

struct VertexAttr_WideLineType
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    nointerpolation uint flag : FLAG;   // line flag
    nointerpolation uint color : COLOR;  // line color
    nointerpolation uint glowColor : GLOW;  // glow color
    nointerpolation uint width : WIDTH;  // line width;

    nointerpolation float2 prevPoint : PREV;
    nointerpolation float2 startPoint : START;
    nointerpolation float2 endPoint : END;
    nointerpolation float2 postPoint : POST;

    nointerpolation float4 lineParams : PARAMS; // Func = lineParams.x * x + lineParams.y * y + lineParams.z

    nointerpolation uint patternIndex : LTYPE; // line pattern index
    nointerpolation uint capsType : CAPTYPE; // caps type

    nointerpolation float4 patternProp : LTPROP; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset
    linear float4 dist : DIST;     // x - distance to line, y distance to start, z distance to end, w reserved

#ifdef ANALYTIC_STIPPLE
    nointerpolation uint stippleIndex : STPIDX;  // stipple index
#endif
};

struct VertexAttr_MetaWideLineType
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    nointerpolation uint flag : FLAG;   // line flag
    nointerpolation uint color : COLOR;  // line color
    nointerpolation uint glowColor : GLOW;  // glow color
    nointerpolation uint width : WIDTH;  // line width;


    // points:
    // caps:  PNT0 = center point
    //        PNT1 = end point
    //        PNT2 = dir
    // joint: PNT0 = prev point
    //        PNT1 = current point
    //        PNT2 = post point
    // body:  PNT0 = prev point
    //        PNT1 = start point
    //        PNT2 = end point
    //        PNT3 = post point
    nointerpolation float2 point0 : POINT0;
    nointerpolation float2 point1 : POINT1;
    nointerpolation float2 point2 : POINT2;
    nointerpolation float2 point3 : POINT3;

    nointerpolation uint shapeType : SHAPETYPE;
    nointerpolation uint capsType : CAPSTYPE;  // joint type;
    nointerpolation uint jointType : JOINTYPE;  // joint type;


    nointerpolation uint patternIndex : LTYPE; // line pattern index
    nointerpolation float4 patternProp : LTPROP; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset
    nointerpolation float4 patternProp_Post : LTPROP_POST; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset

    nointerpolation bool reversed : REVERSE; // is start/end point reversed

    nointerpolation float4 lineParams : PARAMS; // Func = lineParams.x * x + lineParams.y * y + lineParams.z
    linear float4 dist : DIST;     // x - distance to line, y distance to start, z distance to end, w reserved

#ifdef ANALYTIC_STIPPLE
    nointerpolation uint stippleIndex : STPIDX;  // stipple index
#endif
};

// wide line attributes
struct WideLineTypeAttr
{
    float2 prevPoint;
    float2 startPoint;
    float2 endPoint;
    float2 postPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint isLogical;

    uint  patternIndex;
    uint capsType;

    float startSkipLen;
    float endSkipLen;
    float patternOffset;
    float patternScale;

#ifdef ANALYTIC_STIPPLE
    uint stippleIndex;
#endif
};

// load line type info for wide line
void load_wide_line_type_info(uint offset, uint line_index, uint seg_index, uint line_flag, out WideLineTypeAttr attr)
{
    load_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);

    uint joint_type;
    uint logical_width, stipple_index, logical_lt;
    load_line_attributes(line_index, attr.color, attr.width, attr.patternIndex, attr.drawZ, attr.glowColor, attr.capsType, joint_type, attr.isLogical);
    load_line_attributes_neutron_sketch(line_index, logical_width, stipple_index, logical_lt);
    load_line_adj_info(offset, line_flag, attr.startPoint, attr.flag, attr.prevPoint, attr.postPoint);
    load_line_type(seg_index, attr.isLogical & logical_lt, attr.startSkipLen, attr.endSkipLen, attr.patternOffset, attr.patternScale);

    adjust_line_width_wide_line_neutron_sketch(logical_width, attr.width);

#ifdef ANALYTIC_STIPPLE
    attr.stippleIndex = stipple_index;
#endif
}

// load line type info for wide line
void load_hatch_wide_line_type_info(uint offset, uint line_index, uint seg_index, uint line_flag, out WideLineTypeAttr attr)
{
    load_hatch_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);

    uint joint_type;
    load_hatch_line_attributes(line_index, attr.color, attr.width, attr.patternIndex, attr.drawZ, attr.glowColor, attr.capsType, joint_type, attr.isLogical);
    load_hatch_line_adj_info(offset, line_flag, attr.startPoint, attr.flag, attr.prevPoint, attr.postPoint);
    load_hatch_line_type(seg_index, attr.isLogical, attr.startSkipLen, attr.endSkipLen, attr.patternOffset, attr.patternScale);
}

// output wide line properties.
void set_wide_line_type_properties(uint vid, WideLineTypeAttr line_attr,
    out VertexAttr_WideLineType output)
{
    float temp_dist;
    output.position.xy = get_line_envelope_pos(vid, line_attr.width,
        line_attr.startPoint, line_attr.endPoint, temp_dist);
    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;

    output.dist = temp_dist;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.flag = line_attr.flag;
    output.width = line_attr.width;

    output.prevPoint = offset_screen_pos(line_attr.prevPoint);
    output.startPoint = offset_screen_pos(line_attr.startPoint);
    output.endPoint = offset_screen_pos(line_attr.endPoint);
    output.postPoint = offset_screen_pos(line_attr.postPoint);

    output.lineParams.x = output.startPoint.y - output.endPoint.y;
    output.lineParams.y = output.endPoint.x - output.startPoint.x;
    output.lineParams.z = output.startPoint.x * output.endPoint.y - output.endPoint.x * output.startPoint.y;
    output.lineParams.w = 0.0f;

    // length on line
    set_line_pattern_dist(vid, line_attr.startPoint, line_attr.endPoint,
        output.dist.y, output.dist.z);
    output.dist.w = 0.0f; // reserved

    output.patternIndex = line_attr.patternIndex;
    output.capsType = line_attr.capsType;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// output wide line properties in logical space
void set_logical_wide_line_type_properties(uint vid, WideLineTypeAttr line_attr,
    out VertexAttr_WideLineType output)
{
    float temp_dist;
    float2 screen_prev = logic_to_screen(line_attr.prevPoint);
    float2 screen_start = logic_to_screen(line_attr.startPoint);
    float2 screen_end = logic_to_screen(line_attr.endPoint);
    float2 screen_post = logic_to_screen(line_attr.postPoint);
    output.position.xy = get_logical_wide_line_envelope_pos(vid, line_attr.flag, line_attr.width,
        screen_start, screen_end, temp_dist);
    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;

    output.dist = temp_dist;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.flag = line_attr.flag;
    output.width = line_attr.width;

    output.prevPoint = screen_prev;
    output.startPoint = screen_start;
    output.endPoint = screen_end;
    output.postPoint = screen_post;

    output.lineParams.x = screen_start.y - screen_end.y;
    output.lineParams.y = screen_end.x - screen_start.x;
    output.lineParams.z = screen_start.x * screen_end.y - screen_end.x * screen_start.y;
    output.lineParams.w = 0.0f;

    // length on line
    set_line_pattern_dist(vid, output.startPoint, output.endPoint,
        output.dist.y, output.dist.z);
    output.dist.w = 0.0f; // reserved

    output.patternIndex = line_attr.patternIndex;
    output.capsType = line_attr.capsType;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

float4 getWLColorFromLTAttr(VertexAttr_WideLineType input, WideLinePatternResult left_attr, WideLinePatternResult right_attr, int res)
{
    // get screen pos
    float2 pixelPos = input.position.xy;
    pixelPos.y = gScreenSize.y - pixelPos.y;

    float width = adjust_line_width_wide_line(input.width);

    float4 color;
    // if on dash, draw as wide line
    if (res == PURE_DASH)
    {
        [branch]if (gNoAAMode != 0)
        {
#ifdef ANALYTIC_HIGHLIGHT
            bool in_sharp = (width > 1) ? true : in_line_sharp(input.lineParams.xyz, pixelPos);
            color = compute_highlight_sharp_color(abs(input.dist.x), width, input.color, input.glowColor, in_sharp);
#else
            color = compute_final_color_sharp(abs(input.dist.x), width, input.color, input.glowColor);
#endif
        }
        else
        {
#ifdef ANALYTIC_STIPPLE
            color = compute_final_color_stipple(abs(input.dist.x), width, input.color, input.glowColor, pixelPos, input.stippleIndex);
#else
            color = compute_final_color(abs(input.dist.x), width, input.color, input.glowColor);
#endif
        }
    }
    // other wise we need get color from left segment and right segment
    // and combine both sides.
    else
    {

#ifdef ANALYTIC_STIPPLE
        float4 left_color = compute_wide_pattern_color_stipple(left_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);

        float4 right_color = compute_wide_pattern_color_stipple(right_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);
#else
        float4 left_color = compute_wide_pattern_color(left_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType);

        float4 right_color = compute_wide_pattern_color(right_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType);;
#endif

        color = (left_color.a >= right_color.a) ? left_color : right_color;
    }

    return color;
}

float4 getWLColorFromLTAttr_Meta(VertexAttr_MetaWideLineType input, WideLinePatternResult left_attr, WideLinePatternResult right_attr, int res)
{
    // get screen pos
    float2 pixelPos = input.position.xy;
    pixelPos.y = gScreenSize.y - pixelPos.y;

    float width = adjust_line_width_wide_line(input.width);

    float4 color;
    // if on dash, draw as wide line
    if (res == PURE_DASH)
    {
        [branch]if (gNoAAMode != 0)
        {
#ifdef ANALYTIC_HIGHLIGHT
            bool in_sharp = (width > 1) ? true : in_line_sharp(input.lineParams.xyz, pixelPos);
            color = compute_highlight_sharp_color(abs(input.dist.x), width, input.color, input.glowColor, in_sharp);
#else
            color = compute_final_color_sharp(abs(input.dist.x), width, input.color, input.glowColor);
#endif
        }
        else
        {
#ifdef ANALYTIC_STIPPLE
            color = compute_final_color_stipple(abs(input.dist.x), width, input.color, input.glowColor, pixelPos, input.stippleIndex);
#else
            color = compute_final_color(abs(input.dist.x), width, input.color, input.glowColor);
#endif
        }
    }
    // other wise we need get color from left segment and right segment
    // and combine both sides.
    else
    {

#ifdef ANALYTIC_STIPPLE
        float4 left_color = compute_wide_pattern_color_stipple(left_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);

        float4 right_color = compute_wide_pattern_color_stipple(right_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);
#else
        float4 left_color = compute_wide_pattern_color(left_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType);

        float4 right_color = compute_wide_pattern_color(right_attr, width,
            input.color, input.glowColor, pixelPos, input.capsType);;
#endif

        color = (left_color.a >= right_color.a) ? left_color : right_color;
    }

    return color;
}

VertexAttr_WideLineType outputWideLineType_VS(uint vid, WideLineTypeAttr line_attr)
{
    VertexAttr_WideLineType output = (VertexAttr_WideLineType)0;
    if (line_attr.isLogical)
        set_logical_wide_line_type_properties(vid, line_attr, output);
    else
        set_wide_line_type_properties(vid, line_attr, output);

    return output;
}

#endif
