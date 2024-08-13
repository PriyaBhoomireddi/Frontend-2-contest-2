//**************************************************************************/
// Copyright (c) 2014 Autodesk, Inc.
// All rights reserved.
// 
// These coded instructions, statements, and computer programs contain
// unpublished proprietary information written by Autodesk, Inc., and are
// protected by Federal copyright law. They may not be disclosed to third
// parties or copied or duplicated in any form, in whole or in part, without
// the prior written consent of Autodesk, Inc.
//**************************************************************************/
// DESCRIPTION: Apply Canon camera response curve to incoming linear data.
//   Data should be floating point, if you're wise.
// AUTHOR: Eric Haines
// CREATED: March 2014
//**************************************************************************/

#include "Common.fxh"

// The exposure adjustment, essentially just a scale factor to the incoming linear color
float gExposureValue = 0.0f;

// use analytic or texture lookup solution
bool gUseTextureLookup = false;

// run in color preserving mode or not. default is to not run in color preserving mode
bool gColorPreserving = false;

// The source image (beauty pass) texture and sampler.
texture gSceneTexture;
sampler2D gSceneSampler = sampler_state { Texture = <gSceneTexture>; };

// The lookup texture, 1024x1, that holds the Canon camera S-Curve
texture gLookupTexture;
// Filter lookup sampler
sampler2D gLookupSampler = sampler_state { Texture = <gLookupTexture>; };

int TonemapEntries = 1024;
float TonemapMin = -2.152529302052785809f;
float TonemapMax = 1.163792197947214113f;
float Shift = 1.0f / 0.18f;

// Pixel shader.
// incoming is 0 to infinity (linear color space), output is 0.0 to 1.0
float AnalyticCanon( float x )
{
    // 23.921x6 - 70.678x5 + 71.943x4 - 29.707x3 + 5.9189x2 - 0.4027x + 0.0071
    // Magic 6th order polynomial found using Excel's curve fitting feature, by Mauricio Vives
    float x2 = x  * x;
    float x3 = x  * x2;
    float x4 = x2 * x2;
    float x5 = x2 * x3;
    float x6 = x3 * x3;

    // fancy way to multiply values together;
    // I think this is actually a tiny bit slower on modern GPUs, which don't do vector operations but
    // rather do single value ops, so the 1.0 times 0.0071 is not needed.
    static float3 coeff1 = float3( 23.921f, -70.678f,  71.943f);
    static float4 coeff2 = float4(-29.707f,  5.9189f, -0.4027f, 0.0071f);
    return dot(coeff1, float3(x6, x5, x4)) + dot(coeff2, float4(x3, x2, x, 1.0f));
}

float T(float x)
{
    // this function fits the measured Canon sigmoid *without gamma correction*
    float tmp = 1.0592f - 1.0631f / (1.0f + 4.5805f * pow(x, 1.5823f));
    return saturate(tmp);
}


float4 PS_CanonCurve(VS_TO_PS_ScreenQuad In) : COLOR0
{
	float4 inputColor = tex2D(gSceneSampler, In.UV).rgba;
    float3 linColor = inputColor.rgb;

    // "undoing" alpha is possible, but not all that useful - it does not really work properly
    // for pixels with a partial alpha value. The right way is to render the whole image
    // (performing inverse alpha on the LDR backplate, if needed) and tone map it.
    // Short answer: alpha is assumed to be 1.0f, as it should be.
    //
    // Old code left just in case there's some use:
    // For compositing: If alpha is < 1.0, need to "unmultiply" by alpha so we can properly
    // tone map.
    // First, the tone map should be done to the "average" color of the surface being
    // rendered, not the color of this surface over a transparent background.
    // Actually, better is to tone map each sample, if MSAA is used; see
    // ShaderX^6, section 3.2. Not done, TODO: need to experiment with this.
    // Second, tone mapping on a premultiplied color can (and does) give
    // a premultiplied color with colors > alpha, a non-meaningful result.
    //if ( linColor.a < 1.0 )
    //{
    //    // if 0, our work here is done, as all zeros should be returned
    //    if ( linColor.a <= 0.0 )
    //    {
    //      return float4( 0.0f, 0.0f, 0.0f, 0.0f );
    //    }
    //    linColor.rgb /= linColor.a;
    //}
    // See DX10 version of shader to see use of alpha (also commented out there).

    if (gColorPreserving) {
      float3 outColor = linColor.rgb;
      // apply exposure scaling
      outColor = outColor * exp2(gExposureValue);

      // clamp the input to simulate finite sensor
      outColor = min(outColor, float3(3.0f, 3.0f, 3.0f));

      // apply the curve to the luminance
      float inLum = dot(float3(0.2126f, 0.7152f, 0.0722f), outColor);
      float outLum = T(inLum);

      // scale the color, preserving channel ratios
      outColor = outColor * (outLum / inLum);

      // clamp again
      outColor = saturate(outColor);

      // and apply gamma 2.2
      float gamma = 1.0f/2.2f;
      outColor = pow(outColor, float3(gamma, gamma, gamma));

      // turn color back into a premultiplied version, so we can composite normally.
      return float4( outColor.r, outColor.g, outColor.b, inputColor.a );
    } else {
      // Shift curve and exposure is base 2.
      float Scale = Shift * exp2(gExposureValue);
      // if input value is 0, clamp output to be 0
      float3 indexColor;
      // don't take the log of 0 or a negative number
      indexColor = log10(max(Scale*linColor.rgb,0.000000001f));
      indexColor = saturate((indexColor.rgb - TonemapMin) / (TonemapMax - TonemapMin));

      if ( gUseTextureLookup )
      {
        // texture lookup;
        // To have 1024 equal-size buckets, need to multiply by 1023/1024 and 
        // offset by 0.5/TonemapEntries to get to center of pixel. For example, if
        // TonemapEntries was 2, we'd want samples at 0.25 and 0.75, which is what
        // this formula gives.
        // This is for a perfect match; in reality it could probably not be done for
        // large textures and no one would know.
        indexColor = (indexColor * (float(TonemapEntries - 1)/float(TonemapEntries))) + 0.5/TonemapEntries;
        // The lookup texture is made of the values from
        // //depot/Raas/current/rsut/include/rsut/camera_response_tonemap_data.hpp,
        // divided by 0-255 to be in the range 0.0 to 1.0.
        float3 lookupColor;
        lookupColor.r = tex2D(gLookupSampler, float2( indexColor.r, 0.5f)).r;
        lookupColor.g = tex2D(gLookupSampler, float2( indexColor.g, 0.5f)).r;
        lookupColor.b = tex2D(gLookupSampler, float2( indexColor.b, 0.5f)).r;
        // turn color back into a premultiplied version, so we can composite normally.
        return float4( lookupColor.r, lookupColor.g, lookupColor.b, inputColor.a);
      }
      else
      {
        // analytic: indexColor is a value from 0.0 to 1.0
        // turn color back into a premultiplied version, so we can composite normally.
        return float4( AnalyticCanon(indexColor.r), AnalyticCanon(indexColor.g), AnalyticCanon(indexColor.b), inputColor.a);
      }
    }
}


// Technique.
technique Main
{
    pass p0
    {
        VertexShader = compile vs_3_0 VS_ScreenQuad();
        PixelShader = compile ps_3_0 PS_CanonCurve();
    }
}

