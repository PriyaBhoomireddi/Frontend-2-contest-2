#ifndef _HQ_FX_OIT_DEF_HEADER__
#define _HQ_FX_OIT_DEF_HEADER__

#ifndef OIT_HEADER_STRING
#include "Sketch_oit_base10.fxh"
#endif

#ifdef LINKED_LIST_OIT_ENABLE
// pixel shader declaration
#define OIT_PS_HEADER(ShaderName, InputName) \
        OITPSOutput ShaderName(InputName input)
#define OIT_PS_HEADER_2(ShaderName, InputName, InputName2) \
        OITPSOutput ShaderName(InputName input, InputName2 input2)
#define OIT_PS_HEADER_3(ShaderName, InputName, InputName2, InputName3) \
        OITPSOutput ShaderName(InputName input, InputName2 input2, InputName3 input3)

#ifndef OIT_HEADER_STRING
#include "Sketch_oit_frag10.fxh"
#endif

// primitives are opaque or not
bool gOpaque = false;

// clip texture used for screen clipping
Texture2D  gClipTex;
SamplerState gClipSampler;

// use texture to clip pixels
void oit_clip(uint2 scrPos)
{
    [branch]if (gClipMode)
    {
        float4 clip_color = gClipTex.Load(uint3(scrPos, 0.0));

        if (clip_color.r == 0.0f)
            discard;
    }
}


// process transparent fragment
void oit_process_transparent(uint2 scrPos, float4 color, float zvalue)
{
#ifdef LINKED_LIST_OIT_TRANSPARENT
    [branch]if (!gOpaque)
    {
        // In order to reduce the number of pixel passed to OIT process
        // for performance, we discard the pixel that is near to complete
        // transparent.
        if (color.a < 0.01f)
            discard;

        bool bDiscard = false; // workaround AMD card compiler issue
        if (color.a < 0.99f)
        {
            AddFragment(scrPos, gScreenSize, pack_color(color), zvalue);
            bDiscard = true;
        }
        if (bDiscard)
            discard;
    }
#endif
}

// output fragment data to fragment buffer when OIT on.
#define OIT_PS_OUTPUT(color, position)                          \
        uint2 scrPos = (uint2)position.xy;                      \
                                                                \
        oit_clip(scrPos);                                       \
        oit_process_transparent(scrPos, color, position.z);     \
                                                                \
        OITPSOutput oit_output;                                 \
        OutputColors(color, position.z,                         \
                    oit_output);                                \
                                                                \
        return oit_output;
#else

// output pixel data when OIT off.
#define OIT_PS_HEADER(ShaderName, InputName)                    \
        float4 ShaderName(InputName input):SV_Target
#define OIT_PS_HEADER_2(ShaderName, InputName, InputName2)                    \
        float4 ShaderName(InputName input, InputName2 input2):SV_Target
#define OIT_PS_HEADER_3(ShaderName, InputName, InputName2, InputName3)                    \
        float4 ShaderName(InputName input, InputName2 input2, InputName3 input3):SV_Target

// Given the OIT process has discarded the nearly complete
// transparent pixel. We do same thing here in order to get
// same visual result as OIT enabled.
#define OIT_PS_OUTPUT(color, position)                          \
        if (color.a < 0.01f)                                    \
            discard;                                            \
                                                                \
        color = neutron_sketch_adjust_output_color(color);      \
        return color;
#endif

#endif
