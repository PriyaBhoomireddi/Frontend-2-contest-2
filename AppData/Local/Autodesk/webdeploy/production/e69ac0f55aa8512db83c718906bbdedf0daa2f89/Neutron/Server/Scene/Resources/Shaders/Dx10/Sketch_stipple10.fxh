#ifndef _HQ_FX_STIPPLE_HEADER__
#define _HQ_FX_STIPPLE_HEADER__

#include "Sketch_primitive10.fxh"

// stipple pattern texture
Texture2D gStippleTex : StipplePatternTexture;
SamplerState gStippleSamp : StipplePatternSampler { Filter = MIN_MAG_MIP_LINEAR; };

// fract from origin to lcs center
float2 gStippleOffset : NeutronStipplePatternOffset;

// properties of the bitmap and pattern texture
static const float BITMAP_SIZE = 32.0f;
static const float BITMAP_BORDER = 1.0f;
static const float BITMAP_HALOED_SIZE = BITMAP_SIZE + BITMAP_BORDER * 2.0f;
static const float MAX_STIPPLE_ROWS = 512.0f;
static const float MAX_STIPPLE_CELLS = 512.0f;

float4 neutron_sketch_stipple_apply(float4 color, float2 pixel_pos, uint stipple_index)
{
    // Index into the stipple pattern texture.
    uint stipple_0 = 0xffff - (stipple_index & 0xffff);
    uint2 stipple_ij = uint2(stipple_0 & 0xff, (stipple_0 >> 8) & 0xff);

    // Offset in pixels to the bitmap at (i, j).
    float2 stipple_ij_offset = float2(stipple_ij) * BITMAP_HALOED_SIZE + BITMAP_BORDER;

    // Sample which pixel in the bitmap?
    float2 bitmapSize = float2(BITMAP_SIZE, BITMAP_SIZE);
    float2 texelPos = fmod(pixel_pos + gStippleOffset, bitmapSize);

    // Always positive.
    texelPos = fmod(texelPos + bitmapSize, bitmapSize);

    // Normalize.
    float2 uv = (texelPos + stipple_ij_offset) / float2(MAX_STIPPLE_CELLS, MAX_STIPPLE_ROWS);

    // Sample.
    float val = gStippleTex.SampleLevel(gStippleSamp, uv, 0).r;

    // Blend with the color.
    return float4(color.rgb, color.a * val);
}

float get_stipple_border_alpha(float dist, float weight, uint color)
{
    float extended_dist = get_extended_dist_to_center(dist);
    float extended_weight = get_extended_line_weight(weight);
    float anti_aliasing_val = get_antialiasing_val(extended_dist, extended_weight);
    float alpha = ((color & 0xff000000) >> 24) / 255.0f;
    return anti_aliasing_val * alpha;
}

float4 compute_final_color_stipple(float dist, float weight, uint color, uint glowColor, float2 cur_pos, uint stipple_index)
{
    // Compute the final color of the wide line.
    float4 final_color = compute_final_color(dist, weight, color, glowColor);

    // Only apply the stipple pattern to the internal of the wide line body.
    if (in_center_of_wide_line(dist, weight))
    {
        // Apply.
        final_color = neutron_sketch_stipple_apply(final_color, cur_pos, stipple_index);

        // Add a 1px border.
        float border_dist = abs((weight - 1.0f) * 0.5f - dist);
        float border_weight = 1.0f;
        float border_alpha = get_stipple_border_alpha(border_dist, border_weight, color);
        final_color.a = border_alpha + (1.0f - border_alpha) * final_color.a;
    }

    return final_color;
}

