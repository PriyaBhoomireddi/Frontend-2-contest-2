//**************************************************************************/
// Copyright 2009 Autodesk, Inc.
// All rights reserved.
// 
// These coded instructions, statements, and computer programs contain
// unpublished proprietary information written by Autodesk, Inc., and are
// protected by Federal copyright law. They may not be disclosed to third
// parties or copied or duplicated in any form, in whole or in part, without
// the prior written consent of Autodesk, Inc.
//**************************************************************************/
// DESCRIPTION: DepthIdBuffers
//   This effect creates up to 3 output targets (assuming each is assigned).
//   * Object ID, where the ID is expressed as float4 of fractions.
//   * NDC z-depth per pixel, the z-depth between 0.0 and 1.0 for each pixel,
//     linearly interpolated (i.e. hyperbolic for perspective)
//   * Code commented out for W-buffer linear interpolation. While potentially
//     useful for other purposes, for NPR this code gives non-linear interpolation
//     of depth in perspective space, which makes the Decaudin slope detection for
//     depth differences fail, as the slope changes per pixel.
// AUTHOR: Nikolai Sander
// CREATED: March 2008
// MODIFIED: Charlotta Wadman, February 2010
//**************************************************************************/

// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection;
float4x4 gWVIT: WorldViewInverseTranspose;


// For per-object clipping, unfortunately needed on by default;
// the problem is that for an override material, per-object clipping will not
// affect this material and get it to recompile.
// TODO: is there some way to get this variable set *per object* for it's material?
// ApplySystemShaderMacros in the script interpreter does so globally, but can't
// per object. Mauricio thinks we might need a callback in the script interpreter.
//#ifdef CLIPPING
#include "Clipping10.fxh" // D3D10 ONLY
// World transformation, needed only for clipping
float4x4 gWXf : World < string UIWidget = "None"; >;
//#endif


// Use this to calculate truly linear depth 
// Standard matrix
//float4x4 gWVXf : WorldView;
// Standard camera propertiy
//float gFarClipPlane;

// Depth priority, which shifts the model a bit forward in the z-buffer
float gDepthPriority : DepthPriority
<
    string UIName =  "Depth Priority";
    string UIWidget = "Slider";
    float UIMin = -16/1048576.0f;    // divide by 2^24/16 by default
    float UIMax = 16/1048576.0f;
    float UIStep = 1/1048576.0f;
> = 0.0f;

float4 gObjectID;

float3 gHaloColor;

// The visibility texture.
Texture2D gVisibilityTex : Texture = NULL;

// Visibility texture sampler.
SamplerState gSamp : TextureSampler;

struct VS_INPUT
{
    float3 Pos : POSITION;
};

// Vertex shader output structure.
struct VS_TO_PS
{
    float4 HPos : SV_Position;
    
//#ifdef CLIPPING
    // D3D10 ONLY
    // Clip distances, for eight clipping planes.
    float4 ClipDistances0 : SV_ClipDistance0;
    float4 ClipDistances1 : SV_ClipDistance1;
//#endif
};

// Vertex shader output structure for text technique.
struct VS_TO_PS_Text
{
    VS_TO_PS BasicVSToPS;
    float4 VPos : TEXCOORD0;
};

struct DepthPixelShaderOutput
{
    float4 ObjectID : SV_Target0;
    float4 PDepthVal : SV_Target1;
    //float4 VDepthVal : SV_Target2;
};

// Basic vertex shader function.
// Outputs:
//   HPos is the position in clip space (NDC with undivided W).
//   Depth holds one value: x holds the z-depth value from the eye, i.e. with respect to the view matrix
//     but not normalized by the projection matrix.
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

    // To get truly linear depth distribution, save the z value before projection calculations.
    // Then let the projection figure out where on the screen that depth is valid. 
    // The hyperbolic interpolation used for vertexes makes sure it is perpective corrected.
    // This depth is not wanted when gradients are used for edge detection.
    // Out.Depth.z = (mul(In.Pos, gWVXf)).z;
    return Out;
}

// Vertex shader for main technique, used to set up GBuffer data to interpolate.
VS_TO_PS VS_DIG(VS_INPUT In)
{
    return VSBasic(In);
}

// Vertex shader for text technique, used to set up GBuffer data to interpolate.
// The position will be used in pixel shader.
VS_TO_PS_Text VS_DIG_Text(VS_INPUT In)
{
    VS_TO_PS_Text Out;
    Out.BasicVSToPS = VSBasic(In);

    // Output the position to pixel shader.
    Out.VPos = Out.BasicVSToPS.HPos;

    return Out;
}

// Basic pixel shader function.
DepthPixelShaderOutput PSBasic(VS_TO_PS In)
{
    DepthPixelShaderOutput Output;

    // Save away object ID, using gObjectID converted to 0-1 floats, with R
    // being the lowest 8 bits of the integer, G being the next highest, B, then A.
    Output.ObjectID = gObjectID;

    // save depth with linear depth distribution.
    // Divide it by far clip plane to get it in the [0,1] range.
    // Perspective correction is already taken care of vertex interpolator
    // If you use the Far clip plane to scale, this value will differ as far clip plane differs
    // An alternative is to use a global scale value, or to multiply the value with far clip plane again before using it.
    // Output.VDepthVal.r = In.Depth.z/gFarClipPlane;
    // Output.VDepthVal.gba = 0.0f;

    // Unlike with DX9, here we can have access to the depth value of the pixel, HPos.z,
    // which is the same value (if it passes the depth test) written to the depth buffer.
    Output.PDepthVal.r = 0.0f;
    Output.PDepthVal.g = gHaloColor.r;
	Output.PDepthVal.b = gHaloColor.g;
	Output.PDepthVal.a = gHaloColor.b;

    return Output;
}

// Pixel shader for main technique, which puts the various values into the needed GBuffers.
DepthPixelShaderOutput PS_DIG(VS_TO_PS In)
{
    return PSBasic(In);
}

// Pixel shader for text technique, which puts the various values into the needed GBuffers.
DepthPixelShaderOutput PS_DIG_Text(VS_TO_PS_Text In)
{
    // Get the sample coordinate for the current pixel.
    float sampleX = (In.VPos.x / In.VPos.w + 1.0) / 2.0;
    float sampleY = (1.0 - In.VPos.y / In.VPos.w) / 2.0;

    // Sample the visibility. We use the reb channel as the visibility.
    float visibility = gVisibilityTex.Sample(gSamp, float2(sampleX, sampleY)).r;
    if(visibility > 0.5f)
        discard;

    return PSBasic(In.BasicVSToPS);
}

// The main technique.
technique10 Main
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_4_0,VS_DIG()));
        SetPixelShader(CompileShader(ps_4_0,PS_DIG()));
    }
}

// The Text technique.
technique10 Text
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_4_0,VS_DIG_Text()));
        SetPixelShader(CompileShader(ps_4_0,PS_DIG_Text()));
    }
}
