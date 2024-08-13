#ifndef _HQ_FX_LINE_WEIGHT_H__
#define _HQ_FX_LINE_WEIGHT_H__

#define SHAPE_BODY  (0)
#define SHAPE_CAPS  (1)
#define SHAPE_JOINT (2)

// load previous and post vertex point
void load_prev_point(uint offset, uint flag, out float2 prev_point)
{
    load_line_vertex(get_prev_pos_id(offset, flag), prev_point);
}
void load_post_point(uint offset, uint flag, out float2 post_point)
{
    load_line_vertex(get_post_pos_id(offset, flag), post_point);
}

void load_hatch_prev_point(uint offset, uint flag, out float2 prev_point)
{
    load_hatch_line_vertex(get_prev_pos_id(offset, flag), prev_point);
}
void load_hatch_post_point(uint offset, uint flag, out float2 post_point)
{
    load_hatch_line_vertex(get_post_pos_id(offset, flag), post_point);
}

// load polyline adjancent information.
void load_line_adj_info(uint offset, uint line_flag, float2 ref_point,
    out uint flag, out float2 prev_point, out float2 post_point)
{
    load_line_flag(line_flag, flag);
    load_prev_point(offset, flag, prev_point);
    load_post_point(offset, flag, post_point);
}

// load polyline adjancent information.
void load_hatch_line_adj_info(uint offset, uint line_flag, float2 ref_point,
    out uint flag, out float2 prev_point, out float2 post_point)
{
    load_line_flag(line_flag, flag);
    load_hatch_prev_point(offset, flag, prev_point);
    load_hatch_post_point(offset, flag, post_point);
}

// TODO: move envelope functions to another place
float2 get_logical_wide_line_envelope_pos(int vid, uint line_flag, uint line_width, inout float2 screen_start, inout float2 screen_end,
    out float dist)
{
    float weight_expand = get_line_weight_expand(line_width);
    float wide_line_expand = weight_expand * 0.5f + 1.0f;

    float2 uv = get_rect_pos(vid);
    float2  screen_len = screen_end - screen_start;
    float2 dir = normalize(screen_len);
    float  xoffset = ENDPOINT_EXTEND;

    dist = uv.y * (wide_line_expand);
    float2 extrude = uv.x * dir * xoffset + uv.y * wide_line_expand * float2(dir.y, -dir.x);
    float2  curPoint = (uv.x < 0) ? screen_start : screen_end;
    return screen_to_ndc_pos(curPoint + extrude);


}

// check if a pixel is in a wide-line's region.
bool inLineRegion(float2 curPos, float2 startPoint, float2 endPoint, float width, float2 dir)
{
    // get line len
    float2 delta_line = endPoint - startPoint;
    float  line_len = length(delta_line);

    bool ret = true;


    // ignore degrading line.
    if (abs(line_len) < EPS)
        ret = false;


    // check distance to start and distance to end
    float2 delta_to_start = curPos - startPoint;
    float dist_to_start = dot(delta_to_start, dir);

    float2 delta_to_end = curPos - endPoint;
    float dist_to_end = dot(delta_to_end, -dir);

    // ignore out of distance range pixels.
    if ((dist_to_start > line_len + EPS))
        ret = false;

    if ((dist_to_end > line_len + EPS))
        ret = false;

    // check distance to line center line
    float2 distance = endPoint - startPoint;

    float dist = abs(delta_line.x * delta_to_start.y - delta_line.y * delta_to_start.x) / line_len;

    // ignore the pixels far from current line
    if (ret)
        return dist < width / 2.0f + EPS;
    else
        return false;
}

// load caps information
void load_line_caps_input(uint vid, uint iid, Texture2D<uint> indexTex, Texture2D<uint2> segTex, out LineVertex_Input vs_input, out bool endPoint)
{
    vs_input.VertexID = vid;

    int2 index_offset = get_ptex_offset(iid);
    uint index = indexTex.Load(int3(index_offset, 0));

    endPoint = (index & IS_END_POINT) != 0;

    index = (index & CAPS_IDX_MASK);
    vs_input.SegmentID = index;

    int2 prim_offset = get_ptex_offset(index);
    uint2 primIndex = segTex.Load(int3(prim_offset, 0));

    vs_input.PrimID.x = primIndex.x;
    vs_input.PrimID.y = primIndex.y;
}
// load joint information
void load_joint_line_position(uint offset, uint line_flag, out uint flag, out float2 prev_point, out float2 cur_point, out float2 post_point)
{
    load_line_flag(line_flag, flag);

    load_prev_point(offset, line_flag, prev_point);
    load_line_vertex(get_pos_id(offset), cur_point);
    load_line_vertex(get_pos_id(offset) + 1, post_point);

}

// TODO: move envelope shape together.
float2 get_caps_envelope_pos(uint vid, uint width, float2 center, float2 dir)
{
    float weight_expand = get_line_weight_expand(width);
    float2 uv = get_rect_pos(vid);

    float2 scr_pos = center +
        +uv.x * float2(dir.y, -dir.x) * weight_expand * 0.5f
        + (uv.y * 0.5f + 0.5f) * dir * weight_expand * 0.5f
        + (1.0f - (uv.y * 0.5f + 0.5f)) * (-dir) * 2.0f;

    return screen_to_ndc_pos(scr_pos);
}

// check if a pixel position in the end point side of current line
bool over_middle_point(float2 pixel_pos, float2 start, float2 end, float2 line_dir)
{
    float2 middle_point = (start + end) / 2.0f;

    float2 mid_dir = normalize(pixel_pos - middle_point);

    bool ret = false;
    if (dot(mid_dir, line_dir) < 0.0f)
        ret = true;

    return ret;

}

// get previous segment index
uint get_prev_seg_index(uint seg_index, uint flag, uint offset)
{
    uint prev_vtx = get_prev_pos_id(offset, flag);
    uint cur_vtx = get_pos_id(offset);

    if (prev_vtx == cur_vtx - 1)
        return seg_index - 1;
    else
        return seg_index + prev_vtx - cur_vtx;
}

#endif