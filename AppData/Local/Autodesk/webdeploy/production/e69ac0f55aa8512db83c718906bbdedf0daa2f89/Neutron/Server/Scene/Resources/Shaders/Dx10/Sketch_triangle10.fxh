#ifndef _HQ_FX_TRIANGLE_H__
#define _HQ_FX_TRIANGLE_H__

#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"

struct TriVertexAttr
{
    float2 pos; // vertex position
    uint prim_id; // primitive id for triangle strip

    float  drawZ; // draw-z value
    uint   color; // vertex color
    bool   isLogical; // whether in logical coordinates
};

struct TexTriVertexAttr
{
    float2 pos; // vertex position
    float2 uv;  // texture coordinate

    float  drawZ; // draw-z value
    uint   color; // vertex color
    bool   isLogical; // whether in logical coordinates
    uint   tex_index; // index of texture to sample
};

struct StippleTriVertexAttr
{
    float2 pos; // vertex position
    uint prim_id; // primitive id for triangle strip

    float  drawZ; // draw-z value
    uint   color; // vertex color
    bool   isLogical; // whether in logical coordinates

    uint stipple_index; // index into the stipple texture
};

struct VertexAttr_Triangle
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    nointerpolation float4 color : COLOR;  // color
};

struct VertexAttr_Gouraud_Triangle
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    noperspective float4 color : COLOR;  // color to be interpolated
};

struct VertexAttr_Textured_Triangle
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    nointerpolation float4 color : COLOR;  // color
    noperspective  float2 uv : UV;
    nointerpolation uint tex_index : TEXIDX;
};

struct VertexAttr_Stipple_Triangle
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    nointerpolation float4 color : COLOR;  // color
    nointerpolation uint stipple_index : STPIDX;
};

// set properties of general triangles for pixel shader
void set_triangle_properties(TriVertexAttr attr, out VertexAttr_Triangle output)
{
    output.color = get_formatted_color(attr.color, 1.0f);

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

// set properties of gouraud triangles for pixel shader
void set_gouraud_triangle_properties(TriVertexAttr attr, out VertexAttr_Gouraud_Triangle output)
{
    output.color = get_formatted_color(attr.color, 1.0f);

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

// set properties of textured triangles for pixel shader
void set_textured_triangle_properties(TexTriVertexAttr attr, out VertexAttr_Textured_Triangle output)
{
    output.color = get_formatted_color(attr.color, 1.0f);
    output.uv = attr.uv;
    output.tex_index = attr.tex_index;

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

// set properties of stipple triangles for pixel shader
void set_stipple_triangle_properties(StippleTriVertexAttr attr, out VertexAttr_Stipple_Triangle output)
{
    output.color = get_formatted_color(attr.color, 1.0f);

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

    output.stipple_index = attr.stipple_index;
}

// load triangle index from index texture
uint load_tri_id_from_tex(Texture2D<uint> indexTex, uint id)
{
    int2 tex_offset = get_ptex_offset(id);
    return indexTex.Load(int3(tex_offset, 0));
}

#endif
