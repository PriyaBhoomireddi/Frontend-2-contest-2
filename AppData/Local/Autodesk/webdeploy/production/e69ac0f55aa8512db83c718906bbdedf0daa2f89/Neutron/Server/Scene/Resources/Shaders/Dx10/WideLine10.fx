#include "Clipping10.fxh"

// World transformation.
float4x4 gWXf : World < string UIWidget = "None"; >;

// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection < string UIWidget = "None"; >;

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

// Point color.
float4 gNeutronLineColor : NeutronLineColor
<
    string UIName =  "Neutron Line Color";
> = float4(0.0f, 0.0f, 0.0f, 1.0f);

// Vertex shader input structure.
struct VSPos
{
	float3 Pos			: Position;
};

// Pixel shader input structure.
struct VSOutput
{
    float4 HPos : SV_Position;

    // D3D10 ONLY
    // Clip distances, for eight clipping planes.
    float4 ClipDistances0 : SV_ClipDistance0;
    float4 ClipDistances1 : SV_ClipDistance1;
};

VSOutput VS_Pos( VSPos Input,uniform float2 offset)
{
	VSOutput Out = (VSOutput) 0;
	float4 LocalPos = float4(Input.Pos,1.0f);
	Out.HPos = mul(LocalPos, gWVPXf);

	if(Out.HPos.w > 0.0f)
	{
		//In orthographics mode, Out.Pos.w is always 1.0f, so this is not a problem.
		//But in perspective mode, if Out.Pos.w <= 0, that means we are out of the view frustum
		//and we can't do the following computation otherwise there will be some problem. see DID 1288930
		Out.HPos.xyz /= Out.HPos.w;
		Out.HPos.w = 1.0f;
		Out.HPos.xy += offset.xy;
	}

	// Compute the eight clip distances. D3D10 only - D3D9 uses explicit clipping plane calls.
    // NOTE: The world transform is needed only for this.
    float4 HPw = mul(float4(Input.Pos, 1.0f), gWXf);
    ComputeClipDistances(HPw, Out.ClipDistances0, Out.ClipDistances1);
    
    // modify the HPos a bit by biasing the Z a bit forward, based on depth priority
    Out.HPos.z -= Out.HPos.w*gDepthPriority;

	return Out;
}

float4 PS_Pos( VSOutput Input ) : SV_Target
{
	return gNeutronLineColor;
}



// wide line:2 pixels' width
//Actually 4 passes are needed: offset table is like this:(0,0),(0,1),(1,0),(1,1)
technique10 WideLine2pixels
{
    pass P0
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P1
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,-2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P2
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2.0f/gScreenSize.x,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P3
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2.0f/gScreenSize.x, -2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
}

// wide line:3 pixels' width
//Actually 5 passes are needed: offset table is like this:(0,-1),(-1,0),(0,0),(1,0),(0,1)
technique10 WideLine3pixels
{
    pass P0
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P1
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(-2.0f/gScreenSize.x,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P2
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P3
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2.0f/gScreenSize.x,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P4
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,-2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
}


// wide line:4 or more pixels' width
//Actually 12 passes are needed: offset table is like this:(0,-1),(1,-1),(-1,0),(0,0),(1,0),(2,0),(-1,1),(0,1),(1,1),(2,1),(0,2),(1,2)
technique10 WideLine4pixels
{
    pass P0
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P1
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2.0f/gScreenSize.x,2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P2
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(-2.0f/gScreenSize.x,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P3
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P4
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2.0f/gScreenSize.x,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P5
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2*2.0f/gScreenSize.x,0.0f))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P6
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(-2.0f/gScreenSize.x,-2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P7
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,-2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P8
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2.0f/gScreenSize.x,-2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P9
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2*2.0f/gScreenSize.x,-2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P10
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(0.0f,-2*2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
    pass P11
    {   
	SetVertexShader( CompileShader( vs_4_0, VS_Pos(float2(2.0f/gScreenSize.x,-2*2.0f/gScreenSize.y))));
	SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0,PS_Pos()));
    }
   
}