#ifndef _HQ_FX_COLOR_HEADER__
#define _HQ_FX_COLOR_HEADER__

// Neutron's monochrome output: 0=off,1=max,2=min
int gNeutronSketchMonoMode : NeutronSketchMonoMode = 0;

// render options
bool gClipMode = false;
bool gRetainMode = false;

// change to int to be incompatible with GLSL 300. 
int gNoAAMode = false;

// color pack methods
uint pack_color(float4 color)
{
    uint4 dw_color = (uint4)(color*255.0f);
    return (dw_color.b & 0x000000ff) |
        ((dw_color.g & 0x000000ff) << 8) |
        ((dw_color.r & 0x000000ff) << 16) |
        ((dw_color.a & 0x000000ff) << 24);
}

float4 unpack_color(uint color)
{
    return float4(((color & 0x00ff0000) >> 16) / 255.0f,
        ((color & 0x0000ff00) >> 8) / 255.0f,
        ((color & 0x000000ff) >> 0) / 255.0f,
        ((color & 0xff000000) >> 24) / 255.0f
        );
}

float4 neutron_sketch_adjust_output_color(float4 color)
{
    if (gNeutronSketchMonoMode == 1) return color.aaaa;
    if (gNeutronSketchMonoMode == 2) return float4(1.0f, 1.0f, 1.0f, 1.0f) - color.aaaa;
    return color;
}

#endif

