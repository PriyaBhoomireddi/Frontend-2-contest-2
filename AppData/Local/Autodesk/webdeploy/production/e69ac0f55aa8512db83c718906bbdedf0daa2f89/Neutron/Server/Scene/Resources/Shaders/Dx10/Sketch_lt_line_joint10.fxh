#ifndef _HQ_FX_LT_LINE_JOINT_H__
#define _HQ_FX_LT_LINE_JOINT_H__

#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_weight10.fxh"
#include "Sketch_line_type_line10.fxh"

struct VertexAttr_LineTypeJoint
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    nointerpolation uint color : COLOR;  // line color
    nointerpolation uint glowColor : GLOW;  // glow color
    nointerpolation uint width : WIDTH;  // line width;
    nointerpolation uint patternIndex : LTYPE; // line pattern index

    nointerpolation uint capsType : CAPSTYPE;  // joint type;
    nointerpolation uint jointType : JOINTYPE;  // joint type;


    nointerpolation float2 prevPoint : PREV; // previous point
    nointerpolation float2 curPoint : CUR;  // current point
    nointerpolation float2 postPoint : POST;  // post point

    nointerpolation float4 patternProp_prev : LTPROP_PREV; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset
    nointerpolation float4 patternProp_post : LTPROP_POST; // line pattern properties: x - start skip len, y - end skip len, z - pattern scale, w - pattern offset

#ifdef ANALYTIC_STIPPLE
    nointerpolation uint stippleIndex : STPIDX;  // stipple index
#endif
};

#endif
