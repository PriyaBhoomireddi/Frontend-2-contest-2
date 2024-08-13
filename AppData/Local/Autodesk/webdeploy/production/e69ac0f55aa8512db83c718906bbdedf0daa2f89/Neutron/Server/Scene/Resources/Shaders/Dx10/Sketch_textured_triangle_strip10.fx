#include "Sketch_triangle10.fxh"
#include "Sketch_logical_precision10.fxh"

// simple triangle strip vertex texture structure (glow is the same):
// 1. coordinates (2 floats)
// 2. uv  (2 floats)
// 3. primitive index + unused (2 floats)
Texture2D<float3> gTexturedTriStripVertexTex : TexturedTriangleStripVertexTexture;

// Textured triangle strip primitive texture structure:
// depth and logical flag shared value
Texture2D<float4> gTexturedTriStripPrimTex: TexturedTriangleStripPrimTexture;

// Textured triangle list index texture structure:
// index value of current triangle
Texture2D<uint> gTexturedTriStripIndexTex : TexturedTriangleStripIndexTexture;

// Bulk of different input textures.
Texture2D<float4> gColorTexture0 : ColorTexture0;
Texture2D<float4> gColorTexture1 : ColorTexture1;
Texture2D<float4> gColorTexture2 : ColorTexture2;
Texture2D<float4> gColorTexture3 : ColorTexture3;
Texture2D<float4> gColorTexture4 : ColorTexture4;
Texture2D<float4> gColorTexture5 : ColorTexture5;
Texture2D<float4> gColorTexture6 : ColorTexture6;
Texture2D<float4> gColorTexture7 : ColorTexture7;
SamplerState gTexSamp0 : TextureSampler0;
SamplerState gTexSamp1 : TextureSampler1;
SamplerState gTexSamp2 : TextureSampler2;
SamplerState gTexSamp3 : TextureSampler3;
SamplerState gTexSamp4 : TextureSampler4;
SamplerState gTexSamp5 : TextureSampler5;
SamplerState gTexSamp6 : TextureSampler6;
SamplerState gTexSamp7 : TextureSampler7;

void load_textured_triangle_strip_info(uint vtx_id, out TexTriVertexAttr attr)
{
    int2 ver_offset = get_ptex_offset(vtx_id * 2);
    float3 val = gTexturedTriStripVertexTex.Load(int3(ver_offset, 0));

    int2 ver_offset1 = get_ptex_offset(vtx_id * 2 + 1);
    float3 val1 = gTexturedTriStripVertexTex.Load(int3(ver_offset1, 0));

    int2 prim_offset = get_ptex_offset(asuint(val1.z) * 2);
    float4 prims = gTexturedTriStripPrimTex.Load(int3(prim_offset, 0));

    int2 prim_offset1 = get_ptex_offset(asuint(val1.z) * 2 + 1);
    float4 prims1 = gTexturedTriStripPrimTex.Load(int3(prim_offset1, 0));

    attr.pos = val.xy;
    attr.uv = val1.xy;
    attr.uv.y = 1.0f - attr.uv.y;
    attr.uv = attr.uv * prims1.xy + prims1.zw;

    attr.drawZ = abs(prims.x);
    attr.isLogical = get_logical_space(prims.x);
    attr.color = asuint(prims.y);
    attr.tex_index = asuint(prims.z);
}

VertexAttr_Textured_Triangle TexturedTriangleStrip_VS(NullVertex_Input input)
{
    TexTriVertexAttr attr = (TexTriVertexAttr)0;

    uint vtx_id = load_tri_id_from_tex(gTexturedTriStripIndexTex, input.VertexID);

    load_textured_triangle_strip_info(vtx_id, attr);

    VertexAttr_Textured_Triangle output = (VertexAttr_Textured_Triangle)0;
    set_textured_triangle_properties(attr, output);

    return output;
}

OIT_PS_HEADER(TexturedTriangle_PS, VertexAttr_Textured_Triangle)
{
    uint tex_index = (input.tex_index & 0xFFFF);
    uint tex_rgb_order = ((input.tex_index & 0x10000) >> 16);
    uint tex_alpha_only = ((input.tex_index & 0x20000) >> 17);

    float4 tex_color;
    if (tex_index == 0)
        tex_color = gColorTexture0.Sample(gTexSamp0, input.uv);
    else if (tex_index == 1)
        tex_color = gColorTexture1.Sample(gTexSamp1, input.uv);
    else if (tex_index == 2)
        tex_color = gColorTexture2.Sample(gTexSamp2, input.uv);
    else if (tex_index == 3)
        tex_color = gColorTexture3.Sample(gTexSamp3, input.uv);
    else if (tex_index == 4)
        tex_color = gColorTexture4.Sample(gTexSamp4, input.uv);
    else if (tex_index == 5)
        tex_color = gColorTexture5.Sample(gTexSamp5, input.uv);
    else if (tex_index == 6)
        tex_color = gColorTexture6.Sample(gTexSamp6, input.uv);
    else if (tex_index == 7)
        tex_color = gColorTexture7.Sample(gTexSamp7, input.uv);
    else
        tex_color = float4(0.0f, 0.0f, 0.0f, 0.0f);

    if (tex_alpha_only)
    {
        tex_color = float4(1.0f, 1.0f, 1.0f, tex_color.a);
    }

    if (!tex_rgb_order)
    {
        float t_color = tex_color.r;
        tex_color.r = tex_color.b;
        tex_color.b = t_color;
    }

    float4 final_color = tex_color * input.color;
    OIT_PS_OUTPUT(final_color, input.position);
}

technique11 TexturedTriangleStrip
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, TexturedTriangleStrip_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, TexturedTriangle_PS()));
    }
}
