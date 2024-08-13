#ifndef _HQ_FX_CIRCLR_ELLIPSE_H__
#define _HQ_FX_CIRCLR_ELLIPSE_H__

#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"

// ellipse primitive texture
Texture2D<float4> gPTex : PrimitiveTexture;

/*
Ellipse/Circle data format.
// high-->low
// |---reserved1 : 2---|---lt_inverted : 1---|---capType : 2---|---logical_flag : 1---|---lt_dot : 1---|---lt_index : 9---|---width : 16---|

    center                  64-bits
    radius                  64-bits
    range                   64-bits
    rotate                  32-bits
    color                   32-bits
    width                   16-bits
    lt_index                9-bits
    lt_dot                  1-bit
    logical_flag            1-bit
    capType                 2-bits
    lt_inverted             1-bit
    reserved1               2-bits
    drawZ                   32-bits
    glowColor               32-bits
    reserved2               32-bits
    total                   256-bits
*/

#define OFFSET_WIDTH (0)        // width offset
#define MASK_WIDTH (0xffff)     // width mask

#define OFFSET_LINDEX (16)      // linetype index offset
#define MASK_LINDEX (0x1ff0000) // linetype index mask

#define OFFSET_LDOT (25)        // linetype dot offset
#define MASK_LDOT (0x2000000)   // linetype dot mask

#define OFFSET_LFLAG (26)       // logical flag offset
#define MASK_LFLAG (0x4000000)  // logical flag mask

#define OFFSET_CTYPE (27)       // cap type offset
#define MASK_CTYPE (0x18000000) // cap type mask

#define OFFSET_LTINV (29)       // linetype inverted offset
#define MASK_LTINV (0x20000000) // linetype inverted mask

struct EllipseAttr_Dash
{
    float2 center : POSITION;   // screen space center
    float2 radius : RADIUS;     // screen space raiuds

    float2 range : RANGE;       // start angle end angle
    float rotate : ROTATE;      // rotation

    float weight : WEIGHT;      // line weight
    uint color : COLOR0;        // color
    float drawZ : DRAWZ;        // draw order z

    uint glowColor : COLOR1;    // glow color
    uint capType : CAPTYPE;     // cap type
    uint isLogical : FLAG;      //logical flag 0: non-logical transform, 1: logical transform
};
#define ATTR_SIZE (3)           // count of attribute size (of float4)

struct VertexAttr_Ellipse
{
    noperspective float4 position : SV_Position;    // transformed  vertex position

    nointerpolation  float2 radius : RADIUS;        // x long axis, y short axis
    nointerpolation  float2 range : RANGE;          // x start angle, y end angle
    nointerpolation  float2 center : POSITION;      // screen space center
    nointerpolation  float rotate : ROTATE;         // rotation

    linear float2 uv : UV;                          // uv is used to compute gradient
    nointerpolation  uint  color : COLOR0;          // ellipse color
    nointerpolation  float weight : WEIGHT;         // ellipse line weight

    nointerpolation  uint  glowColor : COLOR1;      // glow color for highlights
};

// load ellipse primitive id
uint load_prim_id_from_tex(Texture2D<uint> indexTex, uint id)
{
    int2 tex_offset = get_ptex_offset(id);
    return indexTex.Load(int3(tex_offset, 0));
}

// load ellipse attributes
void assign_attr(float4 attr_array[ATTR_SIZE], out EllipseAttr_Dash attr)
{
    attr.center.x = attr_array[0].x;
    attr.center.y = attr_array[0].y;
    attr.radius.x = attr_array[0].z;
    attr.radius.y = attr_array[0].w;

    attr.range = attr_array[1].xy;
    attr.rotate = attr_array[1].z;
    attr.color = asuint(attr_array[1].w);

    attr.weight = ((asuint(attr_array[2].x) & MASK_WIDTH) >> OFFSET_WIDTH);
    attr.isLogical = ((asuint(attr_array[2].x) & MASK_LFLAG) >> OFFSET_LFLAG);
    attr.capType = ((asuint(attr_array[2].x) & MASK_CTYPE) >> OFFSET_CTYPE);
    attr.glowColor = asuint(attr_array[2].y);
    attr.drawZ = attr_array[2].z;
}

