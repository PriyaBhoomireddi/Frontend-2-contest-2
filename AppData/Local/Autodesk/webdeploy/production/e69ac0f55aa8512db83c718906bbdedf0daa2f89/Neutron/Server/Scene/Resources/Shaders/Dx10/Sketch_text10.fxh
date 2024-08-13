#ifndef _HQ_FX_TEXT_H__
#define _HQ_FX_TEXT_H__

#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"

struct CurvedTextVertexAttr
{
    float2 pos; // vertex position
    float2 uv;  // texture coordinate

    float  drawZ; // draw-z value
    uint   color; // vertex color
    bool   isLogical; // whether in logical coordinates
    float2 triType; // inner, convex, concave
};

struct VertexAttr_Curved_Text
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    nointerpolation float4 color : COLOR;  // color
    noperspective  float2 uv : UV;
    nointerpolation float2 triType : TRITYPE;
};

// set properties of curved text for pixel shader
void set_curved_text_properties(CurvedTextVertexAttr attr, out VertexAttr_Curved_Text output)
{
    output.color = get_formatted_color(attr.color, 1.0f);
    output.uv = attr.uv;
    output.triType = attr.triType;

    [branch]if (gRetainMode)
    {
        output.position.xy = logic_to_ndc(attr.pos);
    }
    else
    {
        output.position.xy = attr.isLogical ? logic_to_ndc(attr.pos) : screen_to_ndc_pos(offset_screen_pos(attr.pos));
    }

    output.position.z = attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;
}

// load triangle index from index texture
uint load_tri_id_from_tex(Texture2D<uint> indexTex, uint id)
{
    int2 tex_offset = get_ptex_offset(id);
    return indexTex.Load(int3(tex_offset, 0));
}

#endif
