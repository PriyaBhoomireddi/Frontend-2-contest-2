#include "Sketch_lt_wide_line10.fxh"

// line type index texture
Texture2D<uint> gWideLineTypeIndexTex: WideLineTypeIndexTexture;

// line type draw order z texture for retain mode
Texture2D<float> gWideLineTypeDrawOrderZTex : WideLineTypeDrawOrderZTexture;

// output wide line properties in logical space
void set_logical_meta_wide_line_type_properties(uint vid, WideLineTypeAttr line_attr,
    out VertexAttr_MetaWideLineType output)
{
    float temp_dist;
    float2 screen_prev = logic_to_screen(line_attr.prevPoint);
    float2 screen_start = logic_to_screen(line_attr.startPoint);
    float2 screen_end = logic_to_screen(line_attr.endPoint);
    float2 screen_post = logic_to_screen(line_attr.postPoint);
    output.position.xy = get_logical_wide_line_envelope_pos(vid, line_attr.flag, line_attr.width,
        screen_start, screen_end, temp_dist);
    output.position.z = line_attr.drawZ;
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

    output.lineParams.x = screen_start.y - screen_end.y;
    output.lineParams.y = screen_end.x - screen_start.x;
    output.lineParams.z = screen_start.x * screen_end.y - screen_end.x * screen_start.y;
    output.lineParams.w = 0.0f;

    // length on line
    set_line_pattern_dist(vid, output.point1, output.point2,
        output.dist.y, output.dist.z);
    output.dist.w = 0.0f; // reserved

    output.patternIndex = line_attr.patternIndex;
    output.capsType = line_attr.capsType;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);

    output.shapeType = 0;
    output.jointType = 0;
    output.reversed = false;
    output.patternProp_Post = float4(0.0f, 0.0f, 0.0f, 0.0f);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// output wide line properties.
void set_meta_wide_line_type_properties(uint vid, WideLineTypeAttr line_attr,
    out VertexAttr_MetaWideLineType output)
{
    float temp_dist;
    output.position.xy = get_line_envelope_pos(vid, line_attr.width,
        line_attr.startPoint, line_attr.endPoint, temp_dist);
    output.position.z = line_attr.drawZ;
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

    output.lineParams.x = output.point1.y - output.point2.y;
    output.lineParams.y = output.point2.x - output.point1.x;
    output.lineParams.z = output.point1.x * output.point2.y - output.point2.x * output.point1.y;
    output.lineParams.w = 0.0f;

    // length on line
    set_line_pattern_dist(vid, line_attr.startPoint, line_attr.endPoint,
        output.dist.y, output.dist.z);
    output.dist.w = 0.0f; // reserved

    output.patternIndex = line_attr.patternIndex;
    output.capsType = line_attr.capsType;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);


    output.shapeType = 0;
    output.jointType = 0;
    output.reversed = false;
    output.patternProp_Post = float4(0.0f, 0.0f, 0.0f, 0.0f);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

VertexAttr_MetaWideLineType outputMetaWideLineType_VS(uint vid, WideLineTypeAttr line_attr)
{
    VertexAttr_MetaWideLineType output = (VertexAttr_MetaWideLineType)0;
    if (line_attr.isLogical)
        set_logical_meta_wide_line_type_properties(vid, line_attr, output);
    else
        set_meta_wide_line_type_properties(vid, line_attr, output);

    output.shapeType = SHAPE_BODY;

    return output;
}

// load line type caps information
void load_caps_line_type_info(uint offset, uint line_index, uint seg_index, uint line_flag, out CapsLineTypeAttr attr)
{
    load_line_position(get_pos_id(offset), attr.startPoint, attr.endPoint);
    uint joint_type;
    uint logical_width, stipple_index, logical_lt;
    load_line_attributes(line_index, attr.color, attr.width, attr.patternIndex, attr.drawZ, attr.glowColor, attr.capsType, joint_type, attr.isLogical);
    load_line_attributes_neutron_sketch(line_index, logical_width, stipple_index, logical_lt);
    load_line_flag(line_flag, attr.flag);
    load_line_type(seg_index, attr.isLogical & logical_lt, attr.startSkipLen, attr.endSkipLen, attr.patternOffset, attr.patternScale);

    adjust_line_width_wide_line_neutron_sketch(logical_width, attr.width);

#ifdef ANALYTIC_STIPPLE
    attr.stippleIndex = stipple_index;
#endif
}


