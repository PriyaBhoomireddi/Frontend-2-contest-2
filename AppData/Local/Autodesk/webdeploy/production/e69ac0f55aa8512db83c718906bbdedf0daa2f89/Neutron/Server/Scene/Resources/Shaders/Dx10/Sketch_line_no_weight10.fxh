#ifndef _HQ_FX_LINE_NW_H__
#define _HQ_FX_LINE_NW_H__

#include "Sketch_line10.fxh"

// TODO: move all get envelope shape functions together.
float2 get_logical_line_envelope_pos(int vid, uint line_flag, uint line_width, float2 start_point, float2 end_point, out float dist, out bool isDot)
{
    float weight_expand = get_line_weight_expand(line_width);
    float wide_line_expand = weight_expand*0.5f + 1.0f;

    float2 uv = get_rect_pos(vid);

    float2 fstart = logic_to_ndc(start_point);
    float2 fend = logic_to_ndc(end_point);
    float2  screen_start = ndc_to_screen(fstart);
    float2  screen_end = ndc_to_screen(fend);

    [branch]if (gNoAAMode != 0)
    {
        screen_start = trunc(screen_start) + float2(0.5f, 0.5f);
        screen_end = trunc(screen_end) + float2(0.5f, 0.5f);
        fstart = screen_to_ndc_pos(screen_start);
        fend = screen_to_ndc_pos(screen_end);
    }

    float2  screen_len = screen_end - screen_start;
    float2 dir = normalize(screen_len);
    float  xoffset = ENDPOINT_EXTEND;

    isDot = false;
    if (abs(screen_len.x) < 1.0f && abs(screen_len.y) < 1.0f)
    {
        dir = float2(1.0f, 0.0f);
        float2 screen_pos = offset_screen_pos(int2((screen_start + screen_end)*0.5f));
        float2  fcenter = screen_to_ndc_pos(screen_pos);
        xoffset = 0.5f;
        wide_line_expand = 0.5f;
        fstart = fcenter;
        fend = fcenter;
        if (line_flag&HAS_PREV_LINE)
        {
            int2 start_pixel = int2(offset_screen_pos(screen_start));
            int2 end_pixel = int2(offset_screen_pos(screen_end));
            if ((start_pixel.x == end_pixel.x) && (start_pixel.y == end_pixel.y))
            {
                xoffset = 0.0f;
                wide_line_expand = 0.0f;
            }
        }

        isDot = ((line_flag & IS_FIRST_SEG) && (line_flag & IS_LAST_SEG));
    }
    dist = uv.y*(wide_line_expand);
    float2 extrude = gPixelLen*(uv.x* dir * xoffset + uv.y * wide_line_expand*float2(dir.y, -dir.x));
    float2  curPoint = (uv.x < 0) ? fstart : fend;
    float2 Hpm = curPoint + extrude;
    return Hpm;

}

// for single line, set line-weight to 1.2f for fine tuning anti-aliasing effect
void adjust_line_width_single_line(inout uint width)
{
    // adjust line-width
    if ((int)width <= 1.0f)
        width = SINGLE_LINE_WIDTH_EXPAND;
}

#endif
