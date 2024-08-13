#ifndef _HQ_FX_LOGICAL_SCREEN_COMMON_H__
#define _HQ_FX_LOGICAL_SCREEN_COMMON_H__

#include "Sketch_logical_precision10.fxh"
#include "Sketch_screen10.fxh"

float neutron_sketch_screen_to_logical(float x)
{
    return x * gPixelLen.x / abs(gLCSMatrix[0].x);
}

float neutron_sketch_logical_to_screen(float x)
{
    return x / gPixelLen.x * abs(gLCSMatrix[0].x);
}

float2 neutron_sketch_radius_to_screen(float2 radius)
{
    if (gLCSIsInteger)
        return asint(radius) * abs(float2(gLCSMatrix[0].x, gLCSMatrix[1].y)) * gScreenSize * 0.5f;
    else
        return radius * abs(float2(gLCSMatrix[0].x, gLCSMatrix[1].y)) * gScreenSize * 0.5f;
}

float neutron_sketch_lcs_matrix_det()
{
    return gLCSMatrix[0].x * gLCSMatrix[1].y;
}

float neutron_sketch_lcs_matrix_det_sign()
{
    return sign(neutron_sketch_lcs_matrix_det());
}

float2 neutron_sketch_lcs_matrix_scale()
{
    return float2(gLCSMatrix[0].x, gLCSMatrix[1].y);
}

float2 neutron_sketch_lcs_matrix_scale_sign()
{
    return sign(neutron_sketch_lcs_matrix_scale());
}

#endif