// output line type caps properties in logical space
void set_logical_meta_line_type_caps_properties(uint vid, bool isEndPoint, CapsLineTypeAttr line_attr, out VertexAttr_MetaWideLineType output)
{
    float2 curPoint, nextPoint;
    bool reversed;

    float weight_expand = get_line_weight_expand(line_attr.width);
    float2 uv = get_rect_pos(vid);

    get_line_type_caps_points(line_attr, isEndPoint, curPoint, nextPoint, reversed);

    float2  screen_next_pt = logic_to_screen(nextPoint);
    float2  screen_cur_pt = logic_to_screen(curPoint);
    float2 ndc_cur_pt = screen_to_ndc_pos(screen_cur_pt);
    float2 dir = -normalize(screen_next_pt - screen_cur_pt);
    int2 cur_pixel = int2(screen_cur_pt);
    int2 next_pixel = int2(screen_next_pt);
    float  xoffset = 2.0f;

    // if the current point and next point is near enough it will have precision issue when
    // calculate the direction. Here set (1.0f, 0.0f) as its direction.
    if (cur_pixel.x == next_pixel.x && cur_pixel.y == next_pixel.y)
    {
        dir = float2(1.0f, 0.0f);
        screen_cur_pt = offset_screen_pos(cur_pixel);
        screen_next_pt = screen_cur_pt - dir * 0.1f;
        weight_expand = 0.0f;
        xoffset = 0.0f;
    }

    float2 extrude = uv.x * float2(dir.y, -dir.x) * gPixelLen * weight_expand * 0.5f
        + (uv.y * 0.5f + 0.5f) * dir * gPixelLen * weight_expand * 0.5f
        + (1.0f - (uv.y * 0.5f + 0.5f)) * (-dir) * gPixelLen * xoffset;

    output.position.xy = ndc_cur_pt + extrude;
    output.point1 = screen_next_pt;
    output.point0 = screen_cur_pt;
    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;

    output.flag = line_attr.flag;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.capsType = line_attr.capsType;
    output.reversed = reversed;

    output.patternIndex = line_attr.patternIndex;

    output.patternProp = float4(line_attr.startSkipLen, line_attr.endSkipLen,
        line_attr.patternOffset, line_attr.patternScale);

    output.point2 = float2(0.0f, 0.0f);
    output.point3 = float2(0.0f, 0.0f);
    output.shapeType = 0;
    output.jointType = 0;
    output.patternProp_Post = float4(0.0f, 0.0f, 0.0f, 0.0f);
    output.lineParams = float4(0.0f, 0.0f, 0.0f, 0.0f);
    output.dist = float4(0.0f, 0.0f, 0.0f, 0.0f);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}


// output line type caps properties
void set_meta_line_type_caps_properties(uint vid, bool isEndPoint, CapsLineTypeAttr line_attr, out VertexAttr_MetaWideLineType output)
{
    float2 curPoint, nextPoint;
    bool reversed;
    get_line_type_caps_points(line_attr, isEndPoint, curPoint, nextPoint, reversed);

    output.flag = line_attr.flag;
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;
    output.capsType = line_attr.capsType;
    output.reversed = reversed;

    float2 dir = -normalize(nextPoint - curPoint);

    output.point1 = offset_screen_pos(nextPoint);
    output.point0 = offset_screen_pos(curPoint);

    output.position.xy = get_caps_envelope_pos(vid, line_attr.width,
        output.point0, dir);
    output.position.z = line_attr.drawZ;
    output.position.w = 1.0f;

    output.patternIndex = line_attr.patternIndex;

    output.patternProp.x = line_attr.startSkipLen;
    output.patternProp.y = line_attr.endSkipLen;
    output.patternProp.z = line_attr.patternOffset;
    output.patternProp.w = line_attr.patternScale;

    output.point2 = float2(0.0f, 0.0f);
    output.point3 = float2(0.0f, 0.0f);
    output.shapeType = 0;
    output.jointType = 0;
    output.patternProp_Post = float4(0.0f, 0.0f, 0.0f, 0.0f);
    output.lineParams = float4(0.0f, 0.0f, 0.0f, 0.0f);
    output.dist = float4(0.0f, 0.0f, 0.0f, 0.0f);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// line type joint attributes
struct JointLineTypeAttr
{
    float2 prevPoint;
    float2 curPoint;
    float2 postPoint;

    uint flag;
    uint color;
    uint width;
    float drawZ;
    uint glowColor;
    uint isLogical;

    uint capsType;
    uint jointType;

    uint  patternIndex;

    float startSkipLen_prev;
    float endSkipLen_prev;
    float patternOffset_prev;
    float patternScale_prev;

    float startSkipLen_post;
    float endSkipLen_post;
    float patternOffset_post;
    float patternScale_post;

#ifdef ANALYTIC_STIPPLE
    uint stippleIndex;
#endif
};

// load line type info
void load_joint_line_type_info(uint offset, uint line_index, uint seg_index, uint line_flag, out JointLineTypeAttr attr)
{
    load_joint_line_position(offset, line_flag, attr.flag, attr.prevPoint, attr.curPoint, attr.postPoint);
    uint logical_width, stipple_index, logical_lt;
    load_line_attributes(line_index, attr.color, attr.width, attr.patternIndex, attr.drawZ, attr.glowColor, attr.capsType, attr.jointType, attr.isLogical);
    load_line_attributes_neutron_sketch(line_index, logical_width, stipple_index, logical_lt);

    load_line_type(seg_index, attr.isLogical & logical_lt, attr.startSkipLen_post, attr.endSkipLen_post, attr.patternOffset_post, attr.patternScale_post);
    load_line_type(get_prev_seg_index(seg_index, line_flag, offset), attr.isLogical & logical_lt, attr.startSkipLen_prev, attr.endSkipLen_prev, attr.patternOffset_prev, attr.patternScale_prev);

    adjust_line_width_wide_line_neutron_sketch(logical_width, attr.width);

#ifdef ANALYTIC_STIPPLE
    attr.stippleIndex = stipple_index;
#endif
}

//TODO: move all envelpe pos function together.
float2 get_line_type_joint_envelope_pos(uint vid, uint width, float2 prev_point, float2 cur_point, float2 post_point)
{
    float weight_expand = get_line_weight_expand(width);
    float2 uv = get_rect_pos(vid);

    float2 prev_dir = normalize(prev_point - cur_point);
    float2 post_dir = normalize(post_point - cur_point);

    float2 middle_dir = -normalize(prev_dir + post_dir);

    float2 prev_pend_dir = float2(prev_dir.y, -prev_dir.x);
    float2 post_pend_dir = float2(post_dir.y, -post_dir.x);

    if (dot(prev_pend_dir, middle_dir) < 0)
        prev_pend_dir = -prev_pend_dir;

    if (dot(post_pend_dir, middle_dir) < 0)
        post_pend_dir = -post_pend_dir;

    float cos_angle = dot(prev_pend_dir, middle_dir);
    float sin_angle = sqrt(1 - cos_angle * cos_angle);

    float2 scr_pos;

    if (cos_angle < 0.1f)
    {
        scr_pos = cur_point + uv.x * weight_expand * prev_pend_dir * 1.5f +
            uv.y * weight_expand * middle_dir * 1.5f;
    }
    else if (sin_angle < 0.1f)
    {
        scr_pos = cur_point + uv.x * weight_expand * float2(middle_dir.y, -middle_dir.x) * 1.5f +
            uv.y * weight_expand * middle_dir * 1.5f;

    }
    else
    {
        float dist = weight_expand / 2.0f / cos_angle;


        if (vid == 0)
            scr_pos = cur_point - dist * middle_dir * 1.5f;
        else if (vid == 1)
            scr_pos = cur_point - dist * float2(middle_dir.y, -middle_dir.x) * 1.5f;
        else if (vid == 2)
            scr_pos = cur_point + dist * float2(middle_dir.y, -middle_dir.x) * 1.5f;
        else
            scr_pos = cur_point + dist * middle_dir * 1.5f;
    }

    return screen_to_ndc_pos(scr_pos);
}

// TODO: move all envelope pos together
float2 get_logical_line_type_joint_envelope_pos(uint vid, uint width, float2 cur_point)
{
    float weight_expand = get_line_weight_expand(width);
    float2 uv = get_rect_pos(vid);

    float2 scr_pos = cur_point + uv.x * float2(1.0f, 0.0f) * weight_expand * 1.5f * 0.5f * gPixelLen +
        uv.y * float2(0.0f, 1.0f) * weight_expand * 1.5f * 0.5f * gPixelLen;

    return scr_pos;
}

// output line-type joint properties in local space
void set_logical_meta_line_type_joint_properties(uint vid, JointLineTypeAttr line_attr, out VertexAttr_MetaWideLineType output)
{
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;

    output.patternIndex = line_attr.patternIndex;
    output.capsType = line_attr.capsType;
    output.jointType = line_attr.jointType;

    output.point0 = logic_to_screen(line_attr.prevPoint);
    output.point1 = logic_to_screen(line_attr.curPoint);
    output.point2 = logic_to_screen(line_attr.postPoint);
    float2 ndc_cur_point = screen_to_ndc_pos(output.point1);

    output.position.xy = get_logical_line_type_joint_envelope_pos(vid, line_attr.width, ndc_cur_point);

    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.patternProp.x = line_attr.startSkipLen_prev;
    output.patternProp.y = line_attr.endSkipLen_prev;
    output.patternProp.z = line_attr.patternOffset_prev;
    output.patternProp.w = line_attr.patternScale_prev;

    output.patternProp_Post.x = line_attr.startSkipLen_post;
    output.patternProp_Post.y = line_attr.endSkipLen_post;
    output.patternProp_Post.z = line_attr.patternOffset_post;
    output.patternProp_Post.w = line_attr.patternScale_post;


    output.flag = 0;
    output.reversed = false;
    output.point3 = float2(0.0f, 0.0f);
    output.shapeType = 0;
    output.lineParams = float4(0.0f, 0.0f, 0.0f, 0.0f);
    output.dist = float4(0.0f, 0.0f, 0.0f, 0.0f);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}

// output line-type joint properties
void set_meta_line_type_joint_properties(uint vid, JointLineTypeAttr line_attr, out VertexAttr_MetaWideLineType output)
{
    output.color = line_attr.color;
    output.glowColor = line_attr.glowColor;
    output.width = line_attr.width;

    output.patternIndex = line_attr.patternIndex;
    output.capsType = line_attr.capsType;
    output.jointType = line_attr.jointType;

    output.point0 = offset_screen_pos(line_attr.prevPoint);
    output.point1 = offset_screen_pos(line_attr.curPoint);
    output.point2 = offset_screen_pos(line_attr.postPoint);

    output.position.xy = get_line_type_joint_envelope_pos(vid, line_attr.width,
        output.point0, output.point1, output.point2);

    output.position.z = line_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.patternProp.x = line_attr.startSkipLen_prev;
    output.patternProp.y = line_attr.endSkipLen_prev;
    output.patternProp.z = line_attr.patternOffset_prev;
    output.patternProp.w = line_attr.patternScale_prev;

    output.patternProp_Post.x = line_attr.startSkipLen_post;
    output.patternProp_Post.y = line_attr.endSkipLen_post;
    output.patternProp_Post.z = line_attr.patternOffset_post;
    output.patternProp_Post.w = line_attr.patternScale_post;

    output.flag = 0;
    output.reversed = false;
    output.point3 = float2(0.0f, 0.0f);
    output.shapeType = 0;
    output.lineParams = float4(0.0f, 0.0f, 0.0f, 0.0f);
    output.dist = float4(0.0f, 0.0f, 0.0f, 0.0f);

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = line_attr.stippleIndex;
#endif
}


// wide line type pixel shader
VertexAttr_MetaWideLineType WideLineType_VS(NullVertex_Input input)
{
    bool isEndPoint = false;
    uint shape_type = 0;
    LineVertex_Input vs_input = (LineVertex_Input)0;

    VertexAttr_MetaWideLineType output = (VertexAttr_MetaWideLineType)0;

    load_wide_line_input(input.VertexID, input.InstanceID, gWideLineTypeIndexTex, vs_input, shape_type, isEndPoint);

    if (shape_type == SHAPE_BODY)
    {

        WideLineTypeAttr line_attr = (WideLineTypeAttr)0;
        load_wide_line_type_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), vs_input.SegmentID, get_prim_flag(vs_input.PrimID.y), line_attr);

        [branch] if (gRetainMode)
            load_dynamic_draworderz(input.InstanceID, gWideLineTypeDrawOrderZTex, line_attr.drawZ);

        output = outputMetaWideLineType_VS(vs_input.VertexID, line_attr);
    }
    else if (shape_type == SHAPE_CAPS)
    {

        CapsLineTypeAttr line_attr = (CapsLineTypeAttr)0;
        load_caps_line_type_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), vs_input.SegmentID, get_prim_flag(vs_input.PrimID.y), line_attr);

        [branch] if (gRetainMode)
            load_dynamic_draworderz(input.InstanceID, gWideLineTypeDrawOrderZTex, line_attr.drawZ);

        if (line_attr.isLogical)
            set_logical_meta_line_type_caps_properties(vs_input.VertexID, isEndPoint, line_attr, output);
        else
            set_meta_line_type_caps_properties(vs_input.VertexID, isEndPoint, line_attr, output);

        output.shapeType = SHAPE_CAPS;
    }
    else if (shape_type == SHAPE_JOINT)
    {

        JointLineTypeAttr line_attr = (JointLineTypeAttr)0;
        load_joint_line_type_info(vs_input.PrimID.x, get_prim_id(vs_input.PrimID.y), vs_input.SegmentID, get_prim_flag(vs_input.PrimID.y), line_attr);

        [branch] if (gRetainMode)
            load_dynamic_draworderz(input.InstanceID, gWideLineTypeDrawOrderZTex, line_attr.drawZ);


        if (line_attr.isLogical)
            set_logical_meta_line_type_joint_properties(vs_input.VertexID, line_attr, output);
        else
            set_meta_line_type_joint_properties(vs_input.VertexID, line_attr, output);

        output.shapeType = SHAPE_JOINT;
    }

    return output;
}

OIT_PS_HEADER(WideLineType_PS, VertexAttr_MetaWideLineType)
{
    float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    if (input.shapeType == SHAPE_BODY)
    {

        float2 startPoint = input.point1;
        float2 endPoint = input.point2;

        // get distance to line
        float dist = abs(input.dist.x);

        // get screen pos
        float2 pixelPos = input.position.xy;
        pixelPos.y = gScreenSize.y - pixelPos.y;

        // get line direction
        float2 line_dir = normalize(endPoint - startPoint);

        // discard pixels out of line region
        if (!inLineRegion(pixelPos, startPoint, endPoint, input.width + 4.0f, line_dir))
            discard;

        // compute distance to start and end point
        float start_dist = abs(dot(pixelPos - startPoint, line_dir));
        float end_dist = abs(dot(pixelPos - endPoint, -line_dir));

        // check wide line type shapes: is dash, space or dot
        WideLinePatternResult left_attr;
        WideLinePatternResult right_attr;

        WideLinePatternAttr attr;
        attr.dist = dist;
        attr.width = input.width;
        attr.startDist = start_dist;
        attr.endDist = end_dist;
        attr.startSkipLen = input.patternProp.x;
        attr.endSkipLen = input.patternProp.y;
        attr.patternScale = input.patternProp.z;
        attr.patternOffset = input.patternProp.w;
        attr.patternIndex = input.patternIndex;

        WideLineInfo info;
        info.startPos = startPoint;
        info.endPos = endPoint;
        info.lineDir = line_dir;
        info.hasPrevLine = (input.flag & HAS_PREV_LINE) != 0;
        info.hasPostLine = (input.flag & HAS_POST_LINE) != 0;

        int res = check_wide_line_pattern(
            attr,
            info,
            left_attr,
            right_attr);

        // discard pixel when on space
        if (res == PURE_SPACE)
            discard;

        color = getWLColorFromLTAttr_Meta(input, left_attr, right_attr, res);
    }
    else if (input.shapeType == SHAPE_CAPS)
    {

        float2 center = input.point0;
        float2 endPoint = input.point1;

        // get screen position
        float2 pixelPos = input.position.xy;
        pixelPos.y = gScreenSize.y - pixelPos.y;

        // get line direction
        float2 dir = normalize(center - endPoint);

        // discard the point if it is in the line region.
        if (inLineRegion(pixelPos, center, endPoint, input.width + 2.0f, -dir))
            discard;

        // discard the point if it is over middle point.
        if (over_middle_point(pixelPos, center, endPoint, dir))
            discard;

        // get distances and line width
        float dist_to_center = length(pixelPos - center);
        float width = adjust_line_width_wide_line(input.width);
        float dist_to_line = abs_dist_pixel_to_line(pixelPos, dir, endPoint);

        color = float4(0.0f, 0.0f, 0.0f, 0.0f);

        // get pure dot flag
        bool is_pure_dot = (input.patternIndex & PURE_DOT_MASK) != 0;

        // get plinegen flag
        bool is_plinegen;
        if (input.reversed)
        {
            is_plinegen = is_pline_gen(input.patternProp.y);
        }
        else
        {
            is_plinegen = is_pline_gen(input.patternProp.x);
        }

        // if it is not plinegen and first/last dash length are not zero, then draw cap directly.
        if ((!is_plinegen) && (input.patternProp.x != 0.0f) && (input.patternProp.y != 0.0f))
        {
            [branch] if (gNoAAMode != 0)
            {
                color = compute_sharp_caps_final_color(dist_to_center, width, input.color, input.glowColor,
                    pixelPos, center, dir, input.capsType);
            }
            else
            {
#ifdef ANALYTIC_STIPPLE
                color = compute_caps_final_color_stipple(dist_to_center, width, input.color, input.glowColor,
                    pixelPos, center, dir, input.capsType, input.stippleIndex);
#else
                color = compute_caps_final_color(dist_to_center, width, input.color, input.glowColor,
                    pixelPos, center, dir, input.capsType);
#endif
            }
        }
        else
        {
            // check if need to draw caps

            // get start and end points   
            float2 start, end;
            if (input.reversed)
            {
                start = endPoint;
                end = center;
            }
            else
            {
                start = center;
                end = endPoint;
            }

            // check the line pattern of start or end point.
            // if current point is near the start point, then check the start point's line pattern.
            // if current point is near the end point, then check the end point's line pattern.
            WideLinePatternAttr attr;
            attr.dist = 0;
            attr.width = input.width;
            attr.startDist = length(center - start);
            attr.endDist = length(end - center);
            attr.startSkipLen = input.patternProp.x;
            attr.endSkipLen = input.patternProp.y;
            attr.patternScale = input.patternProp.z;
            attr.patternOffset = input.patternProp.w;
            attr.patternIndex = input.patternIndex;

            WideLineInfo info;
            info.startPos = start;
            info.endPos = end;
            info.lineDir = normalize(end - start);
            info.hasPrevLine = (input.flag & HAS_PREV_LINE) != 0;
            info.hasPostLine = (input.flag & HAS_POST_LINE) != 0;

            WideLinePatternResult left_attr;
            WideLinePatternResult right_attr;


            int res = check_wide_line_pattern(
                attr,
                info,
                left_attr,
                right_attr);

            // if the start(end) point is in pure space, discard current point directly.
            if (res == PURE_SPACE)
                discard;

            // if the start(end) point is in dash, draw the cap directly.
            if (res == PURE_DASH)
            {
                [branch] if (gNoAAMode != 0)
                {
                    color = compute_sharp_caps_final_color(dist_to_center, width, input.color, input.glowColor,
                        pixelPos, center, dir, input.capsType);
                }
                else
                {
#ifdef ANALYTIC_STIPPLE
                    color = compute_caps_final_color_stipple(dist_to_center, width, input.color, input.glowColor,
                        pixelPos, center, dir, input.capsType, input.stippleIndex);
#else
                    color = compute_caps_final_color(dist_to_center, width, input.color, input.glowColor,
                        pixelPos, center, dir, input.capsType);
#endif
                }
            }
            else
            {
                // if start(end) point is in MIXED, which means it is in space, but it is in a cap or a dot region.
#ifdef ANALYTIC_STIPPLE
                float4 left_color = compute_wide_pattern_color_stipple(left_attr, width,
                    input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);

                float4 right_color = compute_wide_pattern_color_stipple(right_attr, width,
                    input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);
#else
                float4 left_color = compute_wide_pattern_color(left_attr, width,
                    input.color, input.glowColor, pixelPos, input.capsType);

                float4 right_color = compute_wide_pattern_color(right_attr, width,
                    input.color, input.glowColor, pixelPos, input.capsType);
#endif

                // if left color is less transparent, or closer to left when have same color, output left color
                if (left_color.a > right_color.a || (left_color.a == right_color.a && left_attr.dist <= right_attr.dist))
                {
                    if (left_color.a < EPS)
                        discard;

                    float2 capCenter = center;

                    // if it is in a cap region, then current point will share the same cap center as start(end) point.
                    if (left_attr.is_caps)
                        capCenter = left_attr.caps_center;
                    // if it is in a dot region, then we need adjust the capCenter for current point.
                    else if (left_attr.dist > 0)
                        capCenter = center - dir * left_attr.dist;

                    left_attr.dist = length(pixelPos - capCenter);
#ifdef ANALYTIC_STIPPLE
                    color = compute_wide_pattern_color_stipple(left_attr, width,
                        input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);
#else
                    color = compute_wide_pattern_color(left_attr, width,
                        input.color, input.glowColor, pixelPos, input.capsType);
#endif
                }
                // output right color
                else
                {
                    if (right_color.a < EPS)
                        discard;

                    float2 capCenter = center;

                    // if it is in a cap region, then current point will share the same cap center as start(end) point.
                    if (right_attr.is_caps)
                        capCenter = right_attr.caps_center;
                    // if it is in a dot region, then we need adjust the capCenter for current point.
                    else if (right_attr.dist > 0)
                        capCenter = center - dir * right_attr.dist;

                    right_attr.dist = length(pixelPos - capCenter);
#ifdef ANALYTIC_STIPPLE
                    color = compute_wide_pattern_color_stipple(right_attr, width,
                        input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);
#else
                    color = compute_wide_pattern_color(right_attr, width,
                        input.color, input.glowColor, pixelPos, input.capsType);
#endif
                }
            }
        }
    }
    else if (input.shapeType == SHAPE_JOINT)
    {

        float2 prevPoint = input.point0;
        float2 curPoint = input.point1;
        float2 postPoint = input.point2;

        // get screen pos
        float2 pixelPos = input.position.xy;
        pixelPos.y = gScreenSize.y - pixelPos.y;

        // get wide line width
        float width = adjust_line_width_wide_line(input.width);


        // check joint point is on dash or not
        bool on_dash = check_joint_point_on_dash(
            prevPoint,
            curPoint,
            postPoint,
            input.patternIndex,
            input.patternProp,
            input.patternProp_Post,
            width
        );

        // compute directions and distances
        float2 prev_dir = normalize(curPoint - prevPoint);
        float2 post_dir = normalize(postPoint - curPoint);

        float dist_to_prev = abs_dist_pixel_to_line(pixelPos, prev_dir, prevPoint);
        float dist_to_post = abs_dist_pixel_to_line(pixelPos, post_dir, curPoint);
        float dist = length(pixelPos - curPoint);

        // compute pixel and line segments relationship
        bool in_prev_line = inLineRegion(pixelPos, prevPoint, curPoint, input.width + 1.0f, prev_dir);
        bool in_post_line = inLineRegion(pixelPos, curPoint, postPoint, input.width + 1.0f, post_dir);


        // get pure dot flag
        bool is_pure_dot = (input.patternIndex & PURE_DOT_MASK) != 0;
        // get pline gen flag
        bool is_pure_dot_pline_gen = is_pure_dot &&
            is_pline_gen(input.patternProp.y) &&
            is_pline_gen(input.patternProp_Post.x);

        // discard pixels when in overlapped region, unless for the case that pure dot and pline gen off.
        if (in_prev_line && in_post_line)
        {
            if (is_pure_dot_pline_gen || (!is_pure_dot))
                discard;
        }

        color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float4 prev_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float4 post_color = float4(0.0f, 0.0f, 0.0f, 0.0f);

        // fading factor is default value with fading power = 0.3f and fading level = 12.
        //    set fading factor = 1.0f when line-fading off, we can fix it later.
        float fading_factor = pow(0.3f, 1.0f / 6.0f);  // = 1.0f;

        // if on dash
        if (on_dash)
        {
            // compute original color if in line region
            if (in_prev_line || in_post_line)
            {
                [branch] if (gNoAAMode != 0)
                {
                    color = compute_final_color_sharp(dist, width, input.color, input.glowColor);
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
            // compute linefading color if in overlapped region
            else
            {
                [branch] if (gNoAAMode != 0)
                {
                    color = compute_sharp_joint_final_color(dist, width, input.color, input.glowColor,
                        pixelPos, prevPoint, curPoint, postPoint, input.jointType);
                }
                else
                {
#ifdef ANALYTIC_STIPPLE
                    color = compute_joint_final_color_stipple(dist, width, input.color, input.glowColor,
                        pixelPos, prevPoint, curPoint, postPoint, input.jointType, input.stippleIndex);
#else
                    color = compute_joint_final_color(dist, width, input.color, input.glowColor,
                        pixelPos, prevPoint, curPoint, postPoint, input.jointType);
#endif
                }

                if (is_pure_dot_pline_gen || (!is_pure_dot))
                    color = float4(color.xyz, (1 + fading_factor) * color.a - color.a * color.a * fading_factor);
            }
        }
        // if on space or dot
        else
        {
            // check wide line pattern result for left line
            WideLinePatternResult left_prev_attr;
            WideLinePatternResult right_prev_attr;

            WideJointInfo left_info;
            left_info.curPoint = pixelPos;
            left_info.dist = dist_to_prev;
            left_info.width = input.width;
            left_info.startPoint = prevPoint;
            left_info.endPoint = curPoint + prev_dir * input.width * 0.5f;

            int res = check_wide_line_pattern_left(left_info,
                input.patternProp,
                input.patternIndex,
                left_prev_attr);


            if (!in_prev_line)
            {
                if (res == MIXED)
                {
                    if (left_prev_attr.dist != -1.0f)
                    {
                        float dist_to_end = length(pixelPos - curPoint);

                        if (dist_to_end <= left_prev_attr.dist + 0.3f)
                        {
#ifdef ANALYTIC_STIPPLE
                            prev_color = compute_wide_pattern_color_stipple(left_prev_attr, width,
                                input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);
#else
                            prev_color = compute_wide_pattern_color(left_prev_attr, width,
                                input.color, input.glowColor, pixelPos, input.capsType);
#endif
                        }
                    }
                }

            }

            // check wide line pattern result for right line
            WideLinePatternResult left_post_attr;
            WideLinePatternResult right_post_attr;

            float4 t_post_prop = input.patternProp_Post;
            t_post_prop.w = t_post_prop.w - (input.width * 0.5f) * t_post_prop.z;// adjust pattern offset

            WideJointInfo right_info;
            right_info.curPoint = pixelPos;
            right_info.dist = dist_to_post;
            right_info.width = input.width;
            right_info.startPoint = curPoint - post_dir * input.width * 0.5f;
            right_info.endPoint = postPoint;


            res = check_wide_line_pattern_right(right_info,
                t_post_prop,
                input.patternIndex,
                right_post_attr);


            if (!in_post_line)
            {
                if (res == MIXED)
                {
                    if (right_post_attr.dist != -1.0f)
                    {
                        float dist_to_start = length(pixelPos - curPoint);

                        if (dist_to_start <= right_post_attr.dist + 0.3f)
                        {
#ifdef ANALYTIC_STIPPLE
                            post_color = compute_wide_pattern_color_stipple(right_post_attr, width,
                                input.color, input.glowColor, pixelPos, input.capsType, input.stippleIndex);
#else
                            post_color = compute_wide_pattern_color(right_post_attr, width,
                                input.color, input.glowColor, pixelPos, input.capsType);
#endif

                        }
                    }
                }
            }

            // merge color
            if (post_color.a == 0.0f)
            {
                color = prev_color;
            }
            else
            {
                // compute fading color.
                float final_alpha = prev_color.a * fading_factor + post_color.a - prev_color.a * post_color.a * fading_factor;
                color = float4((prev_color.xyz * prev_color.w * (1.0f - post_color.w) * fading_factor + post_color.xyz * post_color.w) / final_alpha, final_alpha);
            }
        }

    }

    // output color and position
    OIT_PS_OUTPUT(color, input.position);
}

technique11 WideLine_Type
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, WideLineType_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, WideLineType_PS()));
    }
}

