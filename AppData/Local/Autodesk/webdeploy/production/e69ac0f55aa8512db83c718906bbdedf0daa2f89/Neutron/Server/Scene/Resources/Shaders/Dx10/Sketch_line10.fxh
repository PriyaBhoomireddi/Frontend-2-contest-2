#ifndef _HQ_FX_LINE_COMMON_H__
#define _HQ_FX_LINE_COMMON_H__

#include "Sketch_primitive10.fxh"

// The primitive texture of poly line and wide line
// vertex data texture
Texture2D<float2> gVertexTex : PrimitiveTexture;
// primitive data texture
Texture2D<float4> gLineTex   : LineTexture;
// segment data texture
Texture2D<uint2>  gLineSegTex : LineSegmentTexture;


// The primitive texture of gradient poly line and wide line
// vertex data texture
Texture2D<float3> gGradientVertexTex : GradientPrimitiveTexture;
// primitive data texture
Texture2D<float2> gGradientLineTex   : GradientLineTexture;
// segment data texture
Texture2D<uint2>  gGradientLineSegTex : GradientLineSegmentTexture;

// The primitive texture of hatch line
// vertex data texture
Texture2D<float2> gHatchVertexTex : HatchPrimitiveTexture;
// primitive data texture
Texture2D<float4> gHatchLineTex   : HatchLineTexture;
// segment data texture
Texture2D<uint2>  gHatchLineSegTex : HatchLineSegmentTexture;


// line segment flags
#define IS_FIRST_SEG  (0x1)  // is the first segment of polyline
#define IS_LAST_SEG   (0x2)  // is the last segment of polyline
#define HAS_PREV_LINE (0x4)  // if there is a segment connects to start point
#define HAS_POST_LINE (0x8)  // if there is a segment connects to end point

// mask/offset for primitive flags

// low 24 bits are primitive id
#define PRIM_ID_MASK  (0x0fffffff)
// high 4 bits are primitive flag
#define PRIM_FLAG_MASK (0xf0000000)
#define PRIM_FLAG_OFFSET (28)

// low 16-bits are vertex id
#define POS_ID_MASK (0x0000ffff)
// high 16-bits are reference vertex id for closed polyline:
// reference vertex is last vertex if current vertex is first vertex
// reference vertex is second vertex if current vertex is last vertex,
//    because last vertex is the same as first vertex
#define REF_POS_ID_MASK (0xffff0000)
#define REF_POS_ID_OFFSET (16)

// the highest bit of caps index is if this vertex is end point of segment.
#define IS_END_POINT (0x80000000)
// low 16 bits of caps index is the vertex index
#define CAPS_IDX_MASK (0x0000ffff)
// the shape type mask
#define SHAPE_TYPE_MASK (0x7fff0000)
#define SHAPE_TYPE_OFFSET (16)

// low 16-bits of input width is line-width
#define WIDTH_MASK (0x0000ffff)

// bits 16-25 of input width is line-type index
#define LINE_TYPE_MASK (0x03ff0000)
#define LINE_TYPE_OFFSET (16)
// bits 30-31 of input width is caps type
#define CAPS_TYPE_MASK (0xc0000000)
#define CAPS_TYPE_OFFSET (30)
// bits 28-29 of input width is joint type
#define JOINT_TYPE_MASK (0x30000000)
#define JOINT_TYPE_OFFSET (28)

// bit 27 of input width is closed flag
#define CLOSED_MASK  (0x08000000)
#define CLOSED_OFFSET (27)
// bit 26 of input width is logical space flag
#define LOGIC_SPACE_MASK  (0x04000000)
#define LOGIC_SPACE_OFFSET (26)

// expand constants
static const float SINGLE_LINE_WIDTH = 1.0f;
static const float SINGLE_LINE_WIDTH_EXPAND = 1.2f;
static const float LINE_WEIGHT_EXPAND = 2.0f;
static const float ENDPOINT_EXTEND = 1.0f / 3.0f;

// screen constants
static const float SCR_GUARD_BAND_X = 8192.0f;
static const float SCR_GUARD_BAND_Y = 8192.0f;

struct LineVertex_Input
{
    int VertexID;
    int SegmentID;
    int2 PrimID; // x - start point index, y - line index + flags  
};

