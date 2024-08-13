#ifndef _HQ_FX_CIRCLR_ELLIPSE_LT_H__
#define _HQ_FX_CIRCLR_ELLIPSE_LT_H__

#include "Sketch_circle_ellipse10.fxh"

struct VertexAttr_LineType_Arc
{
    nointerpolation uint patternIndex : LTYPE;   // line pattern index
    nointerpolation uint lt_dot : LTDOT;         // is pure dot
    nointerpolation uint lt_inverted : LTINV;    // line type is inverted
    nointerpolation uint reserved : RESV;        // reserved

    nointerpolation float4 patternProp : LTPROP; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset
};

struct VertexAttr_LineType_DIST
{
    nointerpolation float2 dist : DIST;           // distance from 0 degree to start/end angle
};

struct EllipseAttr_LineType
{
    uint lt_index : LTIDX;    // line type pattern index
    uint lt_dot : LTDOT;      // is pure dot
    uint lt_inverted : LTINV; // line type is inverted
    uint lt_logical : LTLOG;  // line type is logical
};

struct EllipseAttr_Dash_LT
{
    float2 center : POSITION; // screen space center
    float2 radius : RADIUS;   // screen space raiuds

    float2 range : RANGE;     // start angle end angle
    float rotate : ROTATE;    // rotation

    float weight : WEIGHT;    // line weight
    uint color : COLOR0;      // color
    float drawZ : DRAWZ;      // draw order z

    uint glowColor : COLOR1;  // glow color
    uint capType : CAPTYPE;   // cap type
    uint isLogical : FLAG;    // logical flag 0: non-logical transform, 1: logical transform
    uint lt_index : LTIDX;    // line type pattern index
    uint lt_dot : LTDOT;      // is pure dot
    uint lt_inverted : LTINV; // line type is inverted
};

struct VertexAttr_Ellipse_LT
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    nointerpolation  float2 radius : RADIUS;     // x long axis, y short axis
    nointerpolation  float2 range : RANGE;       // x start angle, y end angle

    linear float2 uv : UV;                       // uv is used to compute gradient
    nointerpolation  uint  color : COLOR0;       // ellipse color
    nointerpolation  float weight : WEIGHT;      // ellipse line weight

    nointerpolation  uint  glowColor : COLOR1;   // glow color for highlights
    uint lt_index : LTIDX;                       // line type pattern index
    uint lt_dot : LTDOT;                         // is pure dot
    uint lt_inverted : LTINV;                    // line type is inverted
};


void adjust_elliptical_arc_lt(inout EllipseAttr_Dash_LT attr)
{
    float s1, c1;
    sincos(attr.rotate + attr.range.x, s1, c1);
    float x_start = attr.center.x + attr.radius.x * c1;
    float y_start = attr.center.y + attr.radius.y * s1;
    sincos(attr.rotate + attr.range.y, s1, c1);
    float x_end = attr.center.x + attr.radius.x * c1;
    float y_end = attr.center.y + attr.radius.y * s1;

    float x_start_dev = round(x_start) - x_start;
    float y_start_dev = round(y_start) - y_start;
    float x_end_dev = round(x_end) - x_end;
    float y_end_dev = round(y_end) - y_end;
    attr.center.x += (x_start_dev + x_end_dev) / 2.0f;
    attr.center.y += (y_start_dev + y_end_dev) / 2.0f;

    float adjust_angle = min(0.25f / max(attr.radius.x, attr.radius.y), 0.01f);
    attr.range.x -= adjust_angle;
    attr.range.y += adjust_angle;
}

void set_line_type_properties(EllipseAttr_LineType linetype_attr, float4 patternProps, inout VertexAttr_LineType_Arc output)
{
    output.patternIndex = linetype_attr.lt_index;
    output.lt_dot = linetype_attr.lt_dot;
    output.lt_inverted = linetype_attr.lt_inverted;
    output.reserved = 0;
    output.patternProp = patternProps;
}

