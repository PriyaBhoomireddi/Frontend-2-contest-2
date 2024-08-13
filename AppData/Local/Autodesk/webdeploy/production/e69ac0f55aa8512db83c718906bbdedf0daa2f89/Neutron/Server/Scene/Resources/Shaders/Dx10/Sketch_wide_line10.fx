#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"
#include "Sketch_line10.fxh"
#include "Sketch_line_weight10.fxh"

#ifdef ANALYTIC_STIPPLE
  #include "Sketch_stipple10.fxh"
#endif

struct VertexAttr_MetaWideLine
{
    noperspective float4 position : SV_Position; // transformed  vertex position

    nointerpolation uint flag : FLAG;   // line flag
    nointerpolation uint color : COLOR;  // line color
    nointerpolation uint glowColor : GLOW;  // glow color
    nointerpolation uint width : WIDTH;  // line width;
    nointerpolation uint shapeType : SHAPETYPE;  // line shader type
    nointerpolation uint subType : SUBTYPE;// caps type or joint type;

    // points:
    // caps:  PNT0 = center point
    //        PNT1 = end point
    //        PNT2 = dir
    // joint: PNT0 = prev point
    //        PNT1 = current point
    //        PNT2 = post point
    // body:  PNT0 = prev point
    //        PNT1 = start point
    //        PNT2 = end point
    //        PNT3 = post point
    nointerpolation float2 point0 : PNT0;
    nointerpolation float2 point1 : PNT1;
    nointerpolation float2 point2 : PNT2;
    nointerpolation float2 point3 : PNT3;

    linear float dist : DIST;     // distance to line

#ifdef ANALYTIC_STIPPLE
    nointerpolation uint stippleIndex : STPIDX;  // stipple index
#endif
};

struct CapsLineAttr
{
    float2 startPoint;
    float2 endPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint capsType;
    uint isLogical;

#ifdef ANALYTIC_STIPPLE
    uint stippleIndex;
#endif
};

// get the point relating to line caps
void get_caps_points(CapsLineAttr attr, bool isEndPoint, out float2 cur_point, out float2 next_point)
{
    // if is first segment of polyline
    if ((attr.flag & HAS_PREV_LINE) == 0)
    {
        if (isEndPoint)
        {
            cur_point = attr.endPoint;
            next_point = attr.startPoint;
        }
        else
        {
            cur_point = attr.startPoint;
            next_point = attr.endPoint;
        }
    }
    // if is last segment of polyline
    else
    {
        cur_point = attr.endPoint;
        next_point = attr.startPoint;
    }

}

// load caps information
void load_caps_line_info(uint offset, uint line_index, uint line_flag, out CapsLineAttr attr)
{
    load_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);
    uint joint_type, lt_type;
    uint logical_width, stipple_index, logical_lt;
    load_line_attributes(line_index, attr.color, attr.width, lt_type, attr.drawZ, attr.glowColor, attr.capsType, joint_type, attr.isLogical);
    load_line_attributes_neutron_sketch(line_index, logical_width, stipple_index, logical_lt);
    load_line_flag(line_flag, attr.flag);

    adjust_line_width_wide_line_neutron_sketch(logical_width, attr.width);

#ifdef ANALYTIC_STIPPLE
    attr.stippleIndex = stipple_index;
#endif

    [branch] if (gRetainMode)
    {
        adjust_line_segment_precision_logical(attr.startPoint, attr.endPoint);
    }
    else
    {
        if (attr.isLogical)
            //not define retained_mod but is logical. such as highlight.
            adjust_line_segment_precision_logical(attr.startPoint, attr.endPoint);
        else
            adjust_line_segment_precision(attr.startPoint, attr.endPoint);
    }
}

