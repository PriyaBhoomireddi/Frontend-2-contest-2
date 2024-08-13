#ifndef _HQ_FX_STIPPLE_LINE_TYPE_HEADER__
#define _HQ_FX_STIPPLE_LINE_TYPE_HEADER__

#include "Sketch_line_type10.fxh"
#include "Sketch_stipple10.fxh"

float4 compute_wide_pattern_color_stipple(WideLinePatternResult attr, float width, uint color, uint glow_color, float2 pixelPos, uint caps_type, uint stipple_index)
{
    float4 ret = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // if dist is valid
    if (attr.dist >= 0.0f)
    {
        // if is cap, need to compute cap color
        if (attr.is_caps)
        {
            ret = compute_caps_final_color_stipple(attr.dist, width, color, glow_color,
                pixelPos, attr.caps_center, attr.caps_dir, caps_type, stipple_index);
        }
        // else compute body color
        else
        {
            ret = compute_final_color_stipple(attr.dist, width, color, glow_color, pixelPos, stipple_index);
        }
    }

    return ret;
}

#endif

