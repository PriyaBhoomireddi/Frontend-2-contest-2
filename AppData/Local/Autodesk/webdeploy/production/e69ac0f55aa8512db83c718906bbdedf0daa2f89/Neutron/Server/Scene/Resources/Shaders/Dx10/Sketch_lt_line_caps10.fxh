#ifndef _HQ_FX_LT_LINE_CAPS_H__
#define _HQ_FX_LT_LINE_CAPS_H__

#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_weight10.fxh"
#include "Sketch_line_type_line10.fxh"

// line type caps properties
struct CapsLineTypeAttr
{
    float2 startPoint;
    float2 endPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint isLogical;

    uint patternIndex;
    uint capsType;

    float startSkipLen;
    float endSkipLen;
    float patternOffset;
    float patternScale;

#ifdef ANALYTIC_STIPPLE
    uint stippleIndex;
#endif
};

struct VertexAttr_LineTypeCaps
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    nointerpolation uint flag : FLAG;   // line flag
    nointerpolation uint color : COLOR;  // line color
    nointerpolation uint glowColor : GLOW;  // glow color
    nointerpolation uint width : WIDTH;  // line width;
    nointerpolation uint capType : CAPTYPE;  // caps type;

    nointerpolation float2 center : CENTER; // cap center
    nointerpolation float2 endPoint : END; // end point

    nointerpolation uint patternIndex : LTYPE; // line pattern index
    nointerpolation bool reversed : REVERSE; // is start/end point reversed
    nointerpolation float4 patternProp : LTPROP; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset

#ifdef ANALYTIC_STIPPLE
    nointerpolation uint stippleIndex : STPIDX;  // stipple index
#endif
};

// get center point of caps
void get_line_type_caps_points(CapsLineTypeAttr attr, bool isEndPoint, out float2 cur_point, out float2 next_point, out bool reversed)
{
    // if doesn't have previous line
    if ((attr.flag&HAS_PREV_LINE) == 0)
    {
        // if is end point: that happens for single segment
        if (isEndPoint)
        {
            // end point is the caps point
            cur_point = attr.endPoint;
            next_point = attr.startPoint;
            reversed = true;
        }
        // if is start point
        else
        {
            // start point is the caps point
            cur_point = attr.startPoint;
            next_point = attr.endPoint;
            reversed = false;
        }
    }
    // if has previous line
    else
    {
        // end point must be caps point
        cur_point = attr.endPoint;
        next_point = attr.startPoint;
        reversed = true;
    }
}

