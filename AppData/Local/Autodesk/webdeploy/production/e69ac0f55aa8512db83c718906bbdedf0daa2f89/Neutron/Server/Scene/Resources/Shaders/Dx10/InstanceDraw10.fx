//#define LOCAL_VIEWER
#define FLIP_BACKFACING_NORMALS

// Light structure.
struct Light
{
    // The light color.
    float3 Color;
    
    // The light ambient color.
    float3 AmbColor;
    
    // The light specular color.
    float3 SpecColor;

    // The light direction, in world space.
    // NOTE: Used by directional and spot lights.  This is the direction *toward* the light.
    float3 Dir;

    // The light position, in world space.
    // NOTE: Used by point and spot lights.
    float3 Pos;
    
    // The light range and attenuation factors.
    // NOTE: Used by point and spot lights.
    float4 Atten;
   
    // The cosine of the light hotspot and falloff half-angles.
    // NOTE: Used by spot lights.
    float2 Cone;
};

void ComputeLightingCoefficients(
    float3 Lw, float3 Nw, float3 Vw, float exp, out float diff, out float spec)
{
    // Compute the intermediate results for lighting.
    // > NdotL: The dot product of the world space normal and world space light direction.
    // > Hw   : The halfway vector between the light direction and the view direction, computed as
    //          the normalized sum of the vectors.
    // > NdotH: The dot product of the world space normal and world space halfway vector.
    float NdotL = dot(Nw, Lw);
    float3 Hw = normalize(Vw + Lw);
    float NdotH = dot(Nw, Hw);

    // Use the lit() intrinsic function to compute the diffuse and specular coefficients.
    float4 lighting = lit(NdotL, NdotH, exp);
    diff = lighting.y;
    spec = lighting.z;
}

// Computes lighting for a single directional light.
void ComputeDirectionalLight(
    Light light, float3 Nw, float3 Vw, float exp,
    out float3 amb, out float3 diff, out float3 spec)
{
    // Compute the lighting coefficients based on the incident light direction, surface normal, and
    // view direction.
    float diffCoeff = 0.0f, specCoeff = 0.0f;
    ComputeLightingCoefficients(light.Dir, Nw, Vw, exp, diffCoeff, specCoeff);
    
    // Multiply the light color by the coefficients.
    // NOTE: The ambient component is only affected by attenuation, and there is none here.
    amb  = light.AmbColor;
    diff = light.Color * diffCoeff;
    spec = light.SpecColor * specCoeff;
}

#define LIGHT_COUNT 2

// The array of lights if order of light type: directional lights, followed by point lights,
// followed by spot lights.
Light gLightList[LIGHT_COUNT] : LightArray;

// The number of directional lights.
int gNumDirectionalLights : DirLightCount
<
    string UIName = "# Directional Lights";
    string UIWidget = "Slider";
    int UIMin = 0;
    int UIMax = 8;
    int UIStep = 1;
>
= 1;

// Compute the lighting contribution from the lights in the light array.
void ComputeLighting(
    float3 Nw, float3 Vw, float3 Pw, float exp, out float3 amb, out float3 diff, out float3 spec)
{
    // Set the initial color components to black.
    amb = diff = spec = 0.0f;
    float3 ambFromLight = 0.0f, diffFromLight = 0.0f, specFromLight = 0.0f;

    // Loop over the directional lights, adding the ambient, diffuse, and specular contributions of
    // each one to the output values.
    for (int i = 0; i < gNumDirectionalLights; i++)
    {
        ComputeDirectionalLight(gLightList[i], Nw, Vw, exp,
            ambFromLight, diffFromLight, specFromLight);

        amb  += ambFromLight;
        diff += diffFromLight;
        spec += specFromLight;
    }
}


// World transformation.
float4x4 gWXf : World < string UIWidget = "None"; >;

// World transformation, inverse transpose.
float4x4 gWITXf : WorldInverseTranspose < string UIWidget = "None"; >;

// World-view-projection transformation.
float4x4 gWVPXf : WorldViewProjection < string UIWidget = "None"; >;

// World-view transformation
float4x4 gWV : WorldView < string UIWidget = "None"; >;

#ifdef LOCAL_VIEWER
	float4x4 gVIXf : ViewInverse < string UIWidget = "None"; >;
#else
	float3 gViewDirection : ViewDirection < string UIWidget = "None"; >;
#endif

// Emissive color.
float3 gEmiColor : Emissive
<
    string UIName = "Emissive";
    string UIWidget = "Color";
> = float3(0.0f, 0.0f, 0.0f);

// Ambient color.
float3 gAmbColor : Ambient
<
    string UIName = "Ambient";
    string UIWidget = "Color";
