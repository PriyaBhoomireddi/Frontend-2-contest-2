//**************************************************************************/
// Copyright 2015 Autodesk, Inc.
// All rights reserved.
//
// This computer source code and related instructions and comments are the
// unpublished confidential and proprietary information of Autodesk, Inc.
// and are protected under Federal copyright and state trade secret law.
// They may not be disclosed to, copied or used by any third party without
// the prior written consent of Autodesk, Inc.
//**************************************************************************/
// DESCRIPTION: Virtual ground plane effect (D3D10).
// AUTHOR: Shubird
// CREATED: July 2015
//**************************************************************************/

#include "Common10.fxh"

#define PI 3.141592654

// Environment map
Texture2D g_LatLongTex;
SamplerState g_LatLongSampler;
float4x4 g_LatLongTransform;
float4 g_LatLongGain;

// Ground parameters:
float3 g_PivotPosW;
float3 g_GroundWorldPt;
float3 g_GroundNormal;

// Scene camera parameters:
// Whether scene camera is perspective.
bool g_SceneCameraPerspective
<
    string UIName = "Perspective View";
> = true;
// Scene camera world-space position.
float3 g_SceneCameraWorldPos;
// Projection matrix of scene camera.
float4x4 g_SceneCameraPXf < string UIWidget = "None"; >;
// View scale, i.e. view-space size at a distance of one.
static float2 g_SceneCameraViewScale = 1.0 / float2(g_SceneCameraPXf[0][0], g_SceneCameraPXf[1][1]);
// View inverse martrix of scene camera.
float4x4 g_SceneCameraVIXf < string UIWidget = "None"; >;


// Sample the lat-long environment map by the direction.
float3 SampleLatLongDirection(texture2D tex, sampler samp, float4x4 transform, float3 direction)
{
   // Transform sample direction using the texture matrix.
   float3 dir = normalize(mul(float4(direction,0.0), transform).xyz);
   
   float latitude = -asin(dir.y)/PI + 0.5;
   // Clamp the latitude value to avoid artifacts at the poles.
   // NOTE: The clamping values should be based on the texture height, but this these values will
   // work for most cases.
   latitude = clamp(latitude, 0.001, 0.999);
   float longitude = atan2(dir.x, -dir.z)/PI*0.5+0.5;
   return tex.Sample(samp, float2(longitude,latitude)).rgb;
}

// Return the world-space (3D) position of the pixel.
// depth input parameter is the depth value of view space.
float4 GetWorldPosition(float2 texUV, float depth, bool perspective)
{
    // Convert texUV to normalized [-1.0, 1.0] device coordinates.
    // Note, the texUV need to be inverted as 1.0-texUV.y. 
    //       (1.0-texUV.y)*2.0-1.0 equals to texUV.y*(-2.0)+1.0.
    float2 pos2D = texUV * float2(2.0, -2.0) + float2(-1.0, 1.0);

    // Compute the depth scale from the depth of the current pixel and the view scale.  This
    // is the vector from the center of the screen to the corners of the screen in view space, at
    // the current depth. 
    float2 depthScale = (perspective ? depth : 1.0) * g_SceneCameraViewScale;

    // Get the view-space (3D) position of the current pixel from the depth, the depth
    // scale, and the recovered [-1.0, 1.0] device coordinates.
    float3 viewPos = float3(pos2D * depthScale, depth);

    // Get the world-space (3D) position.
    float4 worldPos = mul(float4(viewPos, 1.0), g_SceneCameraVIXf);

    return worldPos;
}

// Pixel shader.
float4 PS_Ground(VS_TO_PS_ScreenQuad In) : SV_Target
{
    // Get the world-space (3D) position of current pixel at far plane(depth set as 1.0).
    // Note: Whether it is a perspective view or not, the depth of far plane is 1.0.
    float4 worldPos = GetWorldPosition(In.UV, 1.0, g_SceneCameraPerspective);

    float normalLength = length(g_GroundNormal);

    // In perspective projection, view direction is the direction from the scene camera to the draw quad vertex;
    // In orthographic projection, view direction is the view direction of scene camera, which is acquired from view inverse matrix.
    float3 Vw = g_SceneCameraPerspective ? worldPos.xyz - g_SceneCameraWorldPos : float3(g_SceneCameraVIXf[2][0], g_SceneCameraVIXf[2][1], g_SceneCameraVIXf[2][2]);

    float viewDotN = dot(Vw, g_GroundNormal);

    // Get the distance from the camera position to the ground plane in world-space.
    float camera2GroundDist = dot(g_GroundWorldPt - g_SceneCameraWorldPos, g_GroundNormal) / normalLength;

    // If the view direction is towards the ground plane and the camera position is above the 
    // ground plane, use pivot projection.
    float4 outColor = float4(0,0,0,1.0);
    if (viewDotN < 0 && camera2GroundDist < 0)
    {
        // Use the pivot projection at the ground plane:

        // Get the intersection point of the view ray hitting the ground plane.
        float cos = dot(Vw, g_GroundNormal) / (normalLength * length(Vw));

        // In perspective projection, view position is scene camera position;
        // In orthographic projection, view position is draw quad vertex.
        float3 viewPos = g_SceneCameraWorldPos;
        float viewPos2GroundDist = camera2GroundDist;
        if (!g_SceneCameraPerspective)
        {
            viewPos = worldPos.xyz;
            viewPos2GroundDist = dot(g_GroundWorldPt - viewPos, g_GroundNormal) / normalLength;
        }

        float3 intersectPt = viewPos + normalize(Vw) * (viewPos2GroundDist / cos);

        // Use the new ray direction from the pivot to the ground intersection point.
        float3 dir = normalize(intersectPt - g_PivotPosW);

        // Apply the gain here.
        outColor.rgb = g_LatLongGain.rgb * SampleLatLongDirection(g_LatLongTex, g_LatLongSampler, g_LatLongTransform, dir);
    }
    else
    {
        // Discard the pixel if it is not on the ground horizon.
        discard;
    }

    return outColor;
}

// The main technique.
technique10 Main
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_4_0, VS_ScreenQuad()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_4_0, PS_Ground()));
    }
}
