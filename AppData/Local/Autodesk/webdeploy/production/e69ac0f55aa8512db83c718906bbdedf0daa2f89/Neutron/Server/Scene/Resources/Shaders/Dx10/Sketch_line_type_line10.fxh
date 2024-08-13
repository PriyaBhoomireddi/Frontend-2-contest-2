#ifndef _HQ_FX_LINE_TYPE_H__
#define _HQ_FX_LINE_TYPE_H__

#include "Sketch_line_type10.fxh"

// load line type information from line type property texture
void load_line_type_common(float4 pattern_prop, in uint isLogical, out float startSkipLen, out float endSkipLen, out float patternOffset, out float patternScale)
{
    if (isLogical)
    {
        float scale = (gScreenSize.x * abs(gLCSMatrix[0][0])) / 2;
        startSkipLen = pattern_prop.x * scale;
        endSkipLen = pattern_prop.y * scale;
        patternOffset = pattern_prop.z / scale;
        patternScale = pattern_prop.w;
    }
    else
    {
        startSkipLen = pattern_prop.x;
        endSkipLen = pattern_prop.y;
        patternOffset = pattern_prop.z;
        patternScale = pattern_prop.w;
    }
}

void load_line_type(uint lineIndex, in uint isLogical, out float startSkipLen, out float endSkipLen, out float patternOffset, out float patternScale)
{
    int2 line_offset = get_ptex_offset(lineIndex);
    float4 pattern_prop = load_line_pattern_prop(line_offset);
    load_line_type_common(pattern_prop, isLogical, startSkipLen, endSkipLen, patternOffset, patternScale);
}

// load line type information from line type property texture
void load_hatch_line_type(uint lineIndex, in uint isLogical, out float startSkipLen, out float endSkipLen, out float patternOffset, out float patternScale)
{
    int2 line_offset = get_ptex_offset(lineIndex);
    float4 pattern_prop = load_hatch_line_pattern_prop(line_offset);
    load_line_type_common(pattern_prop, isLogical, startSkipLen, endSkipLen, patternOffset, patternScale);
}

// set start/end distance, that can be interpolated into per-pixel distance to start/end point.
void set_line_pattern_dist(uint vid, float2 startPoint, float2 endPoint,
    out float out_start_dist, out float out_end_dist)
{
    float line_len = length(startPoint - endPoint) + 2 * ENDPOINT_EXTEND;

    [branch]if (gNoAAMode != 0)
    {
        out_start_dist = (vid & 0x1)*line_len - ENDPOINT_EXTEND;
        out_end_dist = line_len - out_start_dist - 2 * ENDPOINT_EXTEND;
    }
    else
    {
        out_start_dist = (vid & 0x1)*line_len;
        out_end_dist = line_len - out_start_dist;
    }
}

// comute color for wide line-typed line.
float4 compute_wide_pattern_color_sharp_curve(WideLinePatternResult attr, float width, uint color, uint glow_color, float2 pixelPos, uint caps_type)
{
    float4 ret = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // if dist is valid
    if (attr.dist >= 0.0f)
    {
        // if is cap, need to compute cap color
        if (attr.is_caps)
        {
            ret = compute_sharp_caps_final_color(attr.dist, width, color, glow_color,
                pixelPos, attr.caps_center, attr.caps_dir, caps_type);

        }
        // else compute body color
        else
        {
#ifdef ANALYTIC_HIGHLIGHT
                ret = compute_highlight_sharp_color(attr.dist, width, color, glow_color, true);
#else
                float val = get_sharp_val(attr.dist, width);
                ret = get_formatted_color(color, val);
#endif
        }
    }

    return ret;
}

// comute color for wide line-typed line.
float4 compute_wide_pattern_color(WideLinePatternResult attr, float width, uint color, uint glow_color, float2 pixelPos, uint caps_type)
{
    float4 ret = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // if dist is valid
    if (attr.dist >= 0.0f)
    {
        // if is cap, need to compute cap color
        if (attr.is_caps)
        {
            [branch]if (gNoAAMode != 0)
            {
                ret = compute_sharp_caps_final_color(attr.dist, width, color, glow_color,
                    pixelPos, attr.caps_center, attr.caps_dir, caps_type);
            }
            else
            {
                ret = compute_caps_final_color(attr.dist, width, color, glow_color,
                    pixelPos, attr.caps_center, attr.caps_dir, caps_type);
            }
        }
        // else compute body color
        else
        {
            [branch]if (gNoAAMode != 0)
            {
                ret = compute_final_color_sharp(attr.dist, width, color, glow_color);
            }
            else
            {
                ret = compute_final_color(attr.dist, width, color, glow_color);
            }

        }
    }

    return ret;
}

#endif