void load_line_input(uint vid, uint iid, Texture2D<uint> indexTex, out LineVertex_Input vs_input)
{
    vs_input.VertexID = vid;

    int2 index_offset = get_ptex_offset(iid);
    uint index = indexTex.Load(int3(index_offset, 0));
    vs_input.SegmentID = index;

    int2 prim_offset = get_ptex_offset(index);
    uint2 primIndex = gLineSegTex.Load(int3(prim_offset, 0));

    vs_input.PrimID.x = primIndex.x;
    vs_input.PrimID.y = primIndex.y;
}

void load_hatch_line_input(uint vid, uint iid, Texture2D<uint> indexTex, out LineVertex_Input vs_input)
{
    vs_input.VertexID = vid;

    int2 index_offset = get_ptex_offset(iid);
    uint index = indexTex.Load(int3(index_offset, 0));
    vs_input.SegmentID = index;

    int2 prim_offset = get_ptex_offset(index);
    uint2 primIndex = gHatchLineSegTex.Load(int3(prim_offset, 0));

    vs_input.PrimID.x = primIndex.x;
    vs_input.PrimID.y = primIndex.y;
}

void load_gradient_line_input(uint vid, uint iid, Texture2D<uint> indexTex, out LineVertex_Input vs_input)
{
    vs_input.VertexID = vid;

    int2 index_offset = get_ptex_offset(iid);
    uint index = indexTex.Load(int3(index_offset, 0));
    vs_input.SegmentID = index;

    int2 prim_offset = get_ptex_offset(index);
    uint2 primIndex = gGradientLineSegTex.Load(int3(prim_offset, 0));

    vs_input.PrimID.x = primIndex.x;
    vs_input.PrimID.y = primIndex.y;
}

// get information from vertex id
uint get_pos_id(uint vtx_id)
{
    return (vtx_id&POS_ID_MASK);
}

uint get_ref_pos_id(uint vtx_id)
{
    return (vtx_id&REF_POS_ID_MASK) >> REF_POS_ID_OFFSET;
}

uint get_prev_pos_id(uint vtx_id, uint flag)
{
    if ((flag&IS_FIRST_SEG) == 0)
        return get_pos_id(vtx_id) - 1;
    else
        return get_ref_pos_id(vtx_id);
}

uint get_post_pos_id(uint vtx_id, uint flag)
{
    if ((flag&IS_LAST_SEG) == 0)
        return get_pos_id(vtx_id) + 2;
    else
        return get_ref_pos_id(vtx_id);
}

// get information from primitive id
uint get_prim_flag(uint prim_id)
{
    return (prim_id&PRIM_FLAG_MASK) >> PRIM_FLAG_OFFSET;
}

uint get_prim_id(uint prim_id)
{
    return (prim_id&PRIM_ID_MASK);
}

// expand line weight
float get_line_weight_expand(float weight)
{
    return weight + LINE_WEIGHT_EXPAND;
}


// load line position infomation
void load_line_vertex(uint offset, out float2 pos)
{
    int2 vertex_offset = get_ptex_offset(offset);
    pos = gVertexTex.Load(int3(vertex_offset, 0));
}

void load_line_position(uint offset, out float2 start_point, out float2 end_point)
{
    load_line_vertex(offset, start_point);
    load_line_vertex(offset + 1, end_point);
}



// load hatch line position infomation
void load_hatch_line_vertex(uint offset, out float2 pos)
{
    int2 vertex_offset = get_ptex_offset(offset);
    pos = gHatchVertexTex.Load(int3(vertex_offset, 0));
}

void load_hatch_line_position(uint offset, out float2 start_point, out float2 end_point)
{
    load_hatch_line_vertex(offset, start_point);
    load_hatch_line_vertex(offset + 1, end_point);
}



// load gradient line position infomation
void load_gradient_line_vertex(uint offset, out float2 pos, out uint color)
{
    int2 vertex_offset = get_ptex_offset(offset);
    float3 val = gGradientVertexTex.Load(int3(vertex_offset, 0));
    pos = val.xy;
    color = asuint(val.z);
}

void load_gradient_line_position(uint offset, out float2 start_point, out float2 end_point, out uint start_color, out uint end_color)
{
    load_gradient_line_vertex(offset, start_point, start_color);
    load_gradient_line_vertex(offset + 1, end_point, end_color);
}

