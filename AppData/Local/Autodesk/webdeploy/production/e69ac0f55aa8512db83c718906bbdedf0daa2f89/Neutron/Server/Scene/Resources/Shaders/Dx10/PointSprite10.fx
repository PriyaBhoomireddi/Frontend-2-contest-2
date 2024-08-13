#include "Clipping10.fxh"

// World transformation.
float4x4 gWXf : World < string UIWidget = "None"; >;

// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection < string UIWidget = "None"; >;

// Point Size
float  gNeutronPointSize : NeutronPointSize
<
    string UIName = "Neutron Point Size";
> = 4.0f;                   

// Point color.
float4 gNeutronPointColor : NeutronPointColor
<
    string UIName =  "Neutron Point Color";
> = float4(0.0f, 0.0f, 0.0f, 1.0f);

// Depth priority, which shifts the model a bit forward in the z-buffer
float gDepthPriority : DepthPriority
<
    string UIName =  "Depth Priority";
    string UIWidget = "Slider";
    float UIMin = -16/1048576.0f;    // divide by 2^24/16 by default
    float UIMax = 16/1048576.0f;
    float UIStep = 1/1048576.0f;
> = 0.0f;

// ScreenSize
float2 gScreenSize : ViewportPixelSize < string UIWidget = "None"; >;

// Vertex shader input structure.
struct VS_INPUT
{
    float3 Pos : POSITION;
};

// Pixel shader input structure.
struct VS_TO_PS
{
    float4 HPos : SV_Position;

    // D3D10 ONLY
    // Clip distances, for eight clipping planes.
    float4 ClipDistances0 : SV_ClipDistance0;
    float4 ClipDistances1 : SV_ClipDistance1;
};

// Geometry shader output structure.
struct GS_OUTPUT
{
    float4 HPos : SV_Position;

    // D3D10 ONLY
    // Clip distances, for eight clipping planes.
    float4 ClipDistances0 : SV_ClipDistance0;
    float4 ClipDistances1 : SV_ClipDistance1;
};

// Vertex shader.
VS_TO_PS VS_PointSprite_Shader(VS_INPUT In)
{
    VS_TO_PS Out;
    // Transform the position from object space to clip space for output.
    Out.HPos = mul(float4(In.Pos, 1.0f), gWVPXf);
    
    // Compute the eight clip distances. D3D10 only - D3D9 uses explicit clipping plane calls.
    // NOTE: The world transform is needed only for this.
    float4 HPw = mul(float4(In.Pos, 1.0f), gWXf);
    ComputeClipDistances(HPw, Out.ClipDistances0, Out.ClipDistances1);
    
    // modify the HPos a bit by biasing the Z a bit forward, based on depth priority
    Out.HPos.z -= Out.HPos.w*gDepthPriority;

    return Out;
}

// Geometry Shader
[maxvertexcount(48)]
void GS_PointSprite_Shader( point VS_TO_PS input[1], inout TriangleStream<GS_OUTPUT> TriStream )
{
    GS_OUTPUT output;
   
    //
    // Output the Trianges
    //
	float2 posOffset = gNeutronPointSize / gScreenSize;
	
	float2 radius = posOffset;
	float twoPi = 2.0 * 3.141592654f;
	int sampleCount = 16;
	
	for (int step = 0; step < sampleCount; step++)
	{
		// vertex 0
		output.HPos = input[0].HPos;
		output.ClipDistances0 = input[0].ClipDistances0;
		output.ClipDistances1 = input[0].ClipDistances0;
		TriStream.Append( output );
		
		// vertex 1
		float s, c;
		sincos( twoPi/sampleCount * step, s, c );
		posOffset = radius * float2(c, s);
		output.HPos = input[0].HPos;
		output.HPos.xy += posOffset;
		output.ClipDistances0 = input[0].ClipDistances0;
		output.ClipDistances1 = input[0].ClipDistances0;
		TriStream.Append( output );
		
		// vertex 2
		sincos( twoPi/sampleCount * (step+1), s, c);
		posOffset = radius * float2(c, s);
		output.HPos = input[0].HPos;
		output.HPos.xy += posOffset;
		output.ClipDistances0 = input[0].ClipDistances0;
		output.ClipDistances1 = input[0].ClipDistances0;
		TriStream.Append( output );
	
		TriStream.RestartStrip();
	}
}


// Pixel shader for point sprite.
float4 PS_PointSprite_Shader(GS_OUTPUT In) : SV_Target
{
    return gNeutronPointColor;
}

// The point sprite technique.
technique10 PointSprite
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_4_0, VS_PointSprite_Shader()));
        SetGeometryShader( CompileShader( gs_4_0, GS_PointSprite_Shader() ) );
        SetPixelShader(CompileShader(ps_4_0, PS_PointSprite_Shader()));
    }
}