> = float3(0.2f, 0.2f, 0.2f);

// Diffuse color.
float3 gDiffColor : Diffuse
<
    string UIName =  "Diffuse Color";
    string UIWidget = "Color";
> = float3(0.8f, 0.8f, 0.8f);

// Specular color.
float3 gSpecColor : Specular
<
    string UIName =  "Specular Color";
    string UIWidget = "Color";
> = float3(1.0f, 1.0f, 1.0f);

// Glossiness (specular power).
float gGlossiness : SpecularPower
<
    string UIName = "Glossiness";
    string UIWidget = "Slider";
    float UIMin = 1.0f;
    float UIMax = 128.0f;
    float UIStep = 10.0;
> = 32.0f;

// Opacity factor.
float gOpacity : Opacity
<
    string UIName = "Opacity";
    string UIWidget = "Slider";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
    float UIStep = 0.1f;
> = 1.0f;

struct VS_INPUT
{
    float3 Pos  : POSITION;
    float3 Normal  : NORMAL;

	// transform matrix for instancing
    float4 Row0 : TEXCOORD1;
    float4 Row1 : TEXCOORD2;
    float4 Row2 : TEXCOORD3;
    float4 Row3 : TEXCOORD4;
    float4 VertexColor : TEXCOORD5;
};

struct VS_TO_PS
{
    float4 HPos       : SV_Position;

    float3 WorldNormal    : TEXCOORD0;

    float4 Diff : COLOR0; 
    float3 Spec : COLOR1;
};

VS_TO_PS instanceVS(VS_INPUT In)
{
    VS_TO_PS Out;

    float4 HPm = float4(In.Pos, 1.0);
	float4x4 instanceMatrix = {In.Row0, In.Row1, In.Row2, In.Row3};
    HPm = mul(HPm, instanceMatrix);
	// Transform the position and normal to world space for lighting, and normalize the normal.
    float4 HPw = mul(HPm, gWXf);

    float3 Nw = normalize(mul(In.Normal, (float3x3)instanceMatrix));
	Nw = normalize(mul(Nw, (float3x3)gWITXf));
    
#ifdef LOCAL_VIEWER
    // Compute the view direction, using the eye position and vertex position.  The eye
    // position is the translation vector of the inverse view transformation matrix.  This
    // provides more accurate lighting highlights and environment-mapped reflections than
    // using a non-local viewer (below).
    float3 Vw = HPw - gVIXf[3];
    float3 VwNorm = normalize(Vw);    
#else
    // Use the fixed view direction, the same for the entire view.  Use of this vector is
    // similar to disabling D3DRS_LOCALVIEWER for lighting and reflection in D3D9 (the
    // default state).  This is appropriate for orthographic projections.
    float3 VwNorm = gViewDirection;
#endif

    // Flip the normal to face the view direction, allowing proper shading of back-facing surfaces.
    // NOTE: This will lead to artifacts on the silhouettes of coarsely-tessellated surfaces.  A
    // compensation of about nine degrees is performed here (cos(99deg) ~ 0.15), so this issue
    // should be limited to triangles with very divergent normals.
#ifdef FLIP_BACKFACING_NORMALS
    Nw = -Nw * sign(dot(VwNorm, Nw));
#endif

    Out.WorldNormal  = Nw; 	  
    Out.HPos          = mul(HPm, gWVPXf); 
    
    // Compute the ambient, diffuse, and specular lighting components from the light array.
    float3 amb = 0.0f;
    float3 spec = 0.0f;
    
    // Use the glossiness value.
    ComputeLighting(Nw, -VwNorm, HPw, gGlossiness, amb, Out.Diff.rgb, spec);
    Out.Diff.rgb *= In.VertexColor.rgb;
    Out.Diff.rgb += gAmbColor * amb + gEmiColor;
    Out.Spec = gSpecColor * spec;

    // Clamp the diffuse and specular components to [0.0, 1.0] to match the limitations of COLOR
    // registers in SM 2.0.  Otherwise the final color output will not match.
    Out.Diff = saturate(Out.Diff);

	Out.Diff.a = In.VertexColor.a;

    return Out;
}

float4 instancePS(VS_TO_PS In) : SV_Target
{
    
    // Start the output color with the diffuse component.  The rest of the shader adds to it.
    float3 outputColor = In.Diff.rgb;
    // Add the specular component.
    outputColor += In.Spec; 
    // Final color and alpha.
    float4 final = float4(outputColor, In.Diff.a);

    return final; 
}

technique10 Instance
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_4_0, instanceVS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_4_0, instancePS()));
    }
}
