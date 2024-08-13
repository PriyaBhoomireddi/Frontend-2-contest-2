#include "Sketch_triangle10.fxh"
#include "Sketch_logical_precision10.fxh"
#include "Sketch_stipple10.fxh"

// stipple triangle list vertex texture structure:
// 1. coordinates of three vertices (6 floats)
// 2. depth and logical shared flag (1 float)
// 3. color (1 float)
// 4. stipple index (2 ushorts)
Texture2D<float4> gStippleTriListVertexTex : StippleTriangleListVertexTexture;

// stipple triangle list index texture structure:
// index value of current triangle
Texture2D<uint> gStippleTriListIndexTex : StippleTriangleListIndexTexture;

void load_vertex_info(uint instance_id, uint vertex_id, uint tri_id, out StippleTriVertexAttr attr)
{
    int2 offset = get_ptex_offset(tri_id*3 + 1);
    float4 val = gStippleTriListVertexTex.Load(int3(offset, 0));

    int2 offset2 = get_ptex_offset(tri_id*3 + 2);
    float4 val2 = gStippleTriListVertexTex.Load(int3(offset2, 0));

    if (vertex_id == 0)
    {
        int2 offset1 = get_ptex_offset(tri_id*3);
        attr.pos = gStippleTriListVertexTex.Load(int3(offset1, 0)).xy;
    }
    else if (vertex_id == 1)
    {
        int2 offset1 = get_ptex_offset(tri_id*3);
        attr.pos = gStippleTriListVertexTex.Load(int3(offset1, 0)).zw;
    }
    else if (vertex_id == 2)
    {
        attr.pos = val.xy;
    }

    attr.isLogical = get_logical_space(val.z);
    attr.drawZ = abs(val.z);
    attr.color = asuint(val.w);
    attr.prim_id = 0;
    attr.stipple_index = asuint(val2.x) & 0xffff;
}

VertexAttr_Stipple_Triangle StippleTriangleList_VS(NullVertex_Input input)
{
    StippleTriVertexAttr attr = (StippleTriVertexAttr)0;

    uint tri_id = load_tri_id_from_tex(gStippleTriListIndexTex, input.InstanceID);
    load_vertex_info(input.InstanceID, input.VertexID, tri_id, attr);

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

technique11 StippleTriangleList
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, StippleTriangleList_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, StippleTriangle_PS()));
    }
}