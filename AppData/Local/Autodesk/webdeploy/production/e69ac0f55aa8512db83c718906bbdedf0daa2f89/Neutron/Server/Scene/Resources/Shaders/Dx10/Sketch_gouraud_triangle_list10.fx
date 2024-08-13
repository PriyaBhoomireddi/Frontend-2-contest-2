#include "Sketch_triangle10.fxh"
#include "Sketch_logical_precision10.fxh"

// for gouraud triangles we don't need glow texture because glow on those 
// triangles will go through simple triangle pipeline with same colors on
// all vertices and with no interpolation
//
// Gouraud triangle list vertex texture structure:
// each vertex of triangle occupy a float4 buffer
// 1. coordinates of vertex (2 float)
// 2. depth and logical shared flag (1 float)
// 3. color (1 float)
Texture2D<float4> gGouraudTriListVertexTex : GouraudTriangleListVertexTexture;

// Gouraud triangle list index texture structure:
// index value of current triangle
Texture2D<uint> gGouraudTriListIndexTex : GouraudTriangleListIndexTexture;
Texture2D<float> gGouraudTriListDrawOrderZTex : GouraudTriListDrawOrderZTex;

void load_gouraud_vertex_info(uint instance_id, uint vertex_id, uint tri_id, out TriVertexAttr attr)
{
    int2 offset = int2(0, 0);
    float4 val = float4(0.f, 0.f, 0.f, 0.f);

    if (vertex_id == 0)
    {
        offset = get_ptex_offset(tri_id * 3);
        val = gGouraudTriListVertexTex.Load(int3(offset, 0));
    }
    else if (vertex_id == 1)
    {
        offset = get_ptex_offset(tri_id * 3 + 1);
        val = gGouraudTriListVertexTex.Load(int3(offset, 0));
    }
    else if (vertex_id == 2)
    {
        offset = get_ptex_offset(tri_id * 3 + 2);
        val = gGouraudTriListVertexTex.Load(int3(offset, 0));
    }
    attr.pos = val.xy;

    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(instance_id, gGouraudTriListDrawOrderZTex, attr.drawZ);
        attr.isLogical = true;
    }
    else
    {
        attr.isLogical = get_logical_space(val.z);
        attr.drawZ = abs(val.z);
    }

    attr.color = asuint(val.w);

    attr.prim_id = 0;
}

VertexAttr_Gouraud_Triangle GouraudTriangleList_VS(NullVertex_Input input)
{
    TriVertexAttr attr = (TriVertexAttr)0;

    uint tri_id = load_tri_id_from_tex(gGouraudTriListIndexTex, input.InstanceID);

    load_gouraud_vertex_info(input.InstanceID, input.VertexID, tri_id, attr);

    VertexAttr_Gouraud_Triangle output = (VertexAttr_Gouraud_Triangle)0;
    set_gouraud_triangle_properties(attr, output);

    return output;
}

OIT_PS_HEADER(GouraudTriangle_PS, VertexAttr_Gouraud_Triangle)
{
    OIT_PS_OUTPUT(input.color, input.position);
}

technique11 GouraudTriangleList
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, GouraudTriangleList_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, GouraudTriangle_PS()));
    }
}