// load line flag
void load_line_flag(uint line_flag, out uint flag)
{
    flag = line_flag;
}

// load line information from width 
uint get_caps_type(uint width_flag)
{
    return (width_flag&CAPS_TYPE_MASK) >> CAPS_TYPE_OFFSET;
}
uint get_joint_type(uint width_flag)
{
    return (width_flag&JOINT_TYPE_MASK) >> JOINT_TYPE_OFFSET;
}

uint get_logic_space_flag(uint width_flag)
{
    return (width_flag&LOGIC_SPACE_MASK) >> LOGIC_SPACE_OFFSET;
}

uint get_width(uint width_flag)
{
    return (width_flag&WIDTH_MASK);
}
uint get_line_type(uint width_flag)
{
    return (width_flag&LINE_TYPE_MASK) >> LINE_TYPE_OFFSET;
}

bool get_is_closed(uint width_flag)
{
    return (width_flag&CLOSED_MASK) != 0;
}


void load_line_attributes_common(float4 line_val, out uint color, out uint width, out uint lt_index, out float drawZ, out uint glowColor, out uint capsType, out uint jointType, out uint logical_flag)
{
    color = asuint(line_val.x);
    width = get_width(asuint(line_val.y));
    lt_index = get_line_type(asuint(line_val.y));
    drawZ = line_val.z;
    glowColor = asuint(line_val.w);
    capsType = get_caps_type(asuint(line_val.y));
    jointType = get_joint_type(asuint(line_val.y));
    logical_flag = get_logic_space_flag(asuint(line_val.y));
}

// load all attributes function
void load_line_attributes(uint lineIndex, out uint color, out uint width, out uint lt_index, out float drawZ, out uint glowColor, out uint capsType, out uint jointType, out uint logical_flag)
{
    int2 line_offset = get_ptex_offset(lineIndex*2);
    float4 line_val = gLineTex.Load(int3(line_offset, 0));
    load_line_attributes_common(line_val, color, width, lt_index, drawZ, glowColor, capsType, jointType, logical_flag);
}

// load all attributes function
void load_hatch_line_attributes(uint lineIndex, out uint color, out uint width, out uint lt_index, out float drawZ, out uint glowColor, out uint capsType, out uint jointType, out uint logical_flag)
{
    int2 line_offset = get_ptex_offset(lineIndex);
    float4 line_val = gHatchLineTex.Load(int3(line_offset, 0));
    load_line_attributes_common(line_val, color, width, lt_index, drawZ, glowColor, capsType, jointType, logical_flag);
}

// load all attributes function
void load_gradient_line_attributes(uint lineIndex, out float drawZ, out uint logical_flag)
{
    int2 line_offset = get_ptex_offset(lineIndex);
    float2 line_val = gGradientLineTex.Load(int3(line_offset, 0));

    drawZ = line_val.y;
    logical_flag = get_logic_space_flag(asuint(line_val.x));
}


void load_line_attributes_neutron_sketch_common(float4 line_val, out uint logical_width, out uint stipple_index, out uint logical_lt)
{
    logical_width = asuint(line_val.x);
    stipple_index = asuint(line_val.y) & 0xffff;
    logical_lt = (asuint(line_val.y) & 0x10000) >> 16;
}

// load all attributes for neutron sketch function
void load_line_attributes_neutron_sketch(uint lineIndex, out uint logical_width, out uint stipple_index, out uint logical_lt)
{
    int2 line_offset = get_ptex_offset(lineIndex*2+1);
    float4 line_val = gLineTex.Load(int3(line_offset, 0));
    load_line_attributes_neutron_sketch_common(line_val, logical_width, stipple_index, logical_lt);
}


// clipping a point with guard band
bool adjust_point_precision(inout float2 pnt, float2 delta)
{
    bool out_range = false;

    // if out of guard band in x direction
    if (abs(pnt.x) > SCR_GUARD_BAND_X)
    {
        // move point to x guard band
        pnt.y = pnt.y - (pnt.x - sign(pnt.x)*SCR_GUARD_BAND_X) / delta.x*delta.y;
        pnt.x = sign(pnt.x)*SCR_GUARD_BAND_X;

        out_range = true;
    }

    // if out of guard band in y direction
    if (abs(pnt.y) > SCR_GUARD_BAND_Y)
    {
        // move point to y guard band
        pnt.x = pnt.x - (pnt.y - sign(pnt.y)*SCR_GUARD_BAND_Y) / delta.y*delta.x;
        pnt.y = sign(pnt.y)*SCR_GUARD_BAND_Y;

        out_range = true;
    }

    // return if out of guard band
    return out_range;
}

