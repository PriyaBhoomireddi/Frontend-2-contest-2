#ifndef _HQ_FX_HIGHT_LIGHT_HEADER__
#define _HQ_FX_HIGHT_LIGHT_HEADER__

#include "Sketch_oit_def10.fxh"
#include "Sketch_color10.fxh"
#include "Sketch_screen10.fxh"
#include "Sketch_math10.fxh"
#include "Sketch_logical_screen10.fxh"

// highlight parameters
float gGlowWidth = 6.0f;

// format float4 color into uint4
uint format_color(float4 color)
{
    return pack_color(color);
}

// get uint color as float4 and apply alpha value
float4 get_formatted_color(uint color, float alpha)
{
    float4 result = unpack_color(color);
    result.a *= alpha;
    return result;
}

// check if the line has line-weight
bool has_line_weight(float half_weight)
{
    return half_weight > 0.75f;
}

// get highlight sharp color
float4 highlight_sharp_color(float dist, float half_weight, uint color, uint glowColor, bool in_sharp)
{
    if (dist <= half_weight && in_sharp)
    {
        return get_formatted_color(color, 1.0f);
    }
    else if (dist <= gGlowWidth * 0.3333f + half_weight)
    {
        return get_formatted_color(glowColor, 1.0f);;
    }
    else
        return float4(0.0f, 0.0f, 0.0f, 0.0f);
}

// compute sharp highlight color for all primitive
float4 compute_highlight_sharp_color(float dist, float weight, uint color, uint glowColor, bool in_sharp)
{
    float half_weight = weight * 0.5f;

    return highlight_sharp_color(dist, half_weight, color, glowColor, in_sharp);
}

// highlight line/curve with no weight.
float4 highlight_color_no_line_weight(float4 glow_color, float4 line_color, float dist, float half_weight, bool isCap)
{
    // experimental number
    static const float GLOW_CAP_ALPHA_RATE = 0.54f;

    // expand cap range to consist with body.
    if (isCap)
        glow_color.w *= GLOW_CAP_ALPHA_RATE;

    if (dist < 1.5f)
    {
        // blending with line color and glow color.
        return lerp(line_color, glow_color, saturate(dist));
    }
    else
    {
        // blend based on distance to line with glow color only.
        float alpha = lerp(0.0f, glow_color.w, -(dist - 1.5f) / (gGlowWidth*0.5f + half_weight - 1.5f) + 1.0f);

        return float4(glow_color.xyz, alpha);
    }
}

// highlight line/curve with line weight.
float4 highlight_color_line_weight(float4 glow_color, float4 line_color, float dist, float half_weight)
{
    float aa_weight = dist - half_weight;

    if (aa_weight < 1.5f)
    {
        // blend with line color and glow color.
        return lerp(line_color, glow_color, saturate(aa_weight));
    }
    else
    {
        // blend based on distance to line with glow color only.
        float alpha = lerp(0.0f, glow_color.w, -(aa_weight - 1.5f) / (gGlowWidth*0.5f - 1.5f) + 1.0f);
        return float4(glow_color.xyz, alpha);
    }
}

// highlight color compute implementation
float4 highlight_color(float dist, float halfWeight, uint color, uint glowColor, bool isCap, bool hasWeight)
{
    float4 glow_color = get_formatted_color(glowColor, 1.0f);
    float4 line_color = get_formatted_color(color, 1.0f);

    if (hasWeight)
        return highlight_color_line_weight(glow_color, line_color, dist, halfWeight);
    else
        return highlight_color_no_line_weight(glow_color, line_color, dist, halfWeight, isCap);
}

// compute highlight color for all primitive
float4 compute_highlight_color(float dist, float weight, uint color, uint glowColor, bool isCap)
{
    float half_line_weight = weight * 0.5f;
    bool has_weight = has_line_weight(half_line_weight);

    return highlight_color(dist, half_line_weight, color, glowColor, isCap, has_weight);
}

// adjust line-weight for no highlight cases
float adjust_line_width_no_highlight(uint in_width)
{
    // for odd line weight, we we need to make it even to avoid the line bias
    // when it vertical or horizontal.
    // return (in_width & 0x1) != 0 ? in_width : in_width + 1.0f;
    //

    // ???
    return float(in_width);
}

// adjust line weight for highlight
float adjust_line_width_highlight(uint in_width)
{
    int out_width = (in_width - gGlowWidth <= 1.0f) ? 1.0f : adjust_line_width_no_highlight(in_width - gGlowWidth);

    return out_width;
}

// adjust line-weight for wide line.
float adjust_line_width_wide_line(uint in_width)
{
    float out_width;

#ifdef ANALYTIC_HIGHLIGHT 
    out_width = adjust_line_width_highlight(in_width);
#else
    out_width = adjust_line_width_no_highlight(in_width);
#endif

    return out_width;
}

// adjust line-weight for wide line using logical width for neutron sketch
void adjust_line_width_wide_line_neutron_sketch(uint logical_width, inout uint width)
{
    if (logical_width != 0)
    {
        if (gLCSIsInteger)
        {
            uint logical_fract = uint(max(1, int(round(neutron_sketch_screen_to_logical(1.0f)))));
            uint logical_width_adjusted = logical_width + logical_fract;
            uint screen_width = uint(neutron_sketch_logical_to_screen(float(logical_width_adjusted)));
            width += screen_width;
        }
        else
        {
            float logical_fract = max(0.0f, neutron_sketch_screen_to_logical(1.0f));
            float logical_width_adjusted = asfloat(logical_width) + logical_fract;
            uint screen_width = uint(neutron_sketch_logical_to_screen(logical_width_adjusted));
            width += screen_width;
        }
    }
}

// Used in check_widearc_line_pattern() for Circle/Arc
float glowWidth()
{
    float out_width = 0.0f;

#ifdef ANALYTIC_HIGHLIGHT 
    out_width = gGlowWidth;
#endif

    return out_width;
}

#endif

