#include "Sketch_lt_simple_line10.fxh"

// line type index texture
Texture2D<uint> gLineTypeIndexTex: LineTypeIndexTexture;

// line type draw order z  texture for retain mode
Texture2D<float> gLineTypeDrawOrderZTex : LineTypeDrawOrderZTexture;

// line type line vertex shader
VertexAttr_LineType LineType_VS(NullVertex_Input input)
{
    LineVertex_Input vs_input = (LineVertex_Input)0;
    load_line_input(input.VertexID, input.InstanceID, gLineTypeIndexTex, vs_input);

    LineTypeAttr line_attr = (LineTypeAttr)0;
    load_line_type_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), get_prim_flag(vs_input.PrimID.y), vs_input.SegmentID, line_attr);

    [branch] if (gRetainMode)
        load_dynamic_draworderz(input.InstanceID, gLineTypeDrawOrderZTex, line_attr.drawZ);

    return outputLineType_VS(vs_input.VertexID, line_attr);
}

OIT_PS_HEADER(LineType_PS, VertexAttr_LineType)
{
    // set attributes.
    SimpleLineTypeAttr attr;
    attr.toLineDist = input.dist.x;
    attr.startDist = input.dist.y;
    attr.endDist = input.dist.z;
    attr.startSkipLen = input.patternProp.x;
    attr.endSkipLen = input.patternProp.y;
    attr.patternScale = input.patternProp.z;
    attr.patternOffset = input.patternProp.w;
    attr.patternID = input.patternIndex;
    attr.lineDir = normalize(float2(input.lineParams.y, -input.lineParams.x));
    attr.isClosed = false;
    attr.isCurve = false;

    // check current pixel is on display or not
    SimpleLineTypeResult result;
    bool display = check_line_pattern(attr, result);

    if (!display)
        discard;

    float4 color = getColorfromLTAttr(input, result);

    // output color and position
    OIT_PS_OUTPUT(color, input.position);
}

technique11 Line_Type
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, LineType_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, LineType_PS()));
    }
}