// output line type caps properties
void set_line_type_caps_properties(uint vid, bool isEndPoint, CapsLineTypeAttr line_attr, out VertexAttr_LineTypeCaps output)
{
    float2 curPoint, nextPoint;
    bool reversed;
    get_line_type_caps_points(line_attr, isEndPoint, curPoint, nextPoint, reversed);

    output.flag = line_attr.flag;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.capType = line_attr.capsType;
    output.reversed = reversed;

    float2 dir = -normalize(nextPoint - curPoint);

    output.endPoint = offset_screen_pos(nextPoint);
    output.center = offset_screen_pos(curPoint);

    output.position.xy = get_caps_envelope_pos(vid, line_attr.width,
        output.center, dir);
    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;

    output.patternIndex = line_attr.patternIndex;

    output.patternProp.x = line_attr.startSkipLen;
    output.patternProp.y = line_attr.endSkipLen;
    output.patternProp.z = line_attr.patternOffset;
    output.patternProp.w = line_attr.patternScale;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// output line type caps properties in logical space
void set_logical_line_type_caps_properties(uint vid, bool isEndPoint, CapsLineTypeAttr line_attr, out VertexAttr_LineTypeCaps output)
{
    float2 curPoint, nextPoint;
    bool reversed;

    float weight_expand = get_line_weight_expand(line_attr.width);
    float2 uv = get_rect_pos(vid);

    get_line_type_caps_points(line_attr, isEndPoint, curPoint, nextPoint, reversed);

    float2  screen_next_pt = logic_to_screen(nextPoint);
    float2  screen_cur_pt = logic_to_screen(curPoint);
    float2 ndc_cur_pt = screen_to_ndc_pos(screen_cur_pt);
    float2 dir = -normalize(screen_next_pt - screen_cur_pt);
    int2 cur_pixel = int2(screen_cur_pt);
    int2 next_pixel = int2(screen_next_pt);
    float  xoffset = 2.0f;

    // if the current point and next point is near enough it will have precision issue when
    // calculate the direction. Here set (1.0f, 0.0f) as its direction.
    if (cur_pixel.x == next_pixel.x  && cur_pixel.y == next_pixel.y)
    {
        dir = float2(1.0f, 0.0f);
        screen_cur_pt = offset_screen_pos(cur_pixel);
        screen_next_pt = screen_cur_pt - dir*0.1f;
        weight_expand = 0.0f;
        xoffset = 0.0f;
    }

    float2 extrude = uv.x* float2(dir.y, -dir.x) *gPixelLen* weight_expand*0.5f
        + (uv.y*0.5f + 0.5f) * dir *gPixelLen*weight_expand*0.5f
        + (1.0f - (uv.y*0.5f + 0.5f)) * (-dir) *gPixelLen* xoffset;

    output.position.xy = ndc_cur_pt + extrude;
    output.endPoint = screen_next_pt;
    output.center = screen_cur_pt;
    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;

    output.flag = line_attr.flag;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.capType = line_attr.capsType;
    output.reversed = reversed;

    output.patternIndex = line_attr.patternIndex;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

int getCapsColorFromAttr(VertexAttr_LineTypeCaps input, int res, float2 pixelPos, float2 dir,
    WideLinePatternResult left_attr, WideLinePatternResult right_attr, out float4 color)
{
    int ret = 0;

    // get distances and line width
    float dist_to_center = length(pixelPos - input.center);
    float width = adjust_line_width_wide_line(input.width);

    color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    // if the start(end) point is in pure space, discard current point directly.
    if (res == PURE_SPACE)
        return -1;

    // if the start(end) point is in dash, draw the cap directly.
    if (res == PURE_DASH)
    {
        [branch]if (gNoAAMode != 0)
        {
            color = compute_sharp_caps_final_color(dist_to_center, width, input.color, input.glowColor,
                pixelPos, input.center, dir, input.capType);
        }
        else
        {
            color = compute_caps_final_color(dist_to_center, width, input.color, input.glowColor,
                pixelPos, input.center, dir, input.capType);
        }
    }
    else
    {
        // if start(end) point is in MIXED, which means it is in space, but it is in a cap or a dot region.
        float4 left_color = compute_wide_pattern_color(left_attr, width,
            input.color, input.glowColor, pixelPos, input.capType);

        float4 right_color = compute_wide_pattern_color(right_attr, width,
            input.color, input.glowColor, pixelPos, input.capType);

        // if left color is less transparent, or closer to left when have same color, output left color
        if (left_color.a > right_color.a || (left_color.a == right_color.a && left_attr.dist <= right_attr.dist))
        {
            if (left_color.a < EPS)
                return -1;

            float2 capCenter = input.center;

            // if it is in a cap region, then current point will share the same cap center as start(end) point.
            if (left_attr.is_caps)
                capCenter = left_attr.caps_center;
            // if it is in a dot region, then we need adjust the capCenter for current point.
            else if (left_attr.dist > 0)
                capCenter = input.center - dir * left_attr.dist;

            left_attr.dist = length(pixelPos - capCenter);
            color = compute_wide_pattern_color(left_attr, width,
                input.color, input.glowColor, pixelPos, input.capType);
        }
        // output right color
        else
        {
            if (right_color.a < EPS)
                return -1;

            float2 capCenter = input.center;

            // if it is in a cap region, then current point will share the same cap center as start(end) point.
            if (right_attr.is_caps)
                capCenter = right_attr.caps_center;
            // if it is in a dot region, then we need adjust the capCenter for current point.
            else if (right_attr.dist > 0)
                capCenter = input.center - dir * right_attr.dist;

            right_attr.dist = length(pixelPos - capCenter);
            color = compute_wide_pattern_color(right_attr, width,
                input.color, input.glowColor, pixelPos, input.capType);
        }
    }

    return ret;
}

#endif
