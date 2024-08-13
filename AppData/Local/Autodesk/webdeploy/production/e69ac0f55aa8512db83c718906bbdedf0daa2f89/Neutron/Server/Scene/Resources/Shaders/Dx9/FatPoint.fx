// Screen size in pixels, specified for the enabled features that need it.
// NOTE: Needs to be specified before one or more of the include files below.
float2 gScreenSize : ViewportPixelSize < string UIWidget = "None"; > ;

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

// Color.
float3 gColor : Color
<
    string UIName = "Color";
    string UIWidget = "Color";
> = float3(1.0f, 1.0f, 1.0f);

// Opacity factor.
float gOpacity : Opacity
<
    string UIName = "Opacity";
    string UIWidget = "Slider";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
    float UIStep = 0.1f;
> = 1.0f;

// The texture.
texture gTex : Texture
<
    string UIName = "Texture";
> = NULL;

// Texture sampler.
sampler2D gSamp : TextureSampler = sampler_state
{
    Texture = <gTex>;
};

// Point Size.
float2 gNeutronPointSize : NeutronPointSize
<
    string UIName = "Neutron Point Size";
> = float2(1.0f, 1.0f);

// Vertex shader input structure.
struct VS_INPUT
{
    float3 Pos : POSITION;
    float2 UV : TEXCOORD0;
    float  ExtrudeCode : TEXCOORD1;
};

// Pixel shader input structure.
struct VS_TO_PS
{
    float4 HPos : POSITION;
    float2 UV : TEXCOORD0;
};

// Vertex shader.
VS_TO_PS VS_FatPoint(VS_INPUT In)
{
    VS_TO_PS Out;

    // Transform the position from object space to clip space for output.
    Out.HPos = mul(float4(In.Pos, 1.0f), gWVPXf);
    Out.UV = In.UV;
    
    // Half of width and height of the fat point in NDC space.
    float2 hsizeNDC = gNeutronPointSize / gScreenSize;

    // Extrude the 4 vertices.
    if (In.ExtrudeCode == 0.0)
    {
        Out.HPos.x -= Out.HPos.w*hsizeNDC.x;
        Out.HPos.y += Out.HPos.w*hsizeNDC.y;
    }
    else if (In.ExtrudeCode == 1.0)
    {
        Out.HPos.x -= Out.HPos.w*hsizeNDC.x;
        Out.HPos.y -= Out.HPos.w*hsizeNDC.y;
    }
    else if (In.ExtrudeCode == 2.0)
    {
        Out.HPos.x += Out.HPos.w*hsizeNDC.x;
        Out.HPos.y -= Out.HPos.w*hsizeNDC.y;
    }
    else if (In.ExtrudeCode == 3.0)
    {
        Out.HPos.x += Out.HPos.w*hsizeNDC.x;
        Out.HPos.y += Out.HPos.w*hsizeNDC.y;
    }

    // modify the HPos a bit by biasing the Z a bit forward, based on depth priority
    Out.HPos.z -= Out.HPos.w*gDepthPriority;

    return Out;
}

// Pixel shader.
float4 PS_FatPoint(VS_TO_PS In) : COLOR0
{
    // Get the solid color.
    float3 pColor = gColor;
    float pOpacity = gOpacity;

    // Get the texture color.
    float4 clrTex = tex2D(gSamp, In.UV);

    // The output color is the input color modulated by the texture color.
    float3 outputColor = clrTex.rgb * pColor;
    float outputAlpha = pOpacity * clrTex.a;

    float4 finalColor = float4(outputColor, outputAlpha);
    return finalColor;
}

// The main technique.
technique FatPoint
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_FatPoint();
        PixelShader = compile ps_3_0 PS_FatPoint();
    }
}