// set caps properties to output structure
void set_line_caps_properties(uint vid, bool isEndPoint, CapsLineAttr line_attr, out VertexAttr_MetaWideLine output)
{
    float2 curPoint, nextPoint;
    get_caps_points(line_attr, isEndPoint, curPoint, nextPoint);


    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.subType = line_attr.capsType;

    float2 dir = -normalize(nextPoint - curPoint);

    output.point1 = offset_screen_pos(nextPoint);
    output.point0 = offset_screen_pos(curPoint);

    output.position.xy = get_caps_envelope_pos(vid, line_attr.width,
        output.point0, dir);
    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;
    output.point2 = dir;

    output.shapeType = 0;
    output.point3 = float2(0.0f, 0.0f);
    output.dist = 0;
    output.flag = 0;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// set caps properties to output structure in logical space
void set_logical_line_caps_properties(uint vid, bool isEndPoint, CapsLineAttr line_attr, out VertexAttr_MetaWideLine output)
{
    float2 curPoint, nextPoint;

    float weight_expand = get_line_weight_expand(line_attr.width);
    float2 uv = get_rect_pos(vid);

    get_caps_points(line_attr, isEndPoint, curPoint, nextPoint);

    float2 screen_next_pt = logic_to_screen(nextPoint);
    float2 screen_cur_pt = logic_to_screen(curPoint);
    float2 ndc_cur_pt = screen_to_ndc_pos(screen_cur_pt);

    float2 logic_dir = neutron_sketch_logic_dir(curPoint, nextPoint);
    float  logic_len = length(logic_dir);
    float  xoffset = 2.0f;
    float2 dir;

    [branch] if (gNoAAMode != 0)
    {
        dir = -normalize(screen_next_pt - screen_cur_pt);
    }
    else
    {
        float2 factor = gScreenSize * 0.5f;
        dir = normalize(float2(logic_dir.x * gLCSMatrix[0].x, logic_dir.y * gLCSMatrix[1].y) * factor);
    }

    //check if the line is short enough to degrade to a circle.
    if (logic_len <= 100.0f)
    {
        xoffset = weight_expand * 0.5f;
    }

    float2 extrude = uv.x * float2(dir.y, -dir.x) * gPixelLen * weight_expand * 0.5f
        + (uv.y * 0.5f + 0.5f) * dir * gPixelLen * weight_expand * 0.5f
        + (1.0f - (uv.y * 0.5f + 0.5f)) * (-dir) * gPixelLen * xoffset;

    output.position.xy = ndc_cur_pt + extrude;

    output.point1 = screen_next_pt;
    output.point0 = screen_cur_pt;
    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.subType = line_attr.capsType;
    output.point2 = dir;

    output.shapeType = 0;
    output.point3 = float2(0.0f, 0.0f);
    output.dist = 0;
    output.flag = 0;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

struct JointLineAttr
{
    float2 prevPoint;
    float2 curPoint;
    float2 postPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint jointType;
    uint isLogical;

#ifdef ANALYTIC_STIPPLE
    uint stippleIndex;
#endif
};

// adjust precision for line joint
bool2 adjust_line_joint_precision(inout float2 prev_point, inout float2 cur_point, inout float2 post_point)
{
    bool2 out_range = bool2(false, false);

    // if mid point in guard band, we need to adjust previous point and post point
    if ((abs(cur_point.x) <= SCR_GUARD_BAND_X) &&
        (abs(cur_point.y) <= SCR_GUARD_BAND_Y))
    {
        float2 prev_delta = prev_point - cur_point;
        out_range.x = adjust_point_precision(prev_point, prev_delta);

        float2 post_delta = post_point - cur_point;
        out_range.y = adjust_point_precision(post_point, post_delta);

    }
    return out_range;
}

// adjust precision for line joint in logical space
void adjust_line_joint_precision_logical(inout float2 prev_point, inout float2 cur_point, inout float2 post_point)
{
    float2 prevPoint = prev_point;
    float2 curPoint = cur_point;
    float2 postPoint = post_point;

    float2 s_pre = ndc_to_screen(logic_to_ndc(prev_point));
    float2 s_cur = ndc_to_screen(logic_to_ndc(cur_point));
    float2 s_post = ndc_to_screen(logic_to_ndc(post_point));
    bool2 needAdjust = adjust_line_joint_precision(s_pre, s_cur, s_post);

    // restore to logical space
    if (needAdjust.x)
        prev_point = ndc_to_logic(screen_to_ndc_pos(s_pre));
    else
        prev_point = prevPoint;
    cur_point = curPoint;
    if (needAdjust.y)
        post_point = ndc_to_logic(screen_to_ndc_pos(s_post));
    else
        post_point = postPoint;
}

// load line joint info
void load_joint_line_info(uint offset, uint line_index, uint line_flag, out JointLineAttr attr)
{
    load_joint_line_position(offset, line_flag, attr.flag, attr.prevPoint, attr.curPoint, attr.postPoint);

    uint caps_type, lt_type;
    uint logical_width, stipple_index, logical_lt;
    load_line_attributes(line_index, attr.color, attr.width, lt_type, attr.drawZ, attr.glowColor, caps_type, attr.jointType, attr.isLogical);
    load_line_attributes_neutron_sketch(line_index, logical_width, stipple_index, logical_lt);

    adjust_line_width_wide_line_neutron_sketch(logical_width, attr.width);

#ifdef ANALYTIC_STIPPLE
    attr.stippleIndex = stipple_index;
#endif

    [branch] if (gRetainMode)
    {
        adjust_line_joint_precision_logical(attr.prevPoint, attr.curPoint, attr.postPoint);
    }
    else
    {
        if (attr.isLogical)
            //not define retained_mod but is logical. such as highlight.
            adjust_line_joint_precision_logical(attr.prevPoint, attr.curPoint, attr.postPoint);
        else
            adjust_line_joint_precision(attr.prevPoint, attr.curPoint, attr.postPoint);
    }

}
// TODO: move all envelope to a same position
float2 get_joint_envelope_pos(uint vid, uint width, float2 prev_point, float2 cur_point, float2 post_point, uint joint_type)
{
    float weight_expand = get_line_weight_expand(width);
    float2 uv = get_unit_pos(vid);

    // get dir of previous line and post line
    float2 prev_dir = normalize(prev_point - cur_point);
    float2 post_dir = normalize(post_point - cur_point);

    // get the difference of 2 line dirs
    float2 dir_diff = prev_dir - post_dir;

    float2 ave_dir;

    // get perpendicular dir to previous/post dirs
    float2 prev_perp_dir = float2(prev_dir.y, -prev_dir.x);
    float2 post_perp_dir = float2(post_dir.y, -post_dir.x);

    if (dot(prev_perp_dir, post_dir) > 0.0f)
        prev_perp_dir = -prev_perp_dir;

    if (dot(post_perp_dir, prev_dir) > 0.0f)
        post_perp_dir = -post_perp_dir;

    // if the previous line and post line are overlapped 
    if (dot(dir_diff, dir_diff) < EPS)
    {
        // average dir is the same of negative previous dir
        ave_dir = -prev_dir;
    }
    else
    {
        ave_dir = normalize(prev_perp_dir + post_perp_dir);
    }

    // if is miter joint
    if (joint_type == FLAG_JOINT_MITER)
    {
        // adjust expand range 
        float cos_ang = dot(prev_perp_dir, post_perp_dir);
        float cos_half_ang = sqrt(0.5f + cos_ang * 0.5f);

        // if large than 85 degree, no additional expand
        if (cos_half_ang <= cos(0.5f * (180.0f - MITER_MIN_ANGLE) * PI / 180.0f))
            weight_expand = 0.0f;
        // otherwise increase expand range
        else
        {
            weight_expand = width * 0.5f / cos_half_ang;

        }
    }

    // compute final sreen position.
    float2 base_point = cur_point - ave_dir * 2.0f;
    float2 end_point = cur_point + ave_dir * weight_expand;

    float2 scr_pos = base_point * (1.0f - uv.y) + end_point * uv.y -
        (uv.x * 2.0f - 1.0f) * float2(ave_dir.y, -ave_dir.x) * weight_expand;

    // translate to NDC position
    return screen_to_ndc_pos(scr_pos);
}

// output line joint properties
void set_line_joint_properties(uint vid, JointLineAttr line_attr, out VertexAttr_MetaWideLine output)
{
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.subType = line_attr.jointType;

    output.point0 = offset_screen_pos(line_attr.prevPoint);
    output.point1 = offset_screen_pos(line_attr.curPoint);
    output.point2 = offset_screen_pos(line_attr.postPoint);

    output.position.xy = get_joint_envelope_pos(vid, line_attr.width,
        output.point0, output.point1, output.point2, line_attr.jointType);
    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.point3 = float2(0.0f, 0.0f);
    output.shapeType = 0;
    output.dist = 0;
    output.flag = 0;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// output line joint properties in logical space
void set_logical_line_joint_properties(uint vid, JointLineAttr line_attr, out VertexAttr_MetaWideLine output)
{
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.subType = line_attr.jointType;

    output.point0 = logic_to_screen(line_attr.prevPoint);
    output.point1 = logic_to_screen(line_attr.curPoint);
    output.point2 = logic_to_screen(line_attr.postPoint);

    output.position.xy = get_joint_envelope_pos(vid, line_attr.width,
        output.point0, output.point1, output.point2, line_attr.jointType);
    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.point3 = float2(0.0f, 0.0f);
    output.shapeType = 0;
    output.dist = 0;
    output.flag = 0;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// wide line index texture
Texture2D<uint> gWideLineIndexTex : WideLineIndexTexture;
Texture2D<float> gWideLineDrawOrderZTex : WideLineDrawOrderZTexture;

// wide line input information
struct WideLineAttr
{
    float2 prevPoint;
    float2 startPoint;
    float2 endPoint;
    float2 postPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint isLogical;

#ifdef ANALYTIC_STIPPLE
    uint stippleIndex;
#endif
};

// adjust wide line precision by guard bound clipping
bool4 adjust_wide_line_precision(inout float2 start_point, inout float2 end_point, inout float2 prev_point, inout float2 post_point, inout uint flag)
{
    // adjust precision for start point and end point.
    bool4 all_out_range = bool4(false, false, false, false);
    bool pre_out_range = false;
    bool post_out_range = false;
    bool2 out_range = adjust_line_segment_precision(start_point, end_point);

    // if start point out of range, mark it as no previous line
    if (out_range.x)
    {
        flag &= ~HAS_PREV_LINE;
    }
    // if start point in range and has previous line, adjust previous point.
    else if (flag & HAS_PREV_LINE)
    {
        float2 prev_delta = prev_point - start_point;
        pre_out_range = adjust_point_precision(prev_point, prev_delta);
    }

    // if end point out of range, mark it as no post line
    if (out_range.y)
    {
        flag &= ~HAS_POST_LINE;
    }
    // if end point in range and has point line, adjust post point.
    else if (flag & HAS_POST_LINE)
    {
        float2 post_delta = post_point - end_point;
        post_out_range = adjust_point_precision(post_point, post_delta);
    }
    all_out_range = bool4(out_range, pre_out_range, post_out_range);
    return all_out_range;
}

// adjust line precision for logical space position
void adjust_wide_line_precision_logical(inout float2 start_point, inout float2 end_point, inout float2 prev_point, inout float2 post_point, inout uint flag)
{
    // transform to screen space
    float2 startPoint = start_point;
    float2 endPoint = end_point;
    float2 prevPoint = prev_point;
    float2 postPoint = post_point;

    float2 s_start = ndc_to_screen(logic_to_ndc(start_point));
    float2 s_end = ndc_to_screen(logic_to_ndc(end_point));
    float2 s_prev = ndc_to_screen(logic_to_ndc(prev_point));
    float2 s_post = ndc_to_screen(logic_to_ndc(post_point));
    bool4 needAdjust = adjust_wide_line_precision(s_start, s_end, s_prev, s_post, flag);

    // transform back to logical space
    if (needAdjust.x)
        start_point = ndc_to_logic(screen_to_ndc_pos(s_start));
    else
        start_point = startPoint;
    if (needAdjust.y)
        end_point = ndc_to_logic(screen_to_ndc_pos(s_end));
    else
        end_point = endPoint;
    if (needAdjust.z)
        prev_point = ndc_to_logic(screen_to_ndc_pos(s_prev));
    else
        prev_point = prevPoint;
    if (needAdjust.w)
        post_point = ndc_to_logic(screen_to_ndc_pos(s_post));
    else
        post_point = postPoint;
}

// load wide line input information
void load_wide_line_info(uint offset, uint line_index, uint line_flag, out WideLineAttr attr)
{
    load_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);

    uint caps_type, joint_type, lt_type;
    uint logical_width, stipple_index, logical_lt;
    load_line_attributes(line_index, attr.color, attr.width, lt_type, attr.drawZ, attr.glowColor, caps_type, joint_type, attr.isLogical);
    load_line_attributes_neutron_sketch(line_index, logical_width, stipple_index, logical_lt);
    load_line_adj_info(offset, line_flag, attr.startPoint, attr.flag, attr.prevPoint, attr.postPoint);

    adjust_line_width_wide_line_neutron_sketch(logical_width, attr.width);

#ifdef ANALYTIC_STIPPLE
    attr.stippleIndex = stipple_index;
#endif

    [branch] if (gRetainMode)
    {
        adjust_wide_line_precision_logical(attr.startPoint, attr.endPoint, attr.prevPoint, attr.postPoint, attr.flag);
    }
    else
    {
        if (attr.isLogical)
            //not define retained_mod but is logical. such as highlight.
            adjust_wide_line_precision_logical(attr.startPoint, attr.endPoint, attr.prevPoint, attr.postPoint, attr.flag);
        else
            adjust_wide_line_precision(attr.startPoint, attr.endPoint, attr.prevPoint, attr.postPoint, attr.flag);
    }
}

// set vertex output information for wide line
void set_wide_line_properties(uint vid, WideLineAttr line_attr,
    out VertexAttr_MetaWideLine output)
{
    float temp_dist;
    output.position.xy = get_line_envelope_pos(vid, line_attr.width,
        line_attr.startPoint, line_attr.endPoint, temp_dist);
    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.dist = temp_dist;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.flag = line_attr.flag;
    output.width = line_attr.width;

    output.point0 = offset_screen_pos(line_attr.prevPoint);
    output.point1 = offset_screen_pos(line_attr.startPoint);
    output.point2 = offset_screen_pos(line_attr.endPoint);
    output.point3 = offset_screen_pos(line_attr.postPoint);

    output.shapeType = 0;
    output.subType = 0;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}
// set vertex output information for wide line in logical space
void set_logical_wide_line_properties(uint vid, WideLineAttr line_attr,
    out VertexAttr_MetaWideLine output)
{
    float temp_dist;

    float2 screen_prev = logic_to_screen(line_attr.prevPoint);
    float2 screen_start = logic_to_screen(line_attr.startPoint);
    float2 screen_end = logic_to_screen(line_attr.endPoint);
    float2 screen_post = logic_to_screen(line_attr.postPoint);

    output.position.xy = get_logical_wide_line_envelope_pos(vid, line_attr.flag, line_attr.width,
        screen_start, screen_end, temp_dist);

    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.dist = temp_dist;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.flag = line_attr.flag;
    output.width = line_attr.width;

    output.point0 = screen_prev;
    output.point1 = screen_start;
    output.point2 = screen_end;
    output.point3 = screen_post;

    output.shapeType = 0;
    output.subType = 0;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

VertexAttr_MetaWideLine  WideLine_VS(NullVertex_Input input)
{
    bool isEndPoint = false;
    uint shape_type = 0;
    LineVertex_Input vs_input = (LineVertex_Input)0;

    load_wide_line_input(input.VertexID, input.InstanceID, gWideLineIndexTex, vs_input, shape_type, isEndPoint);

    VertexAttr_MetaWideLine output = (VertexAttr_MetaWideLine)0;
    if (shape_type == SHAPE_BODY)
    {
        WideLineAttr line_attr = (WideLineAttr)0;
        load_wide_line_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), get_prim_flag(vs_input.PrimID.y), line_attr);

        [branch] if (gRetainMode)
            load_dynamic_draworderz(input.InstanceID, gWideLineDrawOrderZTex, line_attr.drawZ);

        if (line_attr.isLogical)
            set_logical_wide_line_properties(vs_input.VertexID, line_attr, output);
        else
            set_wide_line_properties(vs_input.VertexID, line_attr, output);

        output.shapeType = shape_type;
    }
    else if (shape_type == SHAPE_CAPS)
    {
        CapsLineAttr line_attr = (CapsLineAttr)0;
        load_caps_line_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), get_prim_flag(vs_input.PrimID.y), line_attr);

        [branch] if (gRetainMode)
            load_dynamic_draworderz(input.InstanceID, gWideLineDrawOrderZTex, line_attr.drawZ);

        if (line_attr.isLogical)
            set_logical_line_caps_properties(vs_input.VertexID, isEndPoint, line_attr, output);
        else
            set_line_caps_properties(vs_input.VertexID, isEndPoint, line_attr, output);

        output.shapeType = shape_type;

    }
    else if (shape_type == SHAPE_JOINT)
    {
        JointLineAttr line_attr = (JointLineAttr)0;
        load_joint_line_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), get_prim_flag(vs_input.PrimID.y), line_attr);

        [branch] if (gRetainMode)
            load_dynamic_draworderz(input.InstanceID, gWideLineDrawOrderZTex, line_attr.drawZ);

        if (line_attr.isLogical)
            set_logical_line_joint_properties(vs_input.VertexID, line_attr, output);
        else
            set_line_joint_properties(vs_input.VertexID, line_attr, output);

        output.shapeType = shape_type;

    }

    return output;
}

