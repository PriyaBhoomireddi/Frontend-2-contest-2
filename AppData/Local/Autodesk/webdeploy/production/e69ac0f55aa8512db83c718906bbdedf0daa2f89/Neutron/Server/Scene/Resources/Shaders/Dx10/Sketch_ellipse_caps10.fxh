#ifndef _HQ_FX_ELLIPSE_CAPS_H__
#define _HQ_FX_ELLIPSE_CAPS_H__

#include "Sketch_circle_ellipse10.fxh"
#include "Sketch_circle10.fxh"
#include "Sketch_ellipse10.fxh"

struct VertexAttr_Caps
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    linear float2 uv : UV;     // uv is used to compute gradient
    linear float4  ref : REF;   // xy reference point, zw reference dir

    nointerpolation  float2 radius : RADIUS;  // x long axis, y short axis
    nointerpolation  float2 range : RANGE;  // x start angle, y end angle
    nointerpolation  uint  color : COLOR0;  // line color
    nointerpolation  float weight : WEIGHT; // line weight

    nointerpolation  uint  glowColor : COLOR1; // glow color for highlights
    nointerpolation  uint  capType : TYPE; // cap type
};

// adjust elliptical arc for precision. don't need to do adjustment in logic CS since this circle is
// represented with float type and is precise.
void adjust_caps(inout EllipseAttr_Dash attr)
{
    if (!attr.isLogical)
    {
        bool is_closed = is_closed_arc(attr.range);
        bool is_circle = is_circle_arc(attr.radius);

        if (is_closed)
        {
            if (is_circle)
                adjust_closed_circle(attr);
            else
                adjust_closed_ellipse(attr);
        }
        else
        {
            if (is_circle)
                adjust_circle_arc(attr);
            else
                adjust_elliptical_arc(attr);
        }
        updateOffset(attr.center);
    }
}

#endif