void assign_attr_neutron_sketch(float4 attr_array[ATTR_SIZE], inout EllipseAttr_Dash attr)
{
    uint logical_width = asuint(attr_array[2].w);
    uint adjusted_width = uint(attr.weight);
    adjust_line_width_wide_line_neutron_sketch(logical_width, adjusted_width);
    attr.weight = float(adjusted_width);
}

// load ellipse input info
void load_ellipse_info(uint offset, out EllipseAttr_Dash attr)
{
    float4 attr_array[ATTR_SIZE];

    [unroll]
    for (uint i = 0; i <ATTR_SIZE; ++i)
    {
        int2 tex_offset = get_ptex_offset(offset*ATTR_SIZE + i);
        attr_array[i] = gPTex.Load(int3(tex_offset, 0));
    }

    assign_attr(attr_array, attr);
    assign_attr_neutron_sketch(attr_array, attr);
}

// check if elliptical or circle arc is closed when do precision adjustment
bool is_closed_arc(float2 range)
{
    // since this is not restrictly to check arc is closed but for precsion adjustment,
    // the EPS is not common float EPS(1E-6) but an experimental value.
    static const float RANGE_EPS = 0.01f;

    return abs(range.y - range.x) > (2 * PI - RANGE_EPS);
}

// calculate arc angle according to cirlce center, position in arc and circle radius
float get_circle_arc_angle(float x_center, float y_center, float x_pos, float y_pos, float radius)
{
    // calculate angle according to two vertexes of a line.
    float sin_value = (y_pos - y_center) / radius;
    sin_value = sin_value > 1 ? 1 : (sin_value < -1 ? -1 : sin_value);

    float angle = asin(sin_value);
    angle = x_pos < x_center ? (PI - angle) : (y_pos < y_center ? 2 * PI + angle : angle);

    // since float asin will cause precision loss sometimes, do angle compensation.
    float new_sin_value, new_cos_value;
    sincos(angle, new_sin_value, new_cos_value);
    float new_x_pos = x_center + new_cos_value * radius;
    float new_y_pos = y_center + new_sin_value * radius;
    float adjust_angle = distance(float2(x_pos, y_pos), float2(new_x_pos, new_y_pos)) / radius;
    angle = ((sin_value > 0) == (new_x_pos > x_pos)) ? angle + adjust_angle : angle - adjust_angle;

    return angle;
}

void updateOffset(inout float2 center)
{
    center.x += 0.5f;
    center.y += 0.5f;
}

// adjust elliptical arc via adjusting center then range according to start point and end point of ellipse arc.
// please refer to https://wiki.autodesk.com/display/AGS/Maestro+Analytic+Curve+Precision.
void adjust_elliptical_arc(inout EllipseAttr_Dash attr)
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

// expand envelope width for ellipse
float get_screen_weight_expand(float weight)
{
    return weight*4.0f;
}

float2 get_ndc_pos(float2 center, float sin_rot, float cos_rot, float2 model_pos)
{
    // rotate model pos
    float2 rot_pos;

    rot_pos.x = model_pos.x*cos_rot - model_pos.y*sin_rot;
    rot_pos.y = model_pos.x*sin_rot + model_pos.y*cos_rot;

    // mirror model pos
    rot_pos *= neutron_sketch_lcs_matrix_scale_sign();

    // get ndc pos
    float2 scr_pos = center + rot_pos;
    float2 ndc_pos = scr_pos * gInvScreenSize * 2.0f - 1.0f;

    return ndc_pos;
}

// compute envelope shape with 30 triangles
static const uint ENVELOPE_ANGLE_COUNT = 15;
static const uint ENVELOPE_GEOM_COUNT = ENVELOPE_ANGLE_COUNT * 2;

float2 get_ellipse_degrade_pos(uint vid,  float2 center, inout float2 range, inout float weight, out float2 uv)
{
    float2 pos_s = int2(center);
    if (vid > 3)
        vid = 3;

    pos_s.x += (-0.5f + (float)(vid & 0x1));
    pos_s.y += (-0.5f + (float)(vid & 0x2));

    uv.x = (-0.5f + (float)(vid & 0x1));
    uv.y = (-0.5f + (float)(vid & 0x2));

    range = float2(0.0f, 2 * PI);
    weight = 1.0f;

    return screen_to_ndc_pos(pos_s);

}

float2 get_ellipse_model_pos(uint vid, float weight_expand, float2 mid_pos, float mid_dist, 
    float2 mid_vec, float2 mid_tan,
    float angle_delta)
{
    float cos_mn = abs(dot(mid_tan, mid_vec));
    float sin_mn = abs(sqrt(1 - cos_mn*cos_mn));

    float adjust_weight_expand = weight_expand / sin_mn;

    float2 model_pos;

    if ((vid & 0x1) == 0)
    {
        adjust_weight_expand = weight_expand;

        if (mid_dist <= adjust_weight_expand)
            model_pos = float2(0.0f, 0.0f);
        else
            model_pos = mid_pos - adjust_weight_expand*mid_vec;
    }
    else
    {
        float half_angle_delta = angle_delta / 2.0f;

        float2 sin_cos_half;
        sincos(half_angle_delta, sin_cos_half.x, sin_cos_half.y);

        float t_dist = (mid_dist + adjust_weight_expand) / sin_cos_half.y - mid_dist;

        if (t_dist < adjust_weight_expand)
            t_dist = adjust_weight_expand;

        model_pos = mid_pos + t_dist*mid_vec;
    }

    return model_pos;
}

// generate ellipse envelope shapes
float2 get_vertex_pos_envelope_30(uint vid, float long_radius, float short_radius,
    float2 center, float sin_rot, float cos_rot,
    inout float2 range, inout float weight, out float2 uv)
{
    if (max(long_radius, short_radius) < 0.5f)
    {
        return get_ellipse_degrade_pos(vid,  center, range, weight, uv);
    }

    float weight_expand = get_screen_weight_expand(weight);

    float2 expand_range = range + float2(-PI / 180.0f, PI / 180.0f);
    if (expand_range.x < 0.0f) expand_range.x = 0.0f;


    // get arc range index:
    float angle_delta = (2 * PI) / (float)ENVELOPE_ANGLE_COUNT;
    float2 range_index = expand_range / angle_delta;

    int s_index = (int)range_index.x;
    int e_index = (int)range_index.y + 1;

    if (e_index - s_index >= (int)ENVELOPE_ANGLE_COUNT)
        e_index = s_index + ENVELOPE_ANGLE_COUNT;

    // get angle_index
    int angle_index = (vid >> 1) + s_index;

    if (angle_index > e_index) // if not current arc, move to end angle to 
        angle_index = e_index; // generate degeneration shape

    while (angle_index > (int)ENVELOPE_ANGLE_COUNT) // change to 0..2PI
        angle_index -= ENVELOPE_ANGLE_COUNT;

    // get angle
    float cur_angle = angle_index * angle_delta;

    // get mid point parameters
    float2 sin_cos_angle;
    sincos(cur_angle, sin_cos_angle.x, sin_cos_angle.y);

    float2 mid_pos = float2(long_radius*sin_cos_angle.y, short_radius*sin_cos_angle.x);
    float  mid_dist = sqrt(mid_pos.x * mid_pos.x + mid_pos.y*mid_pos.y);
    float2 mid_vec = normalize(mid_pos);

    float2 mid_tan = float2(-long_radius*sin_cos_angle.x, short_radius*sin_cos_angle.y);
    mid_tan = normalize(mid_tan);



    // get model space position
    float2 model_pos = get_ellipse_model_pos(vid, weight_expand, mid_pos, mid_dist, mid_vec, mid_tan,
        angle_delta);

    uv = model_pos;

    // rotate model pos
    return get_ndc_pos(center, sin_rot, cos_rot, model_pos);
}