float4 compute_caps_final_color_stipple(float dist, float weight, uint color, uint glowColor,
    float2 cur_pos, float2 cap_center, float2 cap_dir, uint cap_type, uint stipple_index)
{
    // Compute the final color of the line cap.
    float4 final_color = compute_caps_final_color(dist, weight, color, glowColor, cur_pos, cap_center, cap_dir, cap_type);

    // Compute the distance to the line cap again.
    float2 param = float2(0.0f, 0.0f);
    if (cap_type == FLAG_CAP_ROUND) // round cap
    {
        param = get_caps_param_round(cur_pos, cap_center, weight);
    }
    else if (cap_type == FLAG_CAP_BUTT) // butt cap
    {
        param = get_caps_param_butt(cur_pos, cap_center, cap_dir, weight);
    }
    else if (cap_type == FLAG_CAP_SQUARE) // square cap
    {
        param = get_caps_param_square(cur_pos, cap_center, cap_dir, weight);
    }
    else if (cap_type == FLAG_CAP_DIAMOND) // diamond cap
    {
        param = get_caps_param_diamond(cur_pos, cap_center, cap_dir, weight);
    }

    // Only apply the stipple pattern to the internal of the wide line cap.
    if (in_center_of_wide_line(param.x, param.y))
    {
        // Apply.
        final_color = neutron_sketch_stipple_apply(final_color, cur_pos, stipple_index);

        // Add a 1px border.
        float border_dist = abs((param.y - 1.0f) * 0.5f - param.x);
        float border_weight = 1.0f;
        float border_alpha = get_stipple_border_alpha(border_dist, border_weight, color);
        final_color.a = border_alpha + (1.0f - border_alpha) * final_color.a;
    }

    return final_color;
}

float4 compute_joint_final_color_stipple(float dist, float weight, uint color, uint glowColor,
    float2 cur_pos, float2 start_point, float2 end_point, float2 next_point, uint joint_type, uint stipple_index)
{
    // Compute the final color of the line joint.
    float4 final_color = compute_joint_final_color(dist, weight, color, glowColor, cur_pos, start_point, end_point, next_point, joint_type);

    // Compute the distance to the line joint again.
    float2 param = float2(0.0f, 0.0f);
    if (joint_type == FLAG_JOINT_ROUND) // round joint
    {
        param = get_joint_param_round(cur_pos, end_point, weight);
    }
    else
    {
        float2 cur_line_dir = normalize(end_point - start_point);
        float2 next_line_dir = normalize(next_point - end_point);
        if (joint_type == FLAG_JOINT_MITER) // miter joint
        {
            param = get_joint_param_miter(cur_line_dir, next_line_dir, cur_pos, end_point, weight);
        }
        else
        {
            float2 middle_dir = normalize(-cur_line_dir + next_line_dir);
            float2 prev_pend_dir = float2(0.0f, 0.0f);
            float2 post_pend_dir = float2(0.0f, 0.0f);
            get_joint_pend_dirs(cur_line_dir, next_line_dir, middle_dir, prev_pend_dir, post_pend_dir);
            if (joint_type == FLAG_JOINT_BEVEL) // bevel joint
            {
                param = get_joint_param_bevel(cur_line_dir, middle_dir, cur_pos, end_point, weight, prev_pend_dir, post_pend_dir);

                if (out_of_bevel_range(cur_line_dir, middle_dir, cur_pos, end_point, weight, prev_pend_dir, post_pend_dir))
                {
                    param = float2(0.0f, 0.0f);
                }
            }
            else if (joint_type == FLAG_JOINT_DIAMOND) // diamond joint
            {
                param = get_joint_param_diamond(cur_line_dir, middle_dir, cur_pos, end_point, weight, prev_pend_dir, post_pend_dir);

                if (out_of_diamond_range(cur_line_dir, middle_dir, cur_pos, end_point, weight, prev_pend_dir, post_pend_dir))
                {
                    param = float2(0.0f, 0.0f);
                }
            }
        }
    }

    // Only apply the stipple pattern to the internal of the wide line cap.
    if (in_center_of_wide_line(param.x, param.y))
    {
        // Apply.
        final_color = neutron_sketch_stipple_apply(final_color, cur_pos, stipple_index);

        // Add a 1px border.
        float border_dist = abs((param.y - 1.0f) * 0.5f - param.x);
        float border_weight = 1.0f;
        float border_alpha = get_stipple_border_alpha(border_dist, border_weight, color);
        final_color.a = border_alpha + (1.0f - border_alpha) * final_color.a;
    }

    return final_color;
}

#endif