// if out of guard band in x direction for vertical line
bool is_vert_out_range(float2 delta, float2 pnt)
{
    if (abs(delta.x) < EPS)
    {
        if (abs(pnt.x) > SCR_GUARD_BAND_X)
            return true;
        else
            return false;
    }
    else
        return false;
}
// if out of guard band in y direction for horizontal line
bool is_horiz_out_range(float2 delta, float2 pnt)
{
    if (abs(delta.y) < EPS)
    {
        if (abs(pnt.y) > SCR_GUARD_BAND_Y)
            return true;
        else
            return false;
    }
    else
        return false;
}

// use guard band clipping to keep precision
bool2 adjust_line_segment_precision(inout float2 start_point, inout float2 end_point)
{
    // get start/end point difference
    float2 delta = end_point - start_point;

    // check vertical and horizontal line
    if (is_vert_out_range(delta, start_point) ||
        is_horiz_out_range(delta, start_point))
        return bool2(false, false);
    else
    {
        // move start/end point to guard band if out of range
        bool2 out_range;
        out_range.x = adjust_point_precision(start_point, delta);
        out_range.y = adjust_point_precision(end_point, delta);

        return out_range;
    }
}

// se guard band clipping to keep precision for logical position
void adjust_line_segment_precision_logical(inout float2 start_point, inout float2 end_point)
{
    // transform to screen position
    float2 startPoint = start_point;
    float2 endPoint = end_point;

    float2 s_start = ndc_to_screen(logic_to_ndc(start_point));
    float2 s_end = ndc_to_screen(logic_to_ndc(end_point));
    bool2 needAdjust = adjust_line_segment_precision(s_start, s_end);

    // transform back to logical position
    if (needAdjust.x)
        start_point = ndc_to_logic(screen_to_ndc_pos(s_start));
    else
        start_point = startPoint;
    if (needAdjust.y)
        end_point = ndc_to_logic(screen_to_ndc_pos(s_end));
    else
        end_point = endPoint;
}

// get line envelope position
float2 get_line_envelope_pos(int vid, uint line_width, float2 start_point, float2 end_point, out float dist)
{
    float weight_expand = get_line_weight_expand(line_width);
    float2 uv = get_rect_pos(vid);

    float2 dir = normalize(end_point - start_point);

    // extend envelope shape to cover all pixels include aa pixels
    float2 expand_start_point = start_point - dir*ENDPOINT_EXTEND;
    float2 expand_end_point = end_point + dir*ENDPOINT_EXTEND;


    float wide_line_expand = weight_expand*0.5f + 1.0f;

    // get screen position of envelope shape based on vertex id
    float2 scr_pos = (1 - uv.x)*expand_start_point * 0.5f +
        (1 + uv.x)*expand_end_point * 0.5f +
        uv.y * wide_line_expand * float2(dir.y, -dir.x);


    // offset screen position.
    scr_pos += float2(0.5f, 0.5f);

    dist = uv.y*(wide_line_expand);

    return screen_to_ndc_pos(scr_pos);
}

void load_wide_line_input(uint vid, uint iid, Texture2D<uint> indexTex, out LineVertex_Input vs_input, out uint shapeType, out bool isEndPoint)
{
    vs_input.VertexID = vid;

    int2 index_offset = get_ptex_offset(iid);
    uint index = indexTex.Load(int3(index_offset, 0));

    shapeType = (index&SHAPE_TYPE_MASK) >> SHAPE_TYPE_OFFSET;
    isEndPoint = (index&IS_END_POINT) != 0;
    vs_input.SegmentID = (index&CAPS_IDX_MASK);

    int2 prim_offset = get_ptex_offset(vs_input.SegmentID);
    uint2 primIndex = gLineSegTex.Load(int3(prim_offset, 0));

    vs_input.PrimID.x = primIndex.x;
    vs_input.PrimID.y = primIndex.y;
}

#endif