VertexAttr_Ellipse output_vertex_attr_ellipse(NullVertex_Input input, EllipseAttr_Dash ellipse_attr)
{
    // initialize
    VertexAttr_Ellipse output = (VertexAttr_Ellipse)(0);

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

    output.position.xy = get_vertex_pos_envelope_30(input.VertexID, adjusted_radius.x, adjusted_radius.y,
        center, sin_rot, cos_rot, output.range, ellipse_attr.weight, output.uv);

    // get the radius
    output.radius = adjusted_radius;

    output.center = center;
    output.rotate = ellipse_attr.rotate;

    // update other properties
    output.weight = ellipse_attr.weight;
    output.position.z = ellipse_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.color = ellipse_attr.color; // move color assignment to last will fix an Intel compiler issue.
                                        // since the color assignment will affect position result on Intel cards.

    output.glowColor = ellipse_attr.glowColor;

    return output;
}

// get angle for a point on ellipse 
float get_ellipse_angle(float2 radius, float2 uv)
{
    float x_len = radius.x;
    float y_len = radius.y;

    float cur_angle = atan2(uv.y / y_len, uv.x / x_len);

    if (cur_angle < 0)
        cur_angle = cur_angle + 2 * PI;

    return cur_angle;
}
// check if angle is in arc start/end angle
bool angle_is_in_range(float cur_angle, float2 range)
{
    float lower = min(range.x, range.y);
    float upper = max(range.x, range.y);
    float delta = upper - lower + EPS;

    float dist = cur_angle - lower;
    float dist2 = dist + 2 * PI;
    bool result = ((dist > -EPS) && (dist <= delta))
        || ((dist2 > -EPS) && (dist2 <= delta));

    return result;
}

// check current pixel is in arc start/end angle
bool valid_range(float2 radius, float2 uv, float2 range)
{
    float cur_angle = get_ellipse_angle(radius, uv);

    return angle_is_in_range(cur_angle, range);
}

// check if this is a circle arc. Not precise but for arc precision adjustment.
bool is_circle_arc(float2 radius)
{
    return (round(radius.x) == round(radius.y));
}

// expand range to inner direction of caps
static const float INNER_EXPAND = 8.0f;

bool close_to_caps_border(float dist)
{
    return abs(dist) < INNER_EXPAND;
}

// get caps envelope postion
float2 get_vertex_model_pos_caps(uint vertex_id, float2 mid_point, float2 mid_vec, float weight_expand, out float4 ref_point)
{
    float2 mid_dir = float2(-mid_vec.y, mid_vec.x);

    float2 model_pos;
    float move_dir = (vertex_id & 0x1)*2.0f - 1.0f;

    if ((vertex_id & 0x2) == 0) // 0, 1
    {
        model_pos = mid_point - mid_vec*INNER_EXPAND + move_dir * mid_dir * weight_expand;
    }
    else // 1, 3
    {
        model_pos = mid_point + mid_vec * weight_expand + move_dir * mid_dir * weight_expand;
    }

    ref_point.xy = mid_point;
    ref_point.zw = mid_vec;

    return model_pos;
}

// get vertex position for start caps envelope shape
float2 get_vertex_pos_start_caps(uint vertex_id, float2 range, float long_radius, float short_radius, float weight_expand, out float4 ref_point)
{
    if (vertex_id >= 4)
        vertex_id = 3; // adjust last point

                       // start point vec.
    float sin_start, cos_start;
    sincos(range.x, sin_start, cos_start);

    float2 start_point = float2(long_radius*cos_start, short_radius*sin_start);
    float2 start_vec = -float2(-long_radius*sin_start, short_radius*cos_start);
    start_vec = normalize(start_vec);


    return get_vertex_model_pos_caps(vertex_id, start_point, start_vec, weight_expand, ref_point);
}
// get vertex position for end caps envelope shape
float2 get_vertex_pos_end_caps(uint vertex_id, float2 range, float long_radius, float short_radius, float weight_expand, out float4 ref_point)
{
    if (vertex_id <= 5)
        vertex_id = 6; // adjust first point

    vertex_id = vertex_id - 6; // to 0, 1, 2, 3

                               // end point vec
    float sin_end, cos_end;
    sincos(range.y, sin_end, cos_end);

    float2 end_point = float2(long_radius*cos_end, short_radius*sin_end);
    float2 end_vec = float2(-long_radius*sin_end, short_radius*cos_end);
    end_vec = normalize(end_vec);

    return get_vertex_model_pos_caps(vertex_id, end_point, end_vec, weight_expand, ref_point);
}

