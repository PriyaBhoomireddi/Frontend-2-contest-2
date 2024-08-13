#include "Sketch_triangle10.fxh"
#include "Sketch_logical_precision10.fxh"

// simple triangle list vertex texture structure (glow is the same):
// 1. coordinates of three vertices (6 floats)
// 2. depth and logical shared flag (1 float)
// 3. color (1 float)
Texture2D<float4> gSimpleTriListVertexTex : SimpleTriangleListVertexTexture;

// Since simple triangle and simple glow triangle are in one buffer, we need
// index texture to know which triangle it is.
//
// simple triangle list index texture structure:
// index value of current triangle
Texture2D<uint> gSimpleTriListIndexTex : SimpleTriangleListIndexTexture;

// simple glow triangle list index texture structure:
// index value of current glow triangle
Texture2D<uint> gGlowTriListIndexTex : GlowTriangleListIndexTexture;
Texture2D<float> gTriListDrawOrderZTex : TriListDrawOrderZTex;

void load_vertex_info(uint instance_id, uint vertex_id, uint tri_id, out TriVertexAttr attr)
{
    int2 offset = get_ptex_offset(tri_id*2 + 1);
    float4 val = gSimpleTriListVertexTex.Load(int3(offset, 0));

    if (vertex_id == 0)
    {
        int2 offset1 = get_ptex_offset(tri_id*2);
        attr.pos = gSimpleTriListVertexTex.Load(int3(offset1, 0)).xy;
    }
    else if (vertex_id == 1)
    {
        int2 offset1 = get_ptex_offset(tri_id*2);
        attr.pos = gSimpleTriListVertexTex.Load(int3(offset1, 0)).zw;
    }
    else if (vertex_id == 2)
    {
        attr.pos = val.xy;
    }

    [branch]if (gRetainMode)
    {
        load_dynamic_draworderz(instance_id, gTriListDrawOrderZTex, attr.drawZ);
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

VertexAttr_Triangle TriangleList_VS(NullVertex_Input input)
{
    TriVertexAttr attr = (TriVertexAttr)0;

    uint tri_id;

#ifdef ANALYTIC_HIGHLIGHT
        tri_id = load_tri_id_from_tex(gGlowTriListIndexTex, input.InstanceID);
#else
        tri_id = load_tri_id_from_tex(gSimpleTriListIndexTex, input.InstanceID);
#endif

    load_vertex_info(input.InstanceID, input.VertexID, tri_id, attr);

    VertexAttr_Triangle output = (VertexAttr_Triangle)0;
    set_triangle_properties(attr, output);

    return output;
}

OIT_PS_HEADER(Triangle_PS, VertexAttr_Triangle)
{
    OIT_PS_OUTPUT(input.color, input.position);
}

technique11 TriangleList
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, TriangleList_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Triangle_PS()));
    }
}