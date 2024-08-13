
Texture2D gTex0 : Texture0;
Texture2D gTex1 : Texture1;
Texture2D gTex2 : Texture2;
Texture2D gTex3 : Texture3;
Texture2D gTex4 : Texture4;
Texture2D gTex5 : Texture5;
Texture2D gTex6 : Texture6;
Texture2D gTex7 : Texture7;

SamplerState gSamp0 : Sampler0;
SamplerState gSamp1 : Sampler1;
SamplerState gSamp2 : Sampler2;
SamplerState gSamp3 : Sampler3;
SamplerState gSamp4 : Sampler4;
SamplerState gSamp5 : Sampler5;
SamplerState gSamp6 : Sampler6;
SamplerState gSamp7 : Sampler7;

float4 gColor[32] : Color;
int gPackedCount[8] : PackedCount;

struct VS_INPUT
{
    float3 Pos : POSITION;
    float2 UV : TEXCOORD0;
};

struct VS_TO_PS
{
    float4 HPos : SV_Position;
    float2 UV : TEXCOORD0;
};

VS_TO_PS Composite_VS(VS_INPUT In)
{
    VS_TO_PS Out;
    Out.HPos = float4(In.Pos, 1.0f);
    Out.UV = In.UV;
    return Out;
}

float4 composite_rgba_associative(float4 C1, float4 C2)
{
    float4 Cx;
    Cx.a = 1.0f - (1.0f - C1.a) * (1.0f - C2.a);
    Cx.rgb = C2.rgb + C1.rgb * (1.0f - C2.a);
    return Cx;
}

float4 composite_packed_layers(float4 Cx, float4 Tx, int Txn, float4 Color0, float4 Color1, float4 Color2, float4 Color3)
{
    float4 Cy;

    Cy = Color0;
    Cy.a *= lerp(0.0f, Tx.b, float(Txn >= 1));
    Cy.rgb *= Cy.a;
    Cx = composite_rgba_associative(Cx, Cy);

    Cy = Color1;
    Cy.a *= lerp(0.0f, Tx.g, float(Txn >= 2));
    Cy.rgb *= Cy.a;
    Cx = composite_rgba_associative(Cx, Cy);

    Cy = Color2;
    Cy.a *= lerp(0.0f, Tx.r, float(Txn >= 3));
    Cy.rgb *= Cy.a;
    Cx = composite_rgba_associative(Cx, Cy);

    Cy = Color3;
    Cy.a *= lerp(0.0f, Tx.a, float(Txn >= 4));
    Cy.rgb *= Cy.a;
    Cx = composite_rgba_associative(Cx, Cy);

    return Cx;
}

float4 composite_rgba_layer(float4 Cx, float4 Tx)
{
    float4 Cy = Tx;
    Cx = composite_rgba_associative(Cx, Cy);
    return Cx;
}

float4 composite_layers(float4 Cx, int i, Texture2D Tex, SamplerState Samp, float2 UV)
{
    int Txn = gPackedCount[i];
    if (Txn == 0)
    {
        return Cx;
    }
    else
    {
        float4 Tx = Tex.Sample(Samp, UV);
        if (Txn > 0)
        {
            float4 Color0 = gColor[i*4+0];
            float4 Color1 = gColor[i*4+1];
            float4 Color2 = gColor[i*4+2];
            float4 Color3 = gColor[i*4+3];
            Cx = composite_packed_layers(Cx, Tx, Txn, Color0, Color1, Color2, Color3);
        }
        else if (Txn < 0)
        {
            Cx = composite_rgba_layer(Cx, Tx);
        }
    }

    return Cx;
}

float4 Composite_PS(VS_TO_PS In) : SV_Target
{
    float4 Cx = float4(0.0f, 0.0f, 0.0f, 0.0f);

    Cx = composite_layers(Cx, 0, gTex0, gSamp0, In.UV);
    Cx = composite_layers(Cx, 1, gTex1, gSamp1, In.UV);
    Cx = composite_layers(Cx, 2, gTex2, gSamp2, In.UV);
    Cx = composite_layers(Cx, 3, gTex3, gSamp3, In.UV);
    Cx = composite_layers(Cx, 4, gTex4, gSamp4, In.UV);
    Cx = composite_layers(Cx, 5, gTex5, gSamp5, In.UV);
    Cx = composite_layers(Cx, 6, gTex6, gSamp6, In.UV);
    Cx = composite_layers(Cx, 7, gTex7, gSamp7, In.UV);

    return Cx;
}

technique11 Composite
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Composite_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Composite_PS()));
    }
}