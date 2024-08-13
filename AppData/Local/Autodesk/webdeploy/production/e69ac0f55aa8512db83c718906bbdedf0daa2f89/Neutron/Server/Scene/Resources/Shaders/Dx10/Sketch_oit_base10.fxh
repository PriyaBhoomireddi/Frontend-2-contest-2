#ifndef _HQ_FX_OIT_COMMON_HEADER
#define _HQ_FX_OIT_COMMON_HEADER

#ifndef OIT_HEADER_STRING
#include "Sketch_color10.fxh"
#include "Sketch_screen10.fxh"
#include "Sketch_math10.fxh"
#endif

#define MAX_OIT_DEPTH (0xffffffff)
#define MAX_VALID_OIT_DEPTH (0x007fffff)
#define OIT_DEPTH_BITS_MASK (0x007fffff)

#define OIT_FRAG_OFFSET_MASK (0x03ffffff)
#define OIT_MAX_FRAG_OFFSET (0x03ffffff)
#define OIT_FRAME_STAMP_MASK (0xfc000000)
#define OIT_FRAME_STAMP_OFFSET (26)


// the fragment data structure for linked-list OIT.
struct SFragment
{
    uint color;
    uint depth;
    uint next;
};
// the header offset structure of linked-list OIT.
struct SHeader
{
    uint header;
};


// get header buffer offset based on screen position.
uint GetHeaderPosition(uint2 scrPos, float2 scrSize)
{
    return (scrPos.y*scrSize.x + scrPos.x);
}

// adjust depth value
uint GetDepthBits(float in_depth)
{

    uint dw_depth = MAX_OIT_DEPTH;

    if (in_depth < 1.0f)
    {
        dw_depth = (asuint(in_depth) & OIT_DEPTH_BITS_MASK);
    }

    return dw_depth;
}


#endif

