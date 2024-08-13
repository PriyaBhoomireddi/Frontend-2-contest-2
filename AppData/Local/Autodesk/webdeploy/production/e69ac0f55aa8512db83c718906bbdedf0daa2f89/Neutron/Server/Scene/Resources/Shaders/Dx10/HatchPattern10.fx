#include "Clipping10.fxh"

// World transformation.
float4x4 gWXf : World < string UIWidget = "None"; >;

// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection < string UIWidget = "None"; >;

// Whether the projection matrix flips Z: -1.0 if so, otherwise 1.0.
float gProjZSense : ProjectionZSense < string UIWidget = "None"; >;

float gHatchSlope : HatchSlope
<
	string UIName = "Hatch Slope";
	string UIWidget = "Slider";
> = 1.0f;

float  gHatchPeriod : HatchPeriod
<
	string UIName = "Hatch Period";
	string UIWidget = "Slider";
> = 10.0f;

// The first color of the stripe
float3 gHatchTintColor : HatchTintColor
<
	string UIName = "Hatch Tint Color";
> = float3(0.0, 0.5, 0.5);

float  gHatchTintIntensity : HatchTintIntensity
<
	string UIName = "Hatch Tint Intensity";
	string UIWidget = "Slider";
> = 1.0f;

// Opacity factor.
float gOpacity : Opacity
<
	string UIName = "Opacity";
	string UIWidget = "Slider";
	float UIMin = 0.0f;
	float UIMax = 1.0f;
	float UIStep = 0.1f;
> = 1.0f;

// Depth priority, which shifts the model a bit forward in the z-buffer
float gDepthPriority : DepthPriority
<
	string UIName = "Depth Priority";
	string UIWidget = "Slider";
	float UIMin = -16 / 1048576.0f;    // divide by 2^24/16 by default
	float UIMax = 16 / 1048576.0f;
	float UIStep = 1 / 1048576.0f;
> = 0.0f;

struct VS_INPUT
{
	float3 Pos  : POSITION;
	float3 Normal  : NORMAL;
};

struct VS_TO_PS
{
	float4 HPos       : SV_Position;

	// D3D10 ONLY
	// Clip distances, for eight clipping planes.
	float4 ClipDistances0 : SV_ClipDistance0;
	float4 ClipDistances1 : SV_ClipDistance1;
};

VS_TO_PS HatchPatternVS(VS_INPUT In)
{
	VS_TO_PS Out;

	float4 P = float4(In.Pos, 1.0);
	Out.HPos = mul(P, gWVPXf);

	// Transform the position and normal to world space for lighting, and normalize the normal.
	float4 HPw = mul(P, gWXf);

	// modify the HPos a bit by biasing the Z a bit forward, based on depth priority
	Out.HPos.z -= Out.HPos.w*gDepthPriority;

	// D3D10 ONLY
	// Compute the eight clip distances.
	// NOTE: The world transform is only needed for this.
	ComputeClipDistances(HPw, Out.ClipDistances0, Out.ClipDistances1);

	return Out;
}

float4 HatchPatternPS(VS_TO_PS In) : SV_Target
{
	float2 coord = In.HPos.xy;

	float hatchPhase;
	float dist;
	float3 hatchColor;

	float hatchSlope = gHatchSlope;
	if (abs(hatchSlope) <= 1.0f)
	{
		hatchPhase = coord.y - hatchSlope * coord.x;
		dist = fmod(hatchPhase, gHatchPeriod);
		if (dist < 0.0f)
		{
			dist = gHatchPeriod + dist;
		}
	}
	else if (abs(hatchSlope) <= 2.0)
	{
		if (hatchSlope > 0.0f)
		{
			hatchSlope = 2.0 - hatchSlope;
		}
		else
		{
			hatchSlope = -2.0 - hatchSlope;
		}

		hatchPhase = coord.x - hatchSlope * coord.y;
		dist = fmod(hatchPhase, gHatchPeriod);
		if (dist < 0.0f)
		{
			dist = gHatchPeriod + dist;
		}
	}
	else
	{
		dist = fmod(coord.x, gHatchPeriod);
	}

	if (dist < 0.99f)
	{
		hatchColor = float3(0.0f,0.0f,0.0f);
	}
	else
	{
		hatchColor.xyz = gHatchTintColor;
	}

	// Final color and alpha.
	float4 final = float4(hatchColor, gOpacity);
	return final;
}

technique10 HatchPattern
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, HatchPatternVS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_4_0, HatchPatternPS()));
	}
}
