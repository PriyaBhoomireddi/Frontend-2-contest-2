#include "Sketch_screen10.fxh"

Texture2D gRetainedTex : RetainedTexture;
SamplerState gRetainedSamp : RetainedSampler;
float2 gRetainedVec : RetainedVector;
float4 gRetainedHalo : RetainedHalo;
float4 gInvalidatedBox : InvalidatedBox;

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

VS_TO_PS Repair_VS(VS_INPUT In)
{
    VS_TO_PS Out;
    Out.HPos = float4(In.Pos, 1.0f);
    Out.UV = In.UV;
    return Out;
}

float4 Repair_PS(VS_TO_PS In) : SV_Target
{
    float2 rUV = In.UV + gRetainedVec;

    if (any(rUV < gRetainedHalo.xy) || any(rUV > float2(1.0f, 1.0f) - gRetainedHalo.zw))
    {
        discard;
        return float4(0.0f, 0.0f, 0.0f, 0.0f);
    }

    if (all(rUV >= gInvalidatedBox.xy) && all(rUV <= gInvalidatedBox.zw))
    {
        discard;
        return float4(0.0f, 0.0f, 0.0f, 0.0f);
    }

    return gRetainedTex.Sample(gRetainedSamp, rUV);
}

technique11 Repair
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Repair_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Repair_PS()));
    }
}