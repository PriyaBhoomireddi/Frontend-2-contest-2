#include "Sketch_triangle10.fxh"
#include "Sketch_logical_precision10.fxh"
#include "Sketch_stipple10.fxh"

// Triangle strip vertex texture structure:
// 1. coordinates of vertex (2 floats)
// 2. primitive index (1 float)
Texture2D<float3> gStippleTriStripVertexTex : StippleTriangleStripVertexTexture;

// Triangle strip primitive texture structure:
// 1. depth and logical flag shared value (1 float)
// 2. color (1 float)
// 3. stipple index (2 ushorts)
// 4. reserved
Texture2D<float4> gStippleTriStripPrimTex: StippleTriangleStripPrimTexture;

// Triangle strip index texture structure
// index value of current triangle strip
Texture2D<uint> gStippleTriStripIndexTex : StippleTriangleStripIndexTexture;

void load_current_vertex(uint offset, out float2 pos, out uint prim_id)
{
    int2 ver_offset = get_ptex_offset(offset);
    float3 val = gStippleTriStripVertexTex.Load(int3(ver_offset, 0));

    pos = val.xy;
    prim_id = asuint(val.z);
}

void load_primitive(uint prim_id, out float drawZ,
                    out bool isLogical,
                    out uint color,
                    out uint stipple_index)
{
    int2 offset = get_ptex_offset(prim_id);
    float4 prims = gStippleTriStripPrimTex.Load(int3(offset, 0));

    drawZ = abs(prims.x);
    isLogical = get_logical_space(prims.x);

    color = asuint(prims.y);
    stipple_index = asuint(prims.z) & 0xffff;
}

void load_triangle_info(uint ver_index, out StippleTriVertexAttr attr)
{
    load_current_vertex(ver_index, attr.pos, attr.prim_id);

    load_primitive(attr.prim_id, attr.drawZ, 
                   attr.isLogical,
                   attr.color,
                   attr.stipple_index);
}

VertexAttr_Stipple_Triangle StippleTriangleStrip_VS(NullVertex_Input input)
{
    StippleTriVertexAttr attr = (StippleTriVertexAttr)0;

    uint vtx_id = load_tri_id_from_tex(gStippleTriStripIndexTex, input.VertexID);
    load_triangle_info(vtx_id, attr);

    VertexAttr_Stipple_Triangle output = (VertexAttr_Stipple_Triangle)0;
    set_stipple_triangle_properties(attr, output);

    return output;
}

OIT_PS_HEADER(StippleTriangle_PS, VertexAttr_Stipple_Triangle)
{
    // get pixel position
    float2 pixel_pos = input.position.xy;
    pixel_pos.y = gScreenSize.y - pixel_pos.y;

    float4 final_color = neutron_sketch_stipple_apply(input.color, pixel_pos, input.stipple_index);
    OIT_PS_OUTPUT(final_color, input.position);
}

technique11 StippleTriangleStrip
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, StippleTriangleStrip_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, StippleTriangle_PS()));
    }
}