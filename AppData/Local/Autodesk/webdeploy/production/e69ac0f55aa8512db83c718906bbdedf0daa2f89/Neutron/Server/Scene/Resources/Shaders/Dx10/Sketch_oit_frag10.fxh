#ifndef _HQ_FX_OIT_FRAGMENT_HEADER
#define _HQ_FX_OIT_FRAGMENT_HEADER

#ifndef OIT_HEADER_STRING
#include "Sketch_oit_base10.fxh"
#endif

// pixel shader output for OIT data.
struct OITPSOutput
{
    float4 color : SV_Target0;
    float4 depth : SV_Target1;

};

// linked-list OIT header data buffer
globallycoherent RWStructuredBuffer<SHeader> gHeaderBuffer: register(u4);
// linked-list OIT fragment data buffer
globallycoherent RWStructuredBuffer<SFragment> gFragmentBuffer: register(u5);
// linked-list OIT fragment count data buffer.
globallycoherent RWStructuredBuffer<uint2> gFragmentCount: register(u6);


// output color and depth to oit targets.
void OutputColors(float4 color, float depth,
    out OITPSOutput output)
{
    output.color = color;
    output.depth = float4(depth, 0.0f, 0.0f, 0.0f);
}


// fragment buffer size.
int gFragmentBufferSize;

// frame flag used to avoid invalid clear operations.
int gFrameFlag;


// get current frame flag.
int GetFrameFlag(uint offset)
{
    return ((offset & OIT_FRAME_STAMP_MASK) >> OIT_FRAME_STAMP_OFFSET);
}
// get current frame offset.
uint GetFrameOffset(uint offset)
{
    offset = offset | (gFrameFlag << OIT_FRAME_STAMP_OFFSET);

    return offset;
}

// get current linked-list last offset.
bool GetLastOffset(uint2 scrPos, float2 scrSize, out uint cur_offset, out uint last_offset)
{
    cur_offset = 0;
    last_offset = 0;

    // get the header offset in header buffer.
    uint header_pos = GetHeaderPosition(scrPos, scrSize);

    // get current fragment offset.
    InterlockedAdd(gFragmentCount[0].x, 1, cur_offset);

    // in case we don't exceed the overflow limits.
    if (cur_offset > (uint)(gFragmentBufferSize - 1024))
        return false;

    // get current frame buffer offset.
    uint cur_frame_offset = GetFrameOffset(cur_offset);

    // update header buffer pos.
    last_offset;
    InterlockedExchange(gHeaderBuffer[header_pos].header, cur_frame_offset, last_offset);

    if (GetFrameFlag(last_offset) != gFrameFlag)
    {
        last_offset = GetFrameOffset(OIT_MAX_FRAG_OFFSET);
    }

    return true;
}

// add the fragment data to fragment buffer.
void AddToFragmentBuffer(uint cur_offset, uint dw_depth, uint in_color,  uint last_offset)
{
    SFragment frag;

    frag.color = in_color;
    frag.depth = dw_depth;
    frag.next = last_offset;

    gFragmentBuffer[cur_offset] = frag;
}

// add fragment data to linked list in fragment buffer.
void AddFragment(uint2 scrPos, float2 scrSize, uint in_color, float in_depth)
{
    // get int format depth value
    uint dw_depth = GetDepthBits(in_depth);

    // get last offset of current linked-list
    uint cur_offset, last_offset;
    if (!GetLastOffset(scrPos, scrSize, cur_offset, last_offset))
        return;

    // add to fragment buffer
    AddToFragmentBuffer(cur_offset, dw_depth, in_color, last_offset);
}

#endif

