//**************************************************************************/
// Copyright (c) 2019 Autodesk, Inc.
// All rights reserved.
//
// These coded instructions, statements, and computer programs contain
// unpublished proprietary information written by Autodesk, Inc., and are
// protected by Federal copyright law. They may not be disclosed to third
// parties or copied or duplicated in any form, in whole or in part, without
// the prior written consent of Autodesk, Inc.
//**************************************************************************/
// DESCRIPTION: Accessibility Shading and Shadowmap (DX9).
// AUTHOR: Edward Small
// CREATED: March 2019
//**************************************************************************/

//#define LOCAL_VIEWER
#define FLIP_BACKFACING_NORMALS

// World transformation.
float4x4 gWXf : World;

// World transformation, inverse transpose.
float4x4 gWITXf : WorldInverseTranspose;

// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection;

// World-view transformation
float4x4 gWV : WorldView;

#ifdef LOCAL_VIEWER
    float4x4 gVIXf : ViewInverse;
#else
    float3 gViewDirection : ViewDirection;
#endif

// Whether the projection matrix flips Z: -1.0 if so, otherwise 1.0.
float gProjZSense : ProjectionZSense;

// Depth priority, which shifts the model a bit forward in the z-buffer
float gDepthPriority : DepthPriority;

// Opacity factor.
float gOpacity : Opacity;

// Shadow Size
int gAccessibilityShadowSize : AccessibilityShadowSize;

// Shadow Map
float4x4 gAccessibilityShadowTransform : AccessibilityShadowTransform;

// Shadow Texture
Texture2D gAccessibilityShadowTex : AccessibilityShadowTexture;

// Shadow Sample
sampler2D gAccessibilityShadowSampler : AccessibilityShadowSampler = sampler_state
{
  Texture = <gAccessibilityShadowTex>;
};

// A float acting as a bool to flag if the second shadow map is needed
float gAccessibilityIsSecondShadowNeeded : AccessibilityIsSecondShadowNeeded;

// Second Shadow Size
int gAccessibilitySecondShadowSize : AccessibilitySecondShadowSize;

// Second Shadow Map
float4x4 gAccessibilitySecondShadowTransform : AccessibilitySecondShadowTransform;

// Second Shadow Texture
Texture2D gAccessibilitySecondShadowTex : AccessibilitySecondShadowTexture;

// Second Shadow Sample
sampler2D gAccessibilitySecondShadowSampler : AccessibilitySecondShadowSampler = sampler_state
{
  Texture = <gAccessibilitySecondShadowTex>;
};

// Precompute the size of a texel in texel space.
static float gTexelSize = 1.0 / gAccessibilityShadowSize;

static float gOffset = 4.0 * gTexelSize;

static float gSecondTexelSize = (gAccessibilityIsSecondShadowNeeded > 0.5) ? 1.0 / gAccessibilitySecondShadowSize : 1.0;

static float gSecondOffset = 4.0 * gSecondTexelSize;

static float gDepthTolerance = 0.00001;

static float gNormalTolerance = 0.00001;

float CalculateShadow(float2 Pl, sampler2D shadowSampler, float4 texCoords, float4 offsetCoords, float inNDCBox)
{
    // Perform sampling for points inside the NDC box.  Percentage closest filtering is used to
    // smooth the result at shadow-light boundaries.  Points outside are treated as not in shadow.
    // The normalized version of the sample point is used for the rest of this function.
    float result = 1.0;
	
	if(inNDCBox > 0.5){
		// z depth for the pixel related to the vertex in question
		float zDepth = Pl.x; 
		// Sample the texture from computed location and three adjacent texels: down, right, and
		// diagonal.  Each texel's r component is the depth in the shadow map.  Record whether the
		// depth of the current sample point is greater than this depth (in shadow, 0.0) or less
		// (fully lit, 1.0).  The step() instrinsic provides a shorthand for this.
		result = step(zDepth, tex2D(shadowSampler, texCoords.xy).r);
		if (result <= 0.0) {
			result = step(zDepth, tex2D(shadowSampler, texCoords.zy).r);
		}
		if (result <= 0.0) {
			result = step(zDepth, tex2D(shadowSampler, texCoords.xw).r);
		}
		if (result <= 0.0) {
			result = step(zDepth, tex2D(shadowSampler, texCoords.zw).r);
		 }
		 
		// If result is not 1.0 (Green), check the neighbours
		if (result <= 0.0 && Pl.y < gNormalTolerance) {
			result = step(zDepth, tex2D(shadowSampler, offsetCoords.xy).r);	
			if (result <= 0.0) {
				result = step(zDepth, tex2D(shadowSampler, offsetCoords.xw).r);
			}
			//Ideally, we would check all four neighbours, but due to DX9 ps_2_0 number of instructions limitations, check only 2 ones.
			/*if (result <= 0.0) {
				result = step(zDepth, tex2D(shadowSampler, offsetCoords.xy).r);
			}
			if (result <= 0.0) {
				result = step(zDepth, tex2D(shadowSampler, offsetCoords.zw).r);
			}*/
		}
	}
    return result;
}

struct VS_INPUT
{
    float3 Pos : POSITION;
    float3 Normal : NORMAL;
};