void assign_attr_lt(float4 attr_array[ATTR_SIZE], out EllipseAttr_Dash_LT attr)
{
    attr.center.x = attr_array[0].x;
    attr.center.y = attr_array[0].y;
    attr.radius.x = attr_array[0].z;
    attr.radius.y = attr_array[0].w;

    attr.range = attr_array[1].xy;
    attr.rotate = attr_array[1].z;
    attr.color = asuint(attr_array[1].w);

    attr.weight = ((asuint(attr_array[2].x) & MASK_WIDTH) >> OFFSET_WIDTH);
    attr.lt_index = ((asuint(attr_array[2].x) & MASK_LINDEX) >> OFFSET_LINDEX);
    attr.lt_dot = ((asuint(attr_array[2].x) & MASK_LDOT) >> OFFSET_LDOT);
    attr.isLogical = ((asuint(attr_array[2].x) & MASK_LFLAG) >> OFFSET_LFLAG);
    attr.capType = ((asuint(attr_array[2].x) & MASK_CTYPE) >> OFFSET_CTYPE);
    attr.lt_inverted = ((asuint(attr_array[2].x) & MASK_LTINV) >> OFFSET_LTINV);
    attr.glowColor = asuint(attr_array[2].y);
    attr.drawZ = attr_array[2].z;
}

void load_ellipse_info_lt(uint offset, out EllipseAttr_Dash attr_ellipse, out EllipseAttr_LineType attr_linetype)
{
    float4 attr_array[ATTR_SIZE];

    [unroll]
    for (uint i = 0; i < ATTR_SIZE; ++i)
    {
        int2 tex_offset = get_ptex_offset(offset*ATTR_SIZE + i);
        attr_array[i] = gPTex.Load(int3(tex_offset, 0));
    }

    assign_attr(attr_array, attr_ellipse);
    assign_attr_neutron_sketch(attr_array, attr_ellipse);

    // line type
    attr_linetype.lt_index = ((asuint(attr_array[2].x) & MASK_LINDEX) >> OFFSET_LINDEX);
    attr_linetype.lt_dot = ((asuint(attr_array[2].x) & MASK_LDOT) >> OFFSET_LDOT);
    attr_linetype.lt_inverted = ((asuint(attr_array[2].x) & MASK_LTINV) >> OFFSET_LTINV);
    attr_linetype.lt_logical = ((asuint(attr_array[2].x) & 0x40000000) >> 30);
}

VertexAttr_Ellipse_LT output_vertex_attr_ellipse_lt(NullVertex_Input input, EllipseAttr_Dash_LT ellipse_attr)
{
    // initialize
    VertexAttr_Ellipse_LT output = (VertexAttr_Ellipse_LT)(0);

    // update geometry info
    float2 center = float2(ellipse_attr.center.x, ellipse_attr.center.y);
    output.range = ellipse_attr.range;

    float2 adjusted_radius = ellipse_attr.radius;

    float sin_rot, cos_rot;
    sincos(ellipse_attr.rotate, sin_rot, cos_rot);

    [branch]if (gRetainMode)
    {
        center = logic_to_ndc(center);
        center = ndc_to_screen(center);

        adjusted_radius = neutron_sketch_radius_to_screen(adjusted_radius);
    }
    else
    {
        if (ellipse_attr.isLogical)
        {
            center = logic_to_ndc(center);
            center = ndc_to_screen(center);

            adjusted_radius = neutron_sketch_radius_to_screen(adjusted_radius);
        }
        else
        {
            if (ellipse_attr.radius.x == 0) adjusted_radius.x = 0.5f;
            if (ellipse_attr.radius.y == 0) adjusted_radius.y = 0.5f;
        }

    }


    // get the radius
    output.radius = adjusted_radius;

    output.position.xy = get_vertex_pos_envelope_30(input.VertexID, adjusted_radius.x, adjusted_radius.y,
        center, sin_rot, cos_rot, output.range, ellipse_attr.weight, output.uv);

    // update other properties
    output.weight = ellipse_attr.weight;
    output.position.z = ellipse_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.color = ellipse_attr.color; // move color assignment to last will fix an Intel compiler issue.
                                       // since the color assignment will affect position result on Intel cards.

    output.glowColor = ellipse_attr.glowColor;
    output.lt_index = ellipse_attr.lt_index;
    output.lt_dot = ellipse_attr.lt_dot;
    output.lt_inverted = ellipse_attr.lt_inverted;

    return output;
}

#endif
