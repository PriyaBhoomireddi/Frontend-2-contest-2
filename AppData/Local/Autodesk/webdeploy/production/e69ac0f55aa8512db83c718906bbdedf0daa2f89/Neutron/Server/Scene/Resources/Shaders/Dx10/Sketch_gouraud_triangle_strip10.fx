#include "Sketch_triangle10.fxh"
#include "Sketch_logical_precision10.fxh"

// for gouraud triangles we don't need glow texture because glow on those 
// triangles will go through simple triangle pipeline with same colors on
// all vertices and with no interpolation
//
// Gourand triangle strip vertex texture structure:
// 1. coordinates of vertex (2 floats)
// 2. color (1 float)
// 3. primitive index (1 float)
Texture2D<float4> gGouraudTriStripVertexTex : GouraudTriangleStripVertexTexture;

// Gourand triangle strip primitive texture structure:
// depth and logical flag shared value
Texture2D<float> gGouraudTriStripPrimTex: GouraudTriangleStripPrimTexture;

// Gouraud triangle strip index texture structure:
// index value of current triangle strip
Texture2D<uint> gGouraudTriStripIndexTex : GouraudTriangleStripIndexTexture;

void load_current_gouraud_vertex(uint offset, out float2 pos, out uint prim_id, out uint color)
{
    int2 ver_offset = get_ptex_offset(offset);
    float4 val = gGouraudTriStripVertexTex.Load(int3(ver_offset, 0));

    pos = val.xy;
    color = asuint(val.z);
    prim_id = asuint(val.w);
}

void load_gouraud_primitive(uint prim_id,
    out float drawZ,
    out bool isLogical)
{
    int2 offset = get_ptex_offset(prim_id);
    float2 prims = gGouraudTriStripPrimTex.Load(int3(offset, 0));

    drawZ = abs(prims.x);

    isLogical = get_logical_space(prims.x);
}

void load_gouraud_triangle_info(uint ver_index, out TriVertexAttr attr)
{
    load_current_gouraud_vertex(ver_index, attr.pos, attr.prim_id, attr.color);

    load_gouraud_primitive(attr.prim_id, attr.drawZ, attr.isLogical);
}

VertexAttr_Gouraud_Triangle GouraudTriangleStrip_VS(NullVertex_Input input)
{
    TriVertexAttr attr = (TriVertexAttr)0;

    uint vtx_id = load_tri_id_from_tex(gGouraudTriStripIndexTex, input.VertexID);

    load_gouraud_triangle_info(vtx_id, attr);

    VertexAttr_Gouraud_Triangle output = (VertexAttr_Gouraud_Triangle)0;
    set_gouraud_triangle_properties(attr, output);

    return output;
}

OIT_PS_HEADER(GouraudTriangle_PS, VertexAttr_Gouraud_Triangle)
{
    OIT_PS_OUTPUT(input.color, input.position);
}

technique11 GouraudTriangleStrip
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, GouraudTriangleStrip_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, GouraudTriangle_PS()));
    }
}
