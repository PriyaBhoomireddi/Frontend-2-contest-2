#ifndef _HQ_FX_LOGICAL_PRECISION_COMMON_H__
#define _HQ_FX_LOGICAL_PRECISION_COMMON_H__

// logical space transform matrix and center.
#ifdef ROW_MAJOR_MATRIX
row_major float4x4 gLCSMatrix : NeutronSketchLCSMatrix;
#else
column_major float4x4 gLCSMatrix : NeutronSketchLCSMatrix;
#endif    

int2 gLCSCenter : NeutronSketchLCSCenter = int2(0, 0);
bool gLCSIsInteger : NeutronSketchLCSIsInteger = true;

// check if is in logical space
bool get_logical_space(float depth)
{
    return depth < 0.0;
}

float2 logic_to_ndc(float2 logical_pos)
{
    if (gLCSIsInteger)
    {
        int2 pos = asint(logical_pos);
        pos -= gLCSCenter;
        return mul(int4(pos, 0, 1), gLCSMatrix).xy;
    }
    else
    {
        float2 pos = logical_pos;
        pos -= asfloat(gLCSCenter);
        return mul(float4(pos, 0, 1), gLCSMatrix).xy;
    }
}

float2 ndc_to_logic(float2 ndc_pos)
{
    float2 posF;
    posF.x = (ndc_pos.x - gLCSMatrix[3].x) / gLCSMatrix[0].x;
    posF.y = (ndc_pos.y - gLCSMatrix[3].y) / gLCSMatrix[1].y;

    if (gLCSIsInteger)
    {
        int2 pos = posF;
        pos += gLCSCenter;
        return asfloat(pos);
    }
    else
    {
        float2 pos = posF;
        pos += asfloat(gLCSCenter);
        return pos;
    }
}

float2 neutron_sketch_logic_dir(float2 pos1, float2 pos2)
{
    if (gLCSIsInteger)
        return asint(pos1) - asint(pos2);
    else
        return pos1 - pos2;
}

#endif