//check overlap case with previous line
void check_overlap_with_post_line(VertexAttr_MetaWideLine input, float2 pixelPos, float dist_to_end, float2 line_dir)
{
    float2 startPoint = input.point1;
    float2 endPoint = input.point2;
    float2 prevPoint = input.point0;
    float2 postPoint = input.point3;

    if (input.flag & HAS_POST_LINE)
    {
        float2 post_dir = normalize(postPoint - endPoint);
        if (inLineRegion(pixelPos, endPoint, postPoint, input.width + 2.0f, post_dir))
        {
            float2 cur_dir = -line_dir;

            float2 dir_diff = post_dir - cur_dir;

            if ((abs(dir_diff.x) < EPS) && (abs(dir_diff.y) < EPS)) // same dir, always display previous line
                discard;


            bool border_pixel = (dist_to_end < EPS);

            float2 vec_to_end = (pixelPos - endPoint);
            float post_dist = abs(dot(vec_to_end, post_dir));
            float cur_dist = abs(dot(vec_to_end, cur_dir));

            if ((post_dist < EPS) && (cur_dist < EPS) && border_pixel) // case1: end point pixel - display previous line
                discard;

            if (abs(post_dist - cur_dist) < EPS) // case2: same distance - display previous line
                discard;

            if (post_dist >= cur_dist) // case3: display line with brighter pixel
                discard;

        }
    }
}
// check overlap case with post line
void check_overlap_with_prev_line(VertexAttr_MetaWideLine input, float2 pixelPos, float dist_to_start, float2 line_dir)
{
    float2 startPoint = input.point1;
    float2 endPoint = input.point2;
    float2 prevPoint = input.point0;
    float2 postPoint = input.point3;

    if (input.flag & HAS_PREV_LINE)
    {
        float2 prev_dir = normalize(prevPoint - startPoint);
        if (inLineRegion(pixelPos, prevPoint, startPoint, input.width + 2.0f, -prev_dir))
        {
            float2 cur_dir = line_dir;

            float2 dir_diff = prev_dir - cur_dir;


            bool border_pixel = (dist_to_start < EPS);

            float2 vec_to_start = pixelPos - startPoint;
            float prev_dist = abs(dot(vec_to_start, prev_dir));
            float cur_dist = abs(dot(vec_to_start, cur_dir));

            bool same_dir = ((abs(dir_diff.x) < EPS) && (abs(dir_diff.y) < EPS));
            bool start_pixel = ((prev_dist < EPS) && (cur_dist < EPS) && border_pixel);
            bool same_dist = (abs(prev_dist - cur_dist) <= EPS);



            if ((!same_dir) && (!start_pixel) && (!same_dist))
            {
                if (prev_dist > cur_dist)
                    discard;
            }


        }
    }
}

// wide line body pixel shader
OIT_PS_HEADER(WideLine_PS, VertexAttr_MetaWideLine)
{
    float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);

    if (input.shapeType == SHAPE_BODY)
    {
        float2 startPoint = input.point1;
        float2 endPoint = input.point2;

        float2 pixelPos = input.position.xy;
        pixelPos.y = gScreenSize.y - pixelPos.y;

        float width = adjust_line_width_wide_line(input.width);

        float dist = 0.0f;

        float2 line_dir = normalize(endPoint - startPoint);

        // check if current pixel in line region.
        if (!inLineRegion(pixelPos, startPoint, endPoint, input.width + 2.0f, line_dir))
            discard;

        // get distance from pixel to line, and 
        dist = abs_dist_pixel_to_line(pixelPos,
            normalize(startPoint - endPoint), startPoint);

        // get distance from pixel to start/end points
        float dist_to_start = length(pixelPos - startPoint);
        float dist_to_end = length(pixelPos - endPoint);

        check_overlap_with_post_line(input, pixelPos, dist_to_end, line_dir);
        check_overlap_with_prev_line(input, pixelPos, dist_to_start, line_dir);

        // get wide line anti-aliasing color
        [branch] if (gNoAAMode != 0)
        {
#ifdef ANALYTIC_HIGHLIGHT
            float3 lineParams;
            lineParams.x = startPoint.y - endPoint.y;
            lineParams.y = endPoint.x - startPoint.x;
            lineParams.z = startPoint.x * endPoint.y - endPoint.x * startPoint.y;

            bool in_sharp = (width > 1) || in_line_sharp(lineParams, pixelPos);
            color = compute_highlight_sharp_color(dist, width, input.color, input.glowColor, in_sharp);
#else
            color = compute_final_color_sharp(dist, width, input.color, input.glowColor);
#endif
        }
        else
        {
#ifdef ANALYTIC_STIPPLE
            color = compute_final_color_stipple(dist, width, input.color, input.glowColor, pixelPos, input.stippleIndex);
#else
            color = compute_final_color(dist, width, input.color, input.glowColor);
#endif
        }
    }
    else if (input.shapeType == SHAPE_CAPS)
    {
        float2 center = input.point0;
        float2 endPoint = input.point1;
        float2 dir = input.point2;

        // get pixel position
        float2 pixel_pos = input.position.xy;
        pixel_pos.y = gScreenSize.y - pixel_pos.y;

        // compute distance to caps center
        float dist = length(pixel_pos - center);

        // get line width
        float width = adjust_line_width_wide_line(input.width);

        // if in line body region, discard
        if (inLineRegion(pixel_pos, center, endPoint, input.width + 2.0f, -dir))
            discard;

        // if zoom too small and the pixel is out of line and in another side of line-body, discard
        if (over_middle_point(pixel_pos, center, endPoint, dir))
            discard;

        [branch] if (gNoAAMode != 0)
        {
            color = compute_sharp_caps_final_color(dist, width, input.color, input.glowColor,
                pixel_pos, center, dir, input.subType);
        }
        else
        {
#ifdef ANALYTIC_STIPPLE
            color = compute_caps_final_color_stipple(dist, width, input.color, input.glowColor,
                pixel_pos, center, dir, input.subType, input.stippleIndex);
#else
            color = compute_caps_final_color(dist, width, input.color, input.glowColor,
                pixel_pos, center, dir, input.subType);
#endif
        }
    }

    else if (input.shapeType == SHAPE_JOINT)
    {
        float2 prevPoint = input.point0;
        float2 curPoint = input.point1;
        float2 postPoint = input.point2;

        // get screen position
        float2 pixel_pos = input.position.xy;
        pixel_pos.y = gScreenSize.y - pixel_pos.y;

        // get line dir of previous and post line.
        float2 prev_dir = normalize(curPoint - prevPoint);
        float2 pos_dir = normalize(curPoint - postPoint);

        // discard pixels in previous and post line body.
        if (inLineRegion(pixel_pos, prevPoint, curPoint, input.width + 1.0f, prev_dir))
            discard;

        if (inLineRegion(pixel_pos, curPoint, postPoint, input.width + 1.0f, -pos_dir))
            discard;

        // discard pixels out of previous and post lines, and in another side of line bodies.
        if (over_middle_point(pixel_pos, curPoint, prevPoint, prev_dir))
            discard;

        if (over_middle_point(pixel_pos, curPoint, postPoint, pos_dir))
            discard;


        // get lendth to joint point
        float dist = length(pixel_pos - curPoint);

        // get line weight
        float width = adjust_line_width_wide_line(input.width);


        [branch] if (gNoAAMode != 0)
        {
            // get joint color
            color = compute_sharp_joint_final_color(dist, width, input.color, input.glowColor,
                pixel_pos, prevPoint, curPoint, postPoint, input.subType);
        }
        else
        {
            // get joint color
#ifdef ANALYTIC_STIPPLE
            color = compute_joint_final_color_stipple(dist, width, input.color, input.glowColor,
                pixel_pos, prevPoint, curPoint, postPoint, input.subType, input.stippleIndex);
#else
            color = compute_joint_final_color(dist, width, input.color, input.glowColor,
                pixel_pos, prevPoint, curPoint, postPoint, input.subType);
#endif
        }
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Line_WideAA
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, WideLine_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, WideLine_PS()));
    }
}

