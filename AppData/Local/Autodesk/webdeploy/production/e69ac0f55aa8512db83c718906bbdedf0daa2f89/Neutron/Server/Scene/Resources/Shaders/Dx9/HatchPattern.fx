// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection < string UIWidget = "None"; >;

// Screen size. Use it to compute half pixel offset in Dx9
float2 gScreenSize : ViewportPixelSize < string UIWidget = "None"; >;
static float2 gHalfTexel = 0.5 / gScreenSize;

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
	float4 HPos : POSITION;
	float4 ScreenPosition : TEXCOORD0;
};

VS_TO_PS HatchPatternVS(VS_INPUT In)
{
	VS_TO_PS Out;

	float4 P = float4(In.Pos, 1.0);
	Out.HPos = mul(P, gWVPXf);

	// modify the HPos a bit by biasing the Z a bit forward, based on depth priority
	Out.HPos.z -= Out.HPos.w*gDepthPriority;

	Out.ScreenPosition = Out.HPos;

	return Out;
}

float4 HatchPatternPS(VS_TO_PS In) : COLOR0
{
	float2 coord = In.ScreenPosition.xy / In.ScreenPosition.w;

	coord = (coord - gHalfTexel + float2(1.0f, 1.0f)) / 2.0f*gScreenSize.xy;

	float hatchPhase;
	float dist;
	float3 hatchColor = gHatchTintColor;

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

	if (dist < 1.0f)
	{
		hatchColor = float3(0.0f,0.0f,0.0f);
	}

	// Final color and alpha.
	float4 final = float4(hatchColor, gOpacity);
	return final;
}

technique HatchPattern
{
	pass P0
	{
		VertexShader = compile vs_2_0 HatchPatternVS();
		PixelShader = compile ps_2_0 HatchPatternPS();
	}
}
