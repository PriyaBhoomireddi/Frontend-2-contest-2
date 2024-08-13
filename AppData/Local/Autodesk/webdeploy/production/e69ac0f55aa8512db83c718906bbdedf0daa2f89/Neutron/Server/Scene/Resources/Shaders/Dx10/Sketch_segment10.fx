#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_no_weight10.fxh"

// single segment input texture
Texture2D<float3> gSingleSegmentTex : SingleSegmentTexture;

Texture2D<uint> gSegmentIndexTex : SegmentIndexTexture;
Texture2D<float> gSegmentDrawOrderZTex : SegmentDrawOrderZTexture;

struct VertexAttr_Segment
{
    noperspective float4 position : SV_Position; // transformed  vertex position
    nointerpolation uint color : COLOR;  // line color
    linear float dist : DIST;     // distance to line     

    nointerpolation bool isDot : ISDOT; // line degradate to a dot 
};

// segment input information
struct SegmentAttr
{
    float2 startPoint;
    float2 endPoint;
    uint color;
    float drawZ;
    uint flag;
    bool isLogical;
};

// load segment input information
void load_single_segment_info(uint instanceID, out SegmentAttr attr)
{
    uint segmentID = instanceID;
    uint drawOrderZIndex = 0;
    [branch] if (gRetainMode)
    {
        segmentID = gSegmentIndexTex.Load(int3(get_ptex_offset(instanceID), 0));
        drawOrderZIndex = (segmentID & 0xffff0000) >> 16;
        segmentID = segmentID & 0xffff;
    }

    uint line_index = segmentID * 2;
    int2 index_offset = get_ptex_offset(line_index);

    float3 val = gSingleSegmentTex.Load(int3(index_offset, 0));

    attr.startPoint = val.xy;
    attr.endPoint.x = val.z;

    index_offset = get_ptex_offset(line_index + 1);
    val = gSingleSegmentTex.Load(int3(index_offset, 0));
    attr.endPoint.y = val.x;
    attr.color = asuint(val.z);

    [branch] if (gRetainMode)
    {
        attr.flag = get_prim_flag(asuint(val.y));
        attr.isLogical = true;
        drawOrderZIndex = (drawOrderZIndex > 0) ? (drawOrderZIndex - 1) : (asuint(val.y) & 0xffff);
        load_dynamic_draworderz(drawOrderZIndex, gSegmentDrawOrderZTex, attr.drawZ);
    }
    else
    {
        attr.drawZ = abs(val.y);
        attr.isLogical = val.y < 0.0f;
        if (!attr.isLogical)
            adjust_line_segment_precision(attr.startPoint, attr.endPoint);

        attr.flag = 0;
    }
}

// compute segment vertex output properties
void set_single_segment_propertties(uint vid, SegmentAttr seg_attr, float width, out VertexAttr_Segment output)
{
    float temp_dist = 0.0f;
    bool temp_isDot = false;

    [branch] if (gRetainMode)
    {
        output.position.xy = get_logical_line_envelope_pos(vid, seg_attr.flag,
            width, seg_attr.startPoint, seg_attr.endPoint, temp_dist, temp_isDot);
        output.isDot = temp_isDot;
    }

    else
    {
        if (seg_attr.isLogical)
        {

            output.position.xy = get_logical_line_envelope_pos(vid, 0,
                width, seg_attr.startPoint, seg_attr.endPoint, temp_dist, temp_isDot);
            output.isDot = temp_isDot;
        }
        else
        {
            output.position.xy = get_line_envelope_pos(vid,
                width, seg_attr.startPoint, seg_attr.endPoint, temp_dist);
            output.isDot = false;
        }


    }

    output.position.z = seg_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.dist = temp_dist;
    output.color = seg_attr.color;
}

VertexAttr_Segment Segment_VS(NullVertex_Input input)
{
    SegmentAttr seg_attr = (SegmentAttr)0;

    load_single_segment_info(input.InstanceID, seg_attr);

    float width = SINGLE_LINE_WIDTH_EXPAND;

    VertexAttr_Segment output = (VertexAttr_Segment)0;
    set_single_segment_propertties(input.VertexID, seg_attr, width, output);


    return output;
}

OIT_PS_HEADER(Segment_PS, VertexAttr_Segment)
{
    float4 color;
    [branch] if (gRetainMode)
    {
        color = input.isDot ? get_formatted_color(input.color, 1.0f) : compute_final_color(get_extended_dist_to_center(abs(input.dist)), get_extended_line_weight(SINGLE_LINE_WIDTH), input.color, 0);
    }
    else
    {
        color = compute_final_color(get_extended_dist_to_center(abs(input.dist)), get_extended_line_weight(SINGLE_LINE_WIDTH), input.color, 0);
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Segment_AA
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Segment_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Segment_PS()));
    }
}

