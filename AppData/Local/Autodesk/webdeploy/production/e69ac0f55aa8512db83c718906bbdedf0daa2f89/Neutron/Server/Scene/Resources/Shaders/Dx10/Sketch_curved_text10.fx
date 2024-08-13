#include "Sketch_text10.fxh"
#include "Sketch_logical_precision10.fxh"

// simple triangle list vertex texture structure (glow is the same):
// 1. coordinates, uvs of three vertices (12 floats)
// 2. depth and logical shared flag (1 float)
// 3. color (1 float)
// 4. triangle type (2 floats)
Texture2D<float4> gCurvedTextVertexTex : CurvedTextVertexTexture;

// Since simple triangle and simple glow triangle are in one buffer, we need
// index texture to know which triangle it is.
//
// simple triangle list index texture structure:
// index value of current triangle
Texture2D<uint> gCurvedTextIndexTex : CurvedTextIndexTexture;

// simple glow triangle list index texture structure:
// index value of current glow triangle
Texture2D<uint> gGlowCurvedTextIndexTex : GlowCurvedTextIndexTexture;
Texture2D<float> gCurvedTextDrawOrderZTex : CurvedTextDrawOrderZTex;

void load_vertex_info(uint instance_id, uint vertex_id, uint tri_id, out CurvedTextVertexAttr attr)
{
    int2 offset = get_ptex_offset(tri_id*4 + 3);
    float4 val = gCurvedTextVertexTex.Load(int3(offset, 0));

    if (vertex_id == 0)
    {
        int2 offset1 = get_ptex_offset(tri_id*4);
        float4 val1 = gCurvedTextVertexTex.Load(int3(offset1, 0));
        attr.pos = val1.xy;
        attr.uv = val1.zw;
    }
    else if (vertex_id == 1)
    {
        int2 offset1 = get_ptex_offset(tri_id*4 + 1);
        float4 val1 = gCurvedTextVertexTex.Load(int3(offset1, 0));
        attr.pos = val1.xy;
        attr.uv = val1.zw;
    }
    else
    {
        int2 offset1 = get_ptex_offset(tri_id*4 + 2);
        float4 val1 = gCurvedTextVertexTex.Load(int3(offset1, 0));
        attr.pos = val1.xy;
        attr.uv = val1.zw;
    }

    [branch]if (gRetainMode)
    {
        load_dynamic_draworderz(instance_id, gCurvedTextDrawOrderZTex, attr.drawZ);
        attr.isLogical = true;
    }
    else 
    {
        attr.isLogical = get_logical_space(val.z);
        attr.drawZ = abs(val.z);
    }

    attr.color = asuint(val.w);
    attr.triType = val.xy;
}

VertexAttr_Curved_Text CurvedText_VS(NullVertex_Input input)
{
    CurvedTextVertexAttr attr = (CurvedTextVertexAttr)0;

    uint tri_id;

#ifdef ANALYTIC_HIGHLIGHT
        tri_id = load_tri_id_from_tex(gGlowCurvedTextIndexTex, input.InstanceID);
#else
        tri_id = load_tri_id_from_tex(gCurvedTextIndexTex, input.InstanceID);
#endif

    load_vertex_info(input.InstanceID, input.VertexID, tri_id, attr);

    VertexAttr_Curved_Text output = (VertexAttr_Curved_Text)0;
    set_curved_text_properties(attr, output);

    return output;
}

OIT_PS_HEADER(CurvedText_PS, VertexAttr_Curved_Text)
{
    float alpha = 1.0f;

    if (input.triType.x <= 0.5f)
    {
        // The curve is u^2 - v, where (u, v) is the texture coordinate.
        //
        // As in the paper, the signed distance from the pixel to the curve g(x,y) is calculated as
        //
        //                           g(x, y)
        //      d(x, y) = ---------------------------------
        //                 || (g'x(x,y), g'y(x,y))||
        //
        // Here, g(x, y) = g(u(x, y), v(x, y)) = u(x, y) ^ 2 - v(x, y)
        // So, we can calculate the partial derivative:
        //
        //      g'x(x, y) = 2 * u(x, y) * u'x(x, y) - v'x(x, y)
        //      g'y(x, y) = 2 * u(x, y) * u'y(x, y) - v'y(x, y)
        //

        // g(x, y)
        float g = input.uv.x * input.uv.x - input.uv.y;

        // g'x(x, y)
        float pgdx = 2.0f * input.uv.x * ddx(input.uv.x) - ddx(input.uv.y);

        // g'y(x, y)
        float pgdy = 2.0f * input.uv.x * ddy(input.uv.x) - ddy(input.uv.y);

        //                           g(x, y)
        //      d(x, y) = ---------------------------------
        //                 || (g'x(x,y), g'y(x,y))||
        float dist = g / sqrt( pgdx * pgdx + pgdy * pgdy);

        // The anti-alias algorithm is simple.
        // If the distance from the pixel to the outline is larger than 0.5 and on the fill side,
        // we think the pixel should be fully filled, so alpha will be gOpacity.
        // If the distance from the pixel to the outline is larger than 0.5 and on the non-fill side,
        // we think the pixel should be empty, so alpha will be 0.0.
        // If the distance from the pixel to the outline is smaller than 0.5,
        // we think the coverage of the pixel is (0.5 - distance), so alpha will be gOpacity plus this minus.

        if (input.triType.y <= 0.5f)
            alpha = dist > 0.5f ? 1.0f : ( dist > -0.5f ? (0.5f + dist) : 0.0f);
        else
            alpha = dist < -0.5f ? 1.0f : ( dist < 0.5f ? (0.5f - dist) : 0.0f);
    }

    float4 final_color = float4(input.color.rgb, input.color.a * alpha);
    OIT_PS_OUTPUT(final_color, input.position);
}

technique11 CurvedText
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, CurvedText_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, CurvedText_PS()));
    }
}
