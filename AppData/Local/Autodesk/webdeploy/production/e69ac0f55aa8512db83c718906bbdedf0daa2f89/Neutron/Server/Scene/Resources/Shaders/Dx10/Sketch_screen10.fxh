#ifndef _HQ_FX_SCREEN_HEADER__
#define _HQ_FX_SCREEN_HEADER__

float2 gScreenSize : NeutronSketchViewportPixelSize;
float2 gInvScreenSize : NeutronSketchViewportPixelSizeInverse;

static float2 gPixelLen = 2.0f *gInvScreenSize;
static float2 gScreenOffset = float2(0.5, 0.5f);

float2 offset_screen_pos(in float2 pos)
{
    return (pos + gScreenOffset);
}

#endif