// get caps envelope shape
float2 get_vertex_pos_caps(uint vertex_id, float2 range, float long_radius, float short_radius, float weight_expand,
    float2 center, float sin_rot, float cos_rot, out float2 uv, out float4 ref_point)
{
    /* circle as dot don't need caps. */
    if (max(long_radius, short_radius) < 0.5f)
        return float2(0.0f, 0.0f);

    // vid 0,1,2,3 start_cap
    //     4,5,    deprecated pos
    //     6,7,8,9 end_cap
    float2 model_pos;

    if (vertex_id <= 4)
        model_pos = get_vertex_pos_start_caps(vertex_id, range, long_radius, short_radius, weight_expand, ref_point);
    else
        model_pos = get_vertex_pos_end_caps(vertex_id, range, long_radius, short_radius, weight_expand, ref_point);

    uv = model_pos;

    return get_ndc_pos(center, sin_rot, cos_rot, model_pos);
}

bool not_in_circle(VertexAttr_Ellipse input, float width)
{
    float squaredSum = input.uv.x * input.uv.x + input.uv.y * input.uv.y;
    float dist = abs(sqrt(squaredSum) - input.radius.x);
    if ((width > 1) && (dist < width / 2))
        return false;

    float dist2 = squaredSum - input.radius.x * input.radius.x + 0.25f;
    float maxXY = max(abs(input.uv.x), abs(input.uv.y));

    return ((dist >(width + 1) / 2) || (dist2 > max(0.25f, maxXY)) || (dist2 < min(0.25f, -maxXY)));
}
bool in_lw_ellipse(float width, float dist)
{
    return ((width > 1) && (dist < width / 2));
}

bool outside_ellipse(float2 xy, float2 axis)
{
    return ((xy.x * xy.x) / (axis.x * axis.x) + (xy.y * xy.y) / (axis.y * axis.y) - 1 > 0);
}

float2 ellipse_dir(VertexAttr_Ellipse input)
{
    float sin_rot, cos_rot;
    sincos(input.rotate, sin_rot, cos_rot);
    float positionX = input.uv.x * cos_rot - input.uv.y * sin_rot;
    float positionY = input.uv.x * sin_rot + input.uv.y * cos_rot;
    float squareRadiaX = input.radius.x * input.radius.x;
    float squareRadiaY = input.radius.y * input.radius.y;
    float squareRadiaDiff = squareRadiaY - squareRadiaX;
    float temp1 = sin_rot * sin_rot * squareRadiaDiff;
    float temp2 = sin_rot * cos_rot * squareRadiaDiff;
    return normalize(float2((positionY * (squareRadiaX + temp1) + positionX * temp2), (positionX * (squareRadiaY - temp1) + positionY * temp2)));
}

bool not_in_ellipse(VertexAttr_Ellipse input)
{
    float sin_rot, cos_rot;
    sincos(input.rotate, sin_rot, cos_rot);
    float2 dir = ellipse_dir(input);
    float slope = -dir.y / dir.x;

    if (abs(slope) > 1)
        return (outside_ellipse(float2(input.uv.x + 0.5 * cos_rot, input.uv.y - 0.5 * sin_rot), input.radius)
                == outside_ellipse(float2(input.uv.x - 0.5 * cos_rot, input.uv.y + 0.5 * sin_rot), input.radius));
    else
        return (outside_ellipse(float2(input.uv.x + 0.5 * sin_rot, input.uv.y + 0.5 * cos_rot), input.radius)
                == outside_ellipse(float2(input.uv.x - 0.5 * sin_rot, input.uv.y - 0.5 * cos_rot), input.radius));
}

void adjust_circle_range(inout float2 range, inout float rotate)
{
    float adjust_angle = -int((range.x + rotate) / TWO_PI) * TWO_PI;

    range = range + rotate + adjust_angle;

    rotate = 0.0f;
}

#endif
