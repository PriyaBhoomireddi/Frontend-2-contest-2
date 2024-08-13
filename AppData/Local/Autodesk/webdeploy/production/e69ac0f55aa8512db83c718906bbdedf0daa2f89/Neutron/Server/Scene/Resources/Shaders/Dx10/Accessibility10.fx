#include "Clipping10.fxh"

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
SamplerState gAccessibilityShadowSampler : AccessibilityShadowSampler;

// A float acting as a bool to flag if the second shadow map is needed
float gAccessibilityIsSecondShadowNeeded : AccessibilityIsSecondShadowNeeded;

// Second Shadow Size
int gAccessibilitySecondShadowSize : AccessibilitySecondShadowSize;

// Second Shadow Map
float4x4 gAccessibilitySecondShadowTransform : AccessibilitySecondShadowTransform;

// Second Shadow Texture
Texture2D gAccessibilitySecondShadowTex : AccessibilitySecondShadowTexture;

// Second Shadow Sample
SamplerState gAccessibilitySecondShadowSampler : AccessibilitySecondShadowSampler;

// Precompute the size of a texel in texel space.
static float gTexelSize = 1.0 / gAccessibilityShadowSize;

static float gSecondTexelSize = (gAccessibilityIsSecondShadowNeeded > 0.5) ? 1.0 / gAccessibilitySecondShadowSize : gTexelSize;

static float gDepthTolerance = 0.00001;

static float gNormalTolerance = 0.00001;

float CalculateShadow(float4 Pl, float3 Normal, float texelSize, Texture2D shadowTex, SamplerState shadowSampler)
{
    // Perform sampling for points inside the NDC box.  Percentage closest filtering is used to
    // smooth the result at shadow-light boundaries.  Points outside are treated as not in shadow.
    // The normalized version of the sample point is used for the rest of this function.
    float result = 1.0;
    float3 Pndc = Pl.xyz / Pl.w;
    if (all(Pndc > -1.0) && all(Pndc < 1.0)) {

        // z depth for the pixel in question
        float zDepth = Pndc.z - gDepthTolerance;

        // Compute the texture coordinates for shadow map sampling based on the sample point.  Since
        // the point is in the light's space, the x and y components of the point map to the UV
        // texture coordinates.  They must be mapped from the range [-1.0, 1.0] to [0.0, 1.0], and
        // the v component must be flipped, i.e. v == 0.0 is at the top of the texture.  Also, shift
        // the texture coordinates by half a texel to properly emulate bilinear filtering in the code
        // that follows, so that they are relative to a texel center, not corner.
        float2 texCoords = Pndc.xy * float2(0.5, -0.5) + 0.5 - 0.5 * texelSize;

        // Sample the texture from computed location and three adjacent texels: down, right, and
        // diagonal.  Each texel's r component is the depth in the shadow map.  Record whether the
        // depth of the current sample point is greater than this depth (in shadow, 0.0) or less
        // (fully lit, 1.0).  The step() instrinsic provides a shorthand for this.
        result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords, 0).r);
        if (result <= 0.0) {
            result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords + float2(texelSize, 0.0), 0).r);
        }
        if (result <= 0.0) {
            result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords + float2(0.0, texelSize), 0).r);
        }
        if (result <= 0.0) {
            result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords + float2(texelSize, texelSize), 0).r);
        }

        // If result is not 1.0 (Green), check the neighbours
        if (result <= 0.0 && Normal.z > -gNormalTolerance && Normal.z < gNormalTolerance) {
            float offset = 4 * texelSize;
            result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords + float2(offset, offset), 0).r);
            if (result <= 0.0) {
                result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords + float2(offset, -offset), 0).r);
            }
            if (result <= 0.0) {
                result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords + float2(-offset, -offset), 0).r);
            }
            if (result <= 0.0) {
                result = step(zDepth, shadowTex.SampleLevel(shadowSampler, texCoords + float2(-offset, offset), 0).r);
            }
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
    float4 HPos : SV_Position;
    // The position of the sample point in the shadow map's clip space.
    float4 PosShadow : TEXCOORD0;
    float3 NormalShadow : TEXCOORD1;
	//The position and normal for the second shadow map
	float4 PosSecondShadow : TEXCOORD2;
	float3 NormalSecondShadow : TEXCOORD3;
    // D3D10 ONLY
    // Clip distances, for eight clipping planes.
    float4 ClipDistances0 : SV_ClipDistance0;
    float4 ClipDistances1 : SV_ClipDistance1;
};

VS_TO_PS accessibilityVS(VS_INPUT In)
{
    VS_TO_PS Out;

    float4 P = float4(In.Pos, 1.0);

    Out.HPos = mul(P, gWVPXf);

    // Transform the position and normal to world space for lighting, and normalize the normal.
    float4 HPw = mul(P, gWXf);

    // Output the vertex position in the clip space of the shadow map.
    Out.PosShadow = mul(HPw, gAccessibilityShadowTransform);
	Out.PosSecondShadow = Out.PosShadow;
	if( gAccessibilityIsSecondShadowNeeded > 0.5f) Out.PosSecondShadow = mul(HPw, gAccessibilitySecondShadowTransform);

    // Output the vertex normal in the clip space of the shadow map.
    float4 WorldNormal = mul(float4(In.Normal, 0.0), gWXf);
	Out.NormalShadow = normalize(mul(WorldNormal, gAccessibilityShadowTransform).xyz);
	Out.NormalSecondShadow = Out.NormalShadow;
	if( gAccessibilityIsSecondShadowNeeded > 0.5f) Out.NormalSecondShadow = normalize(mul(WorldNormal, gAccessibilitySecondShadowTransform).xyz);
    
    // modify the HPos a bit by biasing the Z a bit forward, based on depth priority
    Out.HPos.z -= Out.HPos.w*gDepthPriority;

    // D3D10 ONLY
    // Compute the eight clip distances.
    // NOTE: The world transform is only needed for this.
    ComputeClipDistances(HPw, Out.ClipDistances0, Out.ClipDistances1);

    return Out;
}

float4 accessibilityPS(VS_TO_PS In) : SV_Target
{
    if( CalculateShadow(In.PosShadow, In.NormalShadow, gTexelSize, gAccessibilityShadowTex, gAccessibilityShadowSampler) > 0.0f) return float4(0.0f, 1.0f, 0.0f, gOpacity);
	else {
		if( gAccessibilityIsSecondShadowNeeded > 0.5f){
			if( CalculateShadow(In.PosSecondShadow, In.NormalSecondShadow, gSecondTexelSize, gAccessibilitySecondShadowTex, gAccessibilitySecondShadowSampler) > 0.0f) return float4(0.0f, 1.0f, 0.0f, gOpacity);
		}
	}
	return float4(1.0f, 0.0f, 0.0f, gOpacity);
}

technique10 Accessibility
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_4_0, accessibilityVS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_4_0, accessibilityPS()));
    }
}
