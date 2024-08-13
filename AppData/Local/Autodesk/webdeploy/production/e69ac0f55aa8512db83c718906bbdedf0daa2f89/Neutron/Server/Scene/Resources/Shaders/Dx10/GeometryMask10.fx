//**************************************************************************/
// Copyright (c) 2009 Autodesk, Inc.
// All rights reserved.
// 
// These coded instructions, statements, and computer programs contain
// unpublished proprietary information written by Autodesk, Inc., and are
// protected by Federal copyright law. They may not be disclosed to third
// parties or copied or duplicated in any form, in whole or in part, without
// the prior written consent of Autodesk, Inc.
//**************************************************************************/
// AUTHOR: Charlotta Wadman
// DESCRIPTION: Geometry mask. Render the input geometry with a specified color.
// CREATED: November 2009
//**************************************************************************/

#include "Clipping10.fxh" // D3D10 ONLY

// World transformation, needed only for clipping
float4x4 gWXf : World < string UIWidget = "None"; >;

// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection < string UIWidget = "None"; >;


float4 gMaskColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

// Depth priority, which shifts the model a bit forward in the z-buffer
float gDepthPriority : DepthPriority
<
    string UIName =  "Depth Priority";
    string UIWidget = "Slider";
    float UIMin = -16/1048576.0f;    // divide by 2^24/16 by default
    float UIMax = 16/1048576.0f;
    float UIStep = 1/1048576.0f;
> = 0.0f;

// The visibility texture.
Texture2D gVisibilityTex : Texture = NULL;

// Visibility texture sampler.
SamplerState gSamp : TextureSampler;

// Vertex shader input structure.
struct VS_INPUT
{
    float3 Pos : POSITION;
};

// Vertex shader output structure.
struct VS_TO_PS
{
    float4 HPos : SV_Position;
    
    // D3D10 ONLY
    // Clip distances, for eight clipping planes.
    float4 ClipDistances0 : SV_ClipDistance0;
    float4 ClipDistances1 : SV_ClipDistance1;
};

// Vertex shader output structure for text technique.
struct VS_TO_PS_Text
{
    VS_TO_PS BasicVSToPS;
    float4 VPos : TEXCOORD0;
};

// Basic vertex shader function.
VS_TO_PS VSBasic(VS_INPUT In)
{
    VS_TO_PS Out;
    
    // Transform the position from object space to clip space for output.
    Out.HPos = mul(float4(In.Pos, 1.0f), gWVPXf);
   
    // modify the HPos a bit by biasing the Z a bit forward, based on depth priority
    Out.HPos.z -= Out.HPos.w*gDepthPriority;

    // Compute the eight clip distances. D3D10 only - D3D9 uses explicit clipping plane calls.
    // NOTE: The world transform is needed only for this.
    float4 HPw = mul(float4(In.Pos, 1.0f), gWXf);
    ComputeClipDistances(HPw, Out.ClipDistances0, Out.ClipDistances1);

    return Out;
}

// Vertex shader for main technique, used to set up GBuffer data to interpolate.
VS_TO_PS VS_NPR(VS_INPUT In)
{
    return VSBasic(In);
}

// Vertex shader for text technique, used to set up GBuffer data to interpolate.
// The position will be used in pixel shader.
VS_TO_PS_Text VS_NPR_Text(VS_INPUT In)
{
    VS_TO_PS_Text Out;
    Out.BasicVSToPS = VSBasic(In);

    // Output the position to pixel shader.
    Out.VPos = Out.BasicVSToPS.HPos;

    return Out;
}

// Pixel shader for main technique, which puts the various values into the needed GBuffers.
float4 PS_NPR(VS_TO_PS In) : SV_Target
{
    return gMaskColor;
}

// Pixel shader for text technique, which puts the various values into the needed GBuffers.
float4 PS_NPR_Text(VS_TO_PS_Text In) : SV_Target
{
    // Get the sample coordinate for the current pixel.
    float sampleX = (In.VPos.x / In.VPos.w + 1.0) / 2.0;
    float sampleY = (1.0 - In.VPos.y / In.VPos.w) / 2.0;

    // Sample the visibility. We use the reb channel as the visibility.
    float visibility = gVisibilityTex.Sample(gSamp, float2(sampleX, sampleY)).r;
    if(visibility > 0.5f)
        discard;

    return gMaskColor;
}

// The main technique.
technique10 Main
{
    pass p0
    {

       SetVertexShader(CompileShader(vs_4_0,VS_NPR()));
       SetPixelShader(CompileShader(ps_4_0,PS_NPR()));

    }
}

// The Text technique.
technique10 Text
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_4_0,VS_NPR_Text()));
        SetPixelShader(CompileShader(ps_4_0,PS_NPR_Text()));
    }
}