#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_no_weight10.fxh"

struct GradientVertexAttr_Line
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    linear float4 color : COLOR;  // line color
    linear float dist : DIST;     // distance to line  
};

// gradient line index texture
Texture2D<uint> gGradientLineIndexTex : GradientLineIndexTexture;
Texture2D<float> gGradientLineDrawOrderZTex : GradientLineDrawOrderZTexture;

// gradient line input information
struct GradientLineAttr
{
    float2 startPoint;
    float2 endPoint;

    uint startColor;
    uint endColor;

    uint flag;
    float drawZ;
    uint isLogical;
};

// load gradient line information
void load_gradient_line_info(uint offset, uint line_index, uint line_flag, out GradientLineAttr attr)
{
    load_gradient_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint, attr.startColor, attr.endColor);
    load_line_flag(line_flag, attr.flag);
    load_gradient_line_attributes(line_index, attr.drawZ, attr.isLogical);

    [branch] if (gRetainMode)
    {
        adjust_line_segment_precision_logical(attr.startPoint, attr.endPoint);
    }
    else
    {
        if (!attr.isLogical)
            adjust_line_segment_precision(attr.startPoint, attr.endPoint);
    }
}

void set_gradient_line_properties(uint vid, GradientLineAttr line_attr, out GradientVertexAttr_Line output)
{
    float temp_dist = 0.0f;
    bool isDot = false;

    if (line_attr.isLogical)
        output.position.xy = get_logical_line_envelope_pos(vid, line_attr.flag,
            1.0f, line_attr.startPoint, line_attr.endPoint, temp_dist, isDot);
    else
        output.position.xy = get_line_envelope_pos(vid,
            1.0f, line_attr.startPoint, line_attr.endPoint, temp_dist);

    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.dist = temp_dist;

    if ((vid == 0) || (vid == 2))
        output.color = unpack_color(line_attr.startColor);
    else
        output.color = unpack_color(line_attr.endColor);
}

GradientVertexAttr_Line GradientLine_VS(NullVertex_Input input)
{
    LineVertex_Input vs_input = (LineVertex_Input)0;
    load_gradient_line_input(input.VertexID, input.InstanceID, gGradientLineIndexTex, vs_input);

    GradientLineAttr line_attr = (GradientLineAttr)0;
    load_gradient_line_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), get_prim_flag(vs_input.PrimID.y), line_attr);

    [branch] if (gRetainMode)
        load_dynamic_draworderz(input.InstanceID, gGradientLineDrawOrderZTex, line_attr.drawZ);

    GradientVertexAttr_Line output = (GradientVertexAttr_Line)0;
    set_gradient_line_properties(vs_input.VertexID, line_attr, output);

    return output;
}

OIT_PS_HEADER(GradientLine_PS, GradientVertexAttr_Line)
{
    uint t_color = pack_color(input.color);
    float4 color;

    float anti_aliasing_val = get_antialiasing_val(get_extended_dist_to_center(abs(input.dist)), get_extended_line_weight(SINGLE_LINE_WIDTH));
    color = get_formatted_color(t_color, anti_aliasing_val);

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Line_AA
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, GradientLine_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, GradientLine_PS()));
    }
}