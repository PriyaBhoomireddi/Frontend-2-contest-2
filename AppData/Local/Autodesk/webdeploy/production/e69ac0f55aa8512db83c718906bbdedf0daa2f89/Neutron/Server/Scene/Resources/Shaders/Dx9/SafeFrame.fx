//**************************************************************************/
// Copyright (c) 2015 Autodesk, Inc.
// All rights reserved.
// 
// These coded instructions, statements, and computer programs contain
// unpublished proprietary information written by Autodesk, Inc., and are
// protected by Federal copyright law. They may not be disclosed to third
// parties or copied or duplicated in any form, in whole or in part, without
// the prior written consent of Autodesk, Inc.
//**************************************************************************/
// DESCRIPTION: This is intended as a post process pass that adds semi transparent grey curtains to the edges of the input texture.
// AUTHOR: Pekka Akerstrom
// CREATED: August 2015
//**************************************************************************/

#include "Common.fxh"

// The amount of uv space that will be grey on each edge. [0,0.5f].
float gUCurtain = 0.0f;
float gVCurtain = 0.0f;
// The amount of greyout.
float gIntensity = 1.0f;

// The single filter input, i.e. the image to be filtered.
texture gInput;

// Filter input sampler.
sampler2D gInputSampler = sampler_state
{
    Texture = <gInput>;
};

// Pixel shader.
float4 PS_SAFEFRAME(VS_TO_PS_ScreenQuad In) : COLOR0
{
    float4 texCol = tex2D(gInputSampler, In.UV.xy);

    float intensity = 1.0f;

    if ( In.UV.x < gUCurtain || (1.0-In.UV.x) < gUCurtain )
        intensity = gIntensity;

    if ( In.UV.y < gVCurtain || (1.0-In.UV.y) < gVCurtain )
        intensity = gIntensity;

    return float4(intensity*texCol.rgb,texCol.a);
}

// The main technique.
technique Main
{
    pass p0
    {

        VertexShader = compile vs_3_0 VS_ScreenQuad();
        PixelShader = compile ps_3_0 PS_SAFEFRAME();

    }
}
