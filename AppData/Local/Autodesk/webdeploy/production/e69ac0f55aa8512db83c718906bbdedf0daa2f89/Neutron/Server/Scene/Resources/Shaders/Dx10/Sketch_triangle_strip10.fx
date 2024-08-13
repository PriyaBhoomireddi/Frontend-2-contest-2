#include "Sketch_triangle10.fxh"
#include "Sketch_logical_precision10.fxh"

// Triangle strip vertex texture structure:
// 1. coordinates of vertex (2 floats)
// 2. primitive index (1 float)
Texture2D<float3> gTriStripVertexTex : TriangleStripVertexTexture;

// Triangle strip primitive texture structure:
// 1. depth and logical flag shared value (1 float)
// 2. color (1 float)
Texture2D<float2> gTriStripPrimTex: TriangleStripPrimTexture;

// Since triangle strip and glow triangle strip are in one buffer, we need
// index texture to know which triangle it is.
//
// Triangle strip index texture structure
// index value of current triangle strip
Texture2D<uint> gTriStripIndexTex : TriangleStripIndexTexture;

// Glow triangle strip index texture structure
// index value of current glow triangle strip
Texture2D<uint> gGlowTriStripIndexTex : GlowTriangleStripIndexTexture;

void load_current_vertex(uint offset, out float2 pos, out uint prim_id)
{
    int2 ver_offset = get_ptex_offset(offset);
    float3 val = gTriStripVertexTex.Load(int3(ver_offset, 0));

    pos = val.xy;
    prim_id = asuint(val.z);
}

void load_primitive(uint prim_id, out float drawZ,
                    out bool isLogical,
                    out uint color)
{
    int2 offset = get_ptex_offset(prim_id);
    float2 prims = gTriStripPrimTex.Load(int3(offset, 0));

    drawZ = abs(prims.x);
    isLogical = get_logical_space(prims.x);

    color = asuint(prims.y);
}

void load_triangle_info(uint ver_index, out TriVertexAttr attr)
{
    load_current_vertex(ver_index, attr.pos, attr.prim_id);

    load_primitive(attr.prim_id, attr.drawZ, 
                   attr.isLogical,
                   attr.color);
}

VertexAttr_Triangle TriangleStrip_VS(NullVertex_Input input)
{
    TriVertexAttr attr = (TriVertexAttr)0;

    uint vtx_id;

#ifdef ANALYTIC_HIGHLIGHT
        vtx_id = load_tri_id_from_tex(gGlowTriStripIndexTex, input.VertexID);
#else
        vtx_id = load_tri_id_from_tex(gTriStripIndexTex, input.VertexID);
#endif

    load_triangle_info(vtx_id, attr);

    VertexAttr_Triangle output = (VertexAttr_Triangle)0;
    set_triangle_properties(attr, output);

    return output;
}

OIT_PS_HEADER(Triangle_PS, VertexAttr_Triangle)
{
    OIT_PS_OUTPUT(input.color, input.position);
}

technique11 TriangleStrip
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, TriangleStrip_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Triangle_PS()));
    }
}