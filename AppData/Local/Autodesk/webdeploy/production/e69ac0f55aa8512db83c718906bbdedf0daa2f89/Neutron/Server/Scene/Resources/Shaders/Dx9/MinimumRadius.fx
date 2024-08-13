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
    amb = light.AmbColor;
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

        amb += ambFromLight;
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

// Inverse view, used for normal in local or perspective view
float4x4 gVIXf : ViewInverse < string UIWidget = "None"; >;

// View direction, for orthographic view
float3 gViewDirection : ViewDirection < string UIWidget = "None"; >;

// Projection, used to determine what the current view is
float4x4 gProjection : Projection < string UIWidget = "None"; >;

// Whether the projection matrix flips Z: -1.0 if so, otherwise 1.0.
float gProjZSense : ProjectionZSense < string UIWidget = "None"; >;

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
> = float3(0.0f, 0.0f, 0.0f);

// Diffuse color.
float3 gDiffColor : Diffuse
<
    string UIName = "Diffuse Color";
    string UIWidget = "Color";
> = float3(0.7f, 0.7f, 0.7f);

// Specular color.
float3 gSpecColor : Specular
<
    string UIName = "Specular Color";
    string UIWidget = "Color";
> = float3(0.0f, 0.0f, 0.0f);

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

float gMinimumRadius : MinimumRadius = 1.0f;

float gTolerance : Tolerance = 0.0f;

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
    float3 Normal: NORMAL;
    float2 UV  : TEXCOORD0;
    float2 Curvature  : TEXCOORD1;
    float2 NormalReversed : TEXCOORD2; // Used as a boolean to indicate if the face normal as been reversed
};

struct VS_TO_PS
{
    float4 HPos       : Position;
    float2 CurData    : TEXCOORD0;
    float3 Normal  : TEXCOORD1;
    float NormalReversed : TEXCOORD2;
    float3 ViewDir : TEXCOORD3;
    float3 Diff : COLOR0;
    float3 Spec : COLOR1;
};

VS_TO_PS minimumRadiusVS(VS_INPUT IN)
{
    VS_TO_PS OUT;
    float4 P = float4(IN.Pos, 1.0);
    OUT.HPos = mul(P, gWVPXf);

    // Transform the position and normal to world space for lighting, and normalize the normal.
    float4 HPw = mul(P, gWXf);
    float3 Nw = normalize(mul(IN.Normal, (float3x3)gWITXf));

    // Compute the view direction, using the eye position and vertex position.  The eye
    // position is the translation vector of the inverse view transformation matrix.  This
    // provides more accurate lighting highlights and environment-mapped reflections than
    // using a non-local viewer (below).
    float3 Vw = HPw - gVIXf[3];
    float3 VwPerspectiveNorm = normalize(Vw);

    // Use the fixed view direction, the same for the entire view.  Use of this vector is
    // similar to disabling D3DRS_LOCALVIEWER for lighting and reflection in D3D9 (the
    // default state).  This is appropriate for orthographic projections.
    float3 VwNorm = gViewDirection;

#ifdef LOCAL_VIEWER
    VwNorm = VwPerspectiveNorm;
#endif

    // Pass normal and view direction on to PS function.
    OUT.Normal = Nw;
    OUT.NormalReversed = IN.NormalReversed.x;
    OUT.ViewDir = gViewDirection;

    if (gProjection[2][3] == 1.0) { // 1.0 is perspective view, 0.0 is orthographic view
        OUT.ViewDir = VwPerspectiveNorm;
    }

    // Flip the normal to face the view direction, allowing proper shading of back-facing surfaces.
    // NOTE: This will lead to artifacts on the silhouettes of coarsely-tessellated surfaces.  A
    // compensation of about nine degrees is performed here (cos(99deg) ~ 0.15), so this issue
    // should be limited to triangles with very divergent normals.
#ifdef FLIP_BACKFACING_NORMALS
    Nw = -Nw * sign(dot(VwNorm, Nw));
#endif

    // Compute the ambient, diffuse, and specular lighting components from the light array.
    float3 amb = 0.0f;
    float3 spec = 0.0f;

    ComputeLighting(Nw, -VwNorm, HPw, gGlossiness, amb, OUT.Diff.rgb, spec);
    OUT.Diff.rgb *= gDiffColor;
    OUT.Diff.rgb += gAmbColor * amb + gEmiColor;
    OUT.Spec = gSpecColor * spec;

    // Clamp the diffuse and specular components to [0.0, 1.0] to match the limitations of COLOR
    // registers in SM 2.0.  Otherwise the final color output will not match.
    OUT.Diff = saturate(OUT.Diff);

    // modify the HPos a bit by biasing the Z a bit forward, based on depth priority
    OUT.HPos.z -= OUT.HPos.w*gDepthPriority;

    OUT.CurData.x = atan(IN.Curvature.x);
    OUT.CurData.y = atan(IN.Curvature.y);

    return OUT;
}

// Pixel shader - colour as red or green based on the radius of curvature
float4 minimumRadiusPS(VS_TO_PS IN) : COLOR
{
    float curvatureU = tan(IN.CurData.x);
    float curvatureV = tan(IN.CurData.y);

    float sign = 1;

    // Check whether the normal is facing in the same direction as the view,
    // if so the curvature needs to be reversed.
    if (dot(IN.ViewDir, IN.Normal) > 0) {
        sign *= -1;
    }

    // Also need to flip the curvature if the normal is reversed.
    // Note: NormalReversed should be 0.0 or 1.0, but interpolation can lead to an imprecise float, so use 0.5 for comparison
    if (IN.NormalReversed > 0.5) {
        sign *= -1;
    }
    
    curvatureU *= sign;
    curvatureV *= sign;
    
    if (curvatureU > 1 / gMinimumRadius || curvatureV > 1 / gMinimumRadius) {
        return float4(1.0f, 0.0f, 0.0f, gOpacity);
    }
    else if (curvatureU > gTolerance || curvatureV > gTolerance) {
        return float4(0.0f, 1.0f, 0.0f, gOpacity);
    }
    else {
        return float4(IN.Diff.rgb, 1.0f);
    }
}

technique MinimumRadius
{
    pass P0
    {
        VertexShader = compile vs_2_0 minimumRadiusVS();
        PixelShader = compile ps_2_0 minimumRadiusPS();
    }
}