struct VS_TO_PS
{
    float4 HPos : POSITION;
    // The z of the sample point and its normal in the two shadow maps' clip space. x,y for the first and z,w for the second
    float4 ShadowPos : TEXCOORD0; 
	//The texcoords at which, we're going to check : x and z of the float4 are x-coordinates and y and w are y-coorinates, so we check the four possible combinations
	float4 PosTexCoords : TEXCOORD1;
	float4 PosSecondTexCoords : TEXCOORD2;
	float4 OffsetCoords : TEXCOORD3;
	float4 OffsetSecondCoords : TEXCOORD4;
	float2 IsInNDCBox : TEXCOORD5;
};

VS_TO_PS accessibilityVS(VS_INPUT In)
{
    VS_TO_PS Out;

    float4 P = float4(In.Pos, 1.0);

    Out.HPos = mul(P, gWVPXf);

    // Transform the position and normal to world space for lighting, and normalize the normal.
    float4 HPw = mul(P, gWXf);
	
    // Output the vertex position in the clip space of the shadow map.
    float4 PosShadow = mul(HPw, gAccessibilityShadowTransform);
	float4 PosSecondShadow = ( gAccessibilityIsSecondShadowNeeded > 0.5f) ? PosSecondShadow = mul(HPw, gAccessibilitySecondShadowTransform) : PosShadow;
	float3 PndcPosShadow = PosShadow.xyz / PosShadow.w;
	Out.ShadowPos.x = PndcPosShadow.z - gDepthTolerance;
	Out.IsInNDCBox.x = (any(PndcPosShadow > -1.0) && any(PndcPosShadow < 1.0)) ? 1.0 : 0.0;
	float3 PndcPosSecondShadow = PosSecondShadow.xyz / PosSecondShadow.w;
	Out.ShadowPos.z = PndcPosSecondShadow.z - gDepthTolerance;
	Out.IsInNDCBox.y = (any(PndcPosSecondShadow > -1.0) && any(PndcPosSecondShadow < 1.0)) ? 1.0 : 0.0;
        // Compute the texture coordinates for shadow map sampling based on the sample point.  Since
        // the point is in the light's space, the x and y components of the point map to the UV
        // texture coordinates.  They must be mapped from the range [-1.0, 1.0] to [0.0, 1.0], and
        // the v component must be flipped, i.e. v == 0.0 is at the top of the texture.  Also, shift
        // the texture coordinates by half a texel to properly emulate bilinear filtering in the code
        // that follows, so that they are relative to a texel center, not corner.
    Out.PosTexCoords.xy = PndcPosShadow.xy * float2(0.5, -0.5) + 0.5 - 0.5 * gTexelSize;
	Out.PosTexCoords.zw = Out.PosTexCoords.xy + float2(gTexelSize, gTexelSize);
	Out.PosSecondTexCoords.xy = PndcPosSecondShadow.xy * float2(0.5, -0.5) + 0.5 - 0.5 * gSecondTexelSize;
	Out.PosSecondTexCoords.zw = Out.PosSecondTexCoords.xy + float2(gTexelSize, gTexelSize);
	
	Out.OffsetCoords.xy = Out.PosTexCoords.xy + float2(gOffset, gOffset);
	Out.OffsetCoords.zw = Out.PosTexCoords.xy + float2(-gOffset, -gOffset);
	Out.OffsetSecondCoords.xy = Out.PosSecondTexCoords.xy + float2(gSecondOffset, gSecondOffset);
	Out.OffsetSecondCoords.zw = Out.PosSecondTexCoords.xy + float2(-gSecondOffset, -gSecondOffset);
	
    // Output the vertex normal in the clip space of the shadow map.
    float4 WorldNormal = mul(float4(In.Normal, 0.0), gWXf);
    Out.ShadowPos.y = normalize(mul(WorldNormal, gAccessibilityShadowTransform).xyz).z;
	Out.ShadowPos.w = ( gAccessibilityIsSecondShadowNeeded > 0.5f) ? normalize(mul(WorldNormal, gAccessibilitySecondShadowTransform).xyz).z : Out.ShadowPos.y;
	Out.ShadowPos.y = Out.ShadowPos.y > 0.0f ? Out.ShadowPos.y : -Out.ShadowPos.y;
	Out.ShadowPos.w = Out.ShadowPos.w > 0.0f ? Out.ShadowPos.w : -Out.ShadowPos.w;
  
    // modify the HPos a bit by biasing the Z a bit forward, based on depth priority
    Out.HPos.z -= Out.HPos.w*gDepthPriority;

    return Out;
}

float4 accessibilityPS(VS_TO_PS In) : SV_Target
{
    if( CalculateShadow(In.ShadowPos.xy, gAccessibilityShadowSampler, In.PosTexCoords, In.OffsetCoords, In.IsInNDCBox.x) > 0.0f) return float4(0.0f, 1.0f, 0.0f, gOpacity);
	else {
		if( gAccessibilityIsSecondShadowNeeded > 0.5f){
			if(CalculateShadow(In.ShadowPos.zw, gAccessibilitySecondShadowSampler, In.PosSecondTexCoords, In.OffsetSecondCoords, In.IsInNDCBox.y) > 0.0f) return float4(0.0f, 1.0f, 0.0f, gOpacity);
		}
	}
	return float4(1.0f, 0.0f, 0.0f, gOpacity);
}

Technique Accessibility
{
    pass P0
    {
        VertexShader = compile vs_2_0 accessibilityVS();
        PixelShader = compile ps_2_0 accessibilityPS();
    }
}

