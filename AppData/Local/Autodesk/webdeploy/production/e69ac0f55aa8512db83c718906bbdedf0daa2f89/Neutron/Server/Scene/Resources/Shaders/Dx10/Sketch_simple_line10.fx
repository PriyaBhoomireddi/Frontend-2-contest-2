#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_no_weight10.fxh"

struct VertexAttr_Line
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    nointerpolation float4 color : COLOR;  // line color
    nointerpolation uint glowColor : GLOW; // glow color
    linear float dist : DIST;     // distance to line  
};

// simple line index texture
Texture2D<uint> gLineIndexTex : LineIndexTexture;
Texture2D<float> gLineDrawOrderZTex : LineDrawOrderZTexture;

// simple line input information
struct LineAttr
{
    float2 startPoint;
    float2 endPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint isLogical;
};

// load simple line information
void load_line_info(uint offset, uint line_index, uint line_flag, out LineAttr attr)
{
    uint caps_type, joint_type, lt_type;
    load_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);
    load_line_flag(line_flag, attr.flag);
    load_line_attributes(line_index, attr.color, attr.width, lt_type, attr.drawZ, attr.glowColor, caps_type, joint_type, attr.isLogical);

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

// get vertex output attributes
void set_line_properties(uint vid, LineAttr line_attr, out VertexAttr_Line output)
{
    float temp_dist = 0.0f;
    bool isDot = false;

    if (line_attr.isLogical)
        output.position.xy = get_logical_line_envelope_pos(vid, line_attr.flag,
            line_attr.width, line_attr.startPoint, line_attr.endPoint, temp_dist, isDot);
    else
        output.position.xy = get_line_envelope_pos(vid,
            line_attr.width, line_attr.startPoint, line_attr.endPoint, temp_dist);

    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.dist = temp_dist;
    output.color = unpack_color(line_attr.color);
    output.glowColor = line_attr.glowColor;
}

// get vertex output attributes
VertexAttr_Line Line_VS(NullVertex_Input input)
{
    LineVertex_Input vs_input = (LineVertex_Input)0;
    load_line_input(input.VertexID, input.InstanceID, gLineIndexTex, vs_input);

    LineAttr line_attr = (LineAttr)0;
    load_line_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), get_prim_flag(vs_input.PrimID.y), line_attr);


    [branch] if (gRetainMode)
        load_dynamic_draworderz(input.InstanceID, gLineDrawOrderZTex, line_attr.drawZ);


    adjust_line_width_single_line(line_attr.width);

    VertexAttr_Line output = (VertexAttr_Line)0;
    set_line_properties(vs_input.VertexID, line_attr, output);

    return output;
}

OIT_PS_HEADER(Line_PS, VertexAttr_Line)
{
    uint t_color = pack_color(input.color);
    float4 color = compute_final_color(get_extended_dist_to_center(abs(input.dist)), get_extended_line_weight(SINGLE_LINE_WIDTH), t_color, input.glowColor);

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Line_AA
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Line_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Line_PS()));
    }
}