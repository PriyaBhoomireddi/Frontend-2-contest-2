#ifndef _HQ_FX_PRIM_COMMON_H__
#define _HQ_FX_PRIM_COMMON_H__

#include "Sketch_highlight10.fxh"
#include "Sketch_logical_precision10.fxh"

// primitive texture  bit-feilds
// we use 1024 elements per row for all primitive texture.
#define  PTEX_BITS (10) 
#define  PTEX_WIDTH (0x1<<PTEX_BITS)
#define  PTEX_MASK (PTEX_WIDTH -1)

// caps type flag
#define FLAG_CAP_BUTT       (0x0)
#define FLAG_CAP_SQUARE     (0x1)
#define FLAG_CAP_ROUND      (0x2)
#define FLAG_CAP_DIAMOND    (0x3)

// joint type flag
#define FLAG_JOINT_MITER    (0x0)
#define FLAG_JOINT_BEVEL    (0x1)
#define FLAG_JOINT_ROUND    (0x2)
#define FLAG_JOINT_DIAMOND  (0x3)

// if miter angle less than this, we need special process of the shape.
static const float MITER_MIN_ANGLE = 10.0f;

// experimental extends to adjust line weight and distance
static const float LINE_WEIGHT_EXTEND = 1.15f;
static const float DISTANCE_TO_CENTER_EXTEND = 1.2f;

// since the dot in line type is not big enough, we need to extend it.
static const float LINE_TYPE_DOT_EXTEND = 1.75f;

// Gauss function parameters
float gGaussTheta = 10.0f;
float gGaussSigma = 52.5f;

// the common vertex input format for NULL Vertex Buffer shaders.
struct NullVertex_Input
{
    int VertexID : TEXCOORD0;
    int InstanceID : TEXCOORD1;
};

// extend line weight
float get_extended_line_weight(in float weight)
{
    return (weight * LINE_WEIGHT_EXTEND);
}

// extend distance to the centerline of line or the center of circle/dot
float get_extended_dist_to_center(in float dist)
{
    return (dist * DISTANCE_TO_CENTER_EXTEND);
}

// extned the line weight of dots in linetype including pure dots and non-pure dots
float get_extended_line_type_dot_weight(in float weight)
{
    return (weight * LINE_TYPE_DOT_EXTEND);
}

// get primitive texture coordinate based on offset
int2 get_ptex_offset(uint offset)
{
    int2 tex_offset = int2(offset&PTEX_MASK, offset >> PTEX_BITS);

    return tex_offset;
}

// load dynamic draw order z value from texture
void load_dynamic_draworderz(uint iid, Texture2D<float> drawOrderZTex, inout float drawOrderZ)
{
    int2 index_offset = get_ptex_offset(iid);
    drawOrderZ = drawOrderZTex.Load(int3(index_offset, 0));
}

// check if a pixel is in the center part of a wide line.
bool in_center_of_wide_line(float dist, float weight)
{
    return ((weight > 1.5f) && (dist < weight / 2 - 0.5));
}

// adjust alpha value for single line
// since PD want single line become darker for better visual experience.
float adjust_single_line_alpha(float weight, float val)
{
    float ret = 0.0f;

    if (weight > 1.5f)
        ret = val;
    else
        ret = val * 0.8f;

    // clamp to range 0.0f - 1.0f;
    return saturate(ret);
}

// compute anti-aliasing for primitives.
float get_antialiasing_val(float dist, float weight)
{
    if ((dist == 0.0f) && (weight == 0.0f))
        return 0.0f;

    // if have line weight, and current pixel inside line-weight
    // draw with full transparency.
    if (in_center_of_wide_line(dist, weight))
        return 1.0f;
    
    // compute gaussion blur value as alpha
    float val = gauss_blur(dist, weight, gGaussTheta, gGaussSigma);
   
    return adjust_single_line_alpha(weight, val);

}

// check if in sharp line
bool in_line_sharp(float3 lineParams, float2 position)
{
    float maxParam = 0.5f * max(abs(lineParams.x), abs(lineParams.y));
    float equation = lineParams.x * position.x + lineParams.y * position.y + lineParams.z;
    return (equation > -maxParam && equation <= maxParam);
}

float get_sharp_val(float dist, float weight)
{
    if ((dist == 0.0f) && (weight == 0.0f))
        return 0.0f;

    if (dist <= weight*0.5f)
        return 1.0f;
    else
        return 0.0f;
}


float2 get_caps_param_round(float2 curPoint, float2 capCenterPoint, float lineWeight)
{
    float2 param;
    param.x = length(curPoint - capCenterPoint);
    param.y = lineWeight;

    return param;
}

float2 get_caps_param_butt(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param;

    float dis_to_cap_base_line = abs_dist_pixel_to_line(curPoint, float2(-capDir.y, capDir.x), capCenterPoint);

    // if current point inside round region
    if (length(curPoint - capCenterPoint) <= lineWeight * 0.5f)
    {
        // extent 1 pixel for anti-aliasing
        param.x = dis_to_cap_base_line;
        param.y = 1.0f;
    }
    else
    {
        param.x = 0.0f;
        param.y = 0.0f;
    }

    return param;
}

float2 get_caps_param_square(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param;

    float dis_to_cap_base_line = abs_dist_pixel_to_line(curPoint, float2(-capDir.y, capDir.x), capCenterPoint);
    float dis_to_cap_middle_line = abs_dist_pixel_to_line(curPoint, capDir, capCenterPoint);

    param.x = max(dis_to_cap_base_line, dis_to_cap_middle_line);
    param.y = lineWeight;

    return param;
}

float2 get_caps_param_diamond(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    static const float sin_value = sqrt(0.5f);

    float2 diamond_edge_dir1 = float2((capDir.x - capDir.y) * sin_value, (capDir.x + capDir.y) * sin_value);
    float2 diamond_edge_dir2 = float2(-diamond_edge_dir1.y, diamond_edge_dir1.x);

    float dis_to_edge1 = abs_dist_pixel_to_line(curPoint, diamond_edge_dir1, capCenterPoint);
    float dis_to_edge2 = abs_dist_pixel_to_line(curPoint, diamond_edge_dir2, capCenterPoint);

    float2 param;
    param.x = max(dis_to_edge1, dis_to_edge2);
    param.y = lineWeight * sin_value;

    return param;

}

float get_caps_antialiasing_val_round(float2 curPoint, float2 capCenterPoint, float lineWeight)
{
    float2 param = get_caps_param_round(curPoint, capCenterPoint, lineWeight);

    return get_antialiasing_val(param.x, param.y);
}
float get_caps_antialiasing_val_butt(float2 curPoint,float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param = get_caps_param_butt(curPoint, capCenterPoint, capDir, lineWeight);

    return get_antialiasing_val(param.x, param.y);
}
float get_caps_antialiasing_val_square(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param = get_caps_param_square(curPoint, capCenterPoint, capDir, lineWeight);

    // extent line-weight length, and apply anti-aliasing in different directions.
    return get_antialiasing_val(param.x, param.y);
}

float get_caps_antialiasing_val_diamond(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param = get_caps_param_diamond(curPoint, capCenterPoint, capDir, lineWeight);

    // use max distance to edge to compute anti-aliasing effect.
    return get_antialiasing_val(param.x, param.y);
}


float get_cap_antialiasing_val(float2 curPoint, uint capType, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float val = 0.0f;
    if (capType == FLAG_CAP_ROUND) // round cap
    {
        val = get_caps_antialiasing_val_round(curPoint, capCenterPoint, lineWeight);
    }
    else if (capType == FLAG_CAP_BUTT) // butt cap
    {
        val = get_caps_antialiasing_val_butt(curPoint, capCenterPoint, capDir, lineWeight);
    }
    else if (capType == FLAG_CAP_SQUARE) // square cap
    {
        val = get_caps_antialiasing_val_square(curPoint, capCenterPoint, capDir, lineWeight);
    }
    else if (capType == FLAG_CAP_DIAMOND) // diamond cap
    {
        val = get_caps_antialiasing_val_diamond(curPoint, capCenterPoint, capDir, lineWeight);
    }

    return val;
}
float get_caps_sharp_val_round(float2 curPoint, float2 capCenterPoint, float lineWeight)
{
    float2 param = get_caps_param_round(curPoint, capCenterPoint, lineWeight);

    return get_sharp_val(param.x, param.y);
}
float get_caps_sharp_val_butt(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param = get_caps_param_butt(curPoint, capCenterPoint, capDir, lineWeight);

    return get_sharp_val(param.x, param.y);

}
float get_caps_sharp_val_square(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param = get_caps_param_square(curPoint, capCenterPoint, capDir, lineWeight);

    // extent line-weight length, and apply anti-aliasing in different directions.
    return get_sharp_val(param.x, param.y);
}

float get_caps_sharp_val_diamond(float2 curPoint, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    float2 param = get_caps_param_diamond(curPoint, capCenterPoint, capDir, lineWeight);

    // use max distance to edge to compute anti-aliasing effect.
    return get_sharp_val(param.x, param.y);
}


float get_caps_sharp_val(float2 curPoint, uint capType, float2 capCenterPoint, float2 capDir, float lineWeight)
{
    if (capType == FLAG_CAP_ROUND) // round cap
    {
        return get_caps_sharp_val_round(curPoint, capCenterPoint, lineWeight);
    }
    else if (capType == FLAG_CAP_BUTT) // butt cap
    {
        return get_caps_sharp_val_butt(curPoint, capCenterPoint, capDir, lineWeight);
    }
    else if (capType == FLAG_CAP_SQUARE) // square cap
    {
        return get_caps_sharp_val_square(curPoint, capCenterPoint, capDir, lineWeight);
    }
    else if (capType == FLAG_CAP_DIAMOND) // diamond cap
    {
        return get_caps_sharp_val_diamond(curPoint, capCenterPoint, capDir, lineWeight);
    }

    return 0.0f;
}
float2 get_joint_param_round(float2 curPoint, float2 endPoint, float lineWeight)
{
    float2 param;
    param.x = length(curPoint - endPoint);
    param.y = lineWeight;

    return param;
}
float2 get_joint_param_miter(float2 curLineDir, float2 nextLineDir,
    float2 curPoint, float2 endPoint, float lineWeight)
{
    float2 param;
    // if larger than 10 degree, we draw miter effect
    if (dot(-curLineDir, nextLineDir) < cos(PI*MITER_MIN_ANGLE / 180.0f))
    {
        float dis_to_preline = abs_dist_pixel_to_line(curPoint, nextLineDir, endPoint);
        float dis_to_curline = abs_dist_pixel_to_line(curPoint, curLineDir, endPoint);

        param.x = max(dis_to_preline, dis_to_curline);
        param.y = lineWeight;
    }
    else
    {
        param.x = 0.0f;
        param.y = 0.0f;
    }

    return param;
}
float get_bevel_joint_line_weight(float2 middle_dir, float2 curLineDir, float lineWeight, float2 endPoint)
{
    float2 new_vertex = endPoint + lineWeight*0.5f * float2(curLineDir.y, -curLineDir.x);
    return abs_dist_pixel_to_line(new_vertex, float2(-middle_dir.y, middle_dir.x), endPoint) * 2;
}
float2 get_joint_param_bevel(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    // get anti-aliasing value
    float2 param;
    param.x = abs_dist_pixel_to_line(curPoint, float2(-middle_dir.y, middle_dir.x), endPoint);
    param.y = get_bevel_joint_line_weight(middle_dir, curLineDir, lineWeight, endPoint);

    return param;

}
float2 get_joint_param_diamond(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    // compute anti-aliasing value.
    float2 prev_middle_dir = normalize(prev_pend_dir - middle_dir);
    float2 post_middle_dir = normalize(post_pend_dir - middle_dir);

    float prev_dist = abs_dist_pixel_to_line(curPoint, float2(-prev_middle_dir.y, prev_middle_dir.x), endPoint);
    float post_dist = abs_dist_pixel_to_line(curPoint, float2(-post_middle_dir.y, post_middle_dir.x), endPoint);

    float new_line_weight = lineWeight*0.5f*dot(-middle_dir, prev_middle_dir);

    float2 cur_dir = normalize(curPoint - endPoint);
    float  cos_prev = dot(cur_dir, prev_middle_dir);
    float  cos_post = dot(cur_dir, post_middle_dir);

    float t_dist;
    if (cos_prev > cos_post)
    {
        t_dist = prev_dist;
    }
    else
    {
        t_dist = post_dist;
    }

    float2 param;  

    param.x = t_dist;
    param.y = new_line_weight*2.0f;

    return param;

}
float get_joint_antialiasing_val_round(float2 curPoint, float2 endPoint, float lineWeight)
{
    float2 param = get_joint_param_round(curPoint, endPoint, lineWeight);

    return get_antialiasing_val(param.x, param.y);
}
float get_joint_antialiasing_val_miter(float2 curLineDir, float2 nextLineDir,
    float2 curPoint, float2 endPoint, float lineWeight)
{
    float2 param = get_joint_param_miter(curLineDir, nextLineDir, curPoint, endPoint, lineWeight);

    return get_antialiasing_val(param.x, param.y);
}
bool out_of_bevel_range(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    // adjust anti-aliasing value: discard pixels out of bevel range.
    float2 prev_pend_pnt = endPoint + prev_pend_dir*lineWeight / 2.0f;
    float2 post_pend_pnt = endPoint + post_pend_dir*lineWeight / 2.0f;

    float test_len = length(prev_pend_pnt - post_pend_pnt) / 2.0f;
    float test_dist = abs_dist_pixel_to_line(curPoint, middle_dir, endPoint);

    return (test_dist >= test_len);
}
float get_joint_antialiasing_val_bevel(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    float2 param = get_joint_param_bevel(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir);

    float anti_aliasing_val = get_antialiasing_val(param.x, param.y);

    if (out_of_bevel_range(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir))
        return 0.0f;

    return anti_aliasing_val;

}
bool out_of_diamond_range(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    // discard pixels out of diamond range.
    float2 prev_pend_pnt = endPoint + prev_pend_dir*lineWeight / 2.0f;
    float2 post_pend_pnt = endPoint + post_pend_dir*lineWeight / 2.0f;

    float test_len = length(prev_pend_pnt - post_pend_pnt) / 2.0f;
    float test_dist = abs_dist_pixel_to_line(curPoint, middle_dir, endPoint);

    return (test_dist >= test_len);

}

float get_joint_antialiasing_val_diamond(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    float2 param = get_joint_param_diamond(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir);

    float anti_aliasing_val = get_antialiasing_val(param.x, param.y);

    if (out_of_diamond_range(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir))
        return 0.0f;

    return anti_aliasing_val;
}
// get  perpendicular dir of current line and next line.
void get_joint_pend_dirs(float2 curLineDir, float2 nextLineDir, float2 middle_dir, 
    out float2 prev_pend_dir, out float2 post_pend_dir)
{
    float2 prev_dir = -curLineDir;
    float2 post_dir = nextLineDir;

    float2 dir_diff = prev_dir - post_dir;
    if (dot(dir_diff, dir_diff) < EPS)
    {
        prev_pend_dir = float2(prev_dir.y, -prev_dir.x);
        post_pend_dir = -prev_pend_dir;
    }
    else
    {
        prev_pend_dir = float2(prev_dir.y, -prev_dir.x);
        post_pend_dir = float2(post_dir.y, -post_dir.x);

        if (dot(prev_pend_dir, middle_dir) > 0)
            prev_pend_dir = -prev_pend_dir;

        if (dot(post_pend_dir, middle_dir) > 0)
            post_pend_dir = -post_pend_dir;

    }

}
float get_joint_antialiasing_val(float2 curPoint, float2 startPoint, float2 endPoint, float2 nextPoint, float lineWeight, uint capJointType)
{

    float val = 0.0f;
    if (capJointType == FLAG_JOINT_ROUND) // round joint
    {
        val = get_joint_antialiasing_val_round(curPoint, endPoint, lineWeight);
    }
    else
    {
        float2 curLineDir = normalize(endPoint - startPoint);
        float2 nextLineDir = normalize(nextPoint - endPoint);

        if (capJointType == FLAG_JOINT_MITER) // miter joint
        {
            val = get_joint_antialiasing_val_miter(curLineDir, nextLineDir, curPoint, endPoint, lineWeight);
        }
        else
        {
            float2 middle_dir = normalize(-curLineDir + nextLineDir);

            float2 prev_pend_dir = float2(0.0f, 0.0f);
            float2 post_pend_dir = float2(0.0f, 0.0f);
            get_joint_pend_dirs(curLineDir, nextLineDir, middle_dir,
                prev_pend_dir, post_pend_dir);


            if (capJointType == FLAG_JOINT_BEVEL) // bevel joint
            {
                val = get_joint_antialiasing_val_bevel(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
                    prev_pend_dir, post_pend_dir);
            }
            else if (capJointType == FLAG_JOINT_DIAMOND) // diamond joint
            {
                val = get_joint_antialiasing_val_diamond(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
                    prev_pend_dir, post_pend_dir);
            }
        }
    }

    return val;
}
float get_joint_sharp_val_round(float2 curPoint, float2 endPoint, float lineWeight)
{
    float2 param = get_joint_param_round(curPoint, endPoint, lineWeight);

    return get_sharp_val(length(curPoint - endPoint), lineWeight);
}

float get_joint_sharp_val_miter(float2 curLineDir, float2 nextLineDir,
    float2 curPoint, float2 endPoint, float lineWeight)
{
    float2 param = get_joint_param_miter(curLineDir, nextLineDir, curPoint, endPoint, lineWeight);

    return get_sharp_val(param.x, param.y);
}

float get_joint_sharp_val_bevel(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    float2 param = get_joint_param_bevel(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir);

    float val = get_sharp_val(param.x, param.y);

    if (out_of_bevel_range(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir))
        return 0.0f;

    return val;

}


float get_joint_sharp_val_diamond(float2 curLineDir, float2 middle_dir, float2 curPoint, float2 endPoint, float lineWeight,
    float2 prev_pend_dir, float2 post_pend_dir)
{
    float2 param = get_joint_param_diamond(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir);

    float val = get_sharp_val(param.x, param.y);

    if (out_of_diamond_range(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
        prev_pend_dir, post_pend_dir))
        return 0.0f;

    return val;
}
float get_joint_sharp_val(float2 curPoint, float2 startPoint, float2 endPoint, float2 nextPoint, float lineWeight, uint capJointType)
{
    float val = 0.0f;
    if (capJointType == FLAG_JOINT_ROUND) // round joint
    {
        val = get_joint_sharp_val_round(curPoint, endPoint, lineWeight);
    }
    else
    {
        float2 curLineDir = normalize(endPoint - startPoint);
        float2 nextLineDir = normalize(nextPoint - endPoint);

        if (capJointType == FLAG_JOINT_MITER) // miter joint
        {
            val = get_joint_sharp_val_miter(curLineDir, nextLineDir, curPoint, endPoint, lineWeight);
        }
        else
        {
            float2 middle_dir = normalize(-curLineDir + nextLineDir);

            float2 prev_pend_dir = float2(0.0f, 0.0f);
            float2 post_pend_dir = float2(0.0f, 0.0f);
            get_joint_pend_dirs(curLineDir, nextLineDir, middle_dir,
                prev_pend_dir, post_pend_dir);


            if (capJointType == FLAG_JOINT_BEVEL) // bevel joint
            {
                val = get_joint_sharp_val_bevel(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
                    prev_pend_dir, post_pend_dir);
            }
            else if (capJointType == FLAG_JOINT_DIAMOND) // diamond joint
            {
                val = get_joint_sharp_val_diamond(curLineDir, middle_dir, curPoint, endPoint, lineWeight,
                    prev_pend_dir, post_pend_dir);
            }
        }
    }

    return val;
}

float4 compute_final_color(float dist, float weight, uint color, uint glowColor)
{
    float4 final_color;

#ifdef ANALYTIC_HIGHLIGHT
    final_color = compute_highlight_color(dist, weight, color, glowColor, false);
#else
    float anti_aliasing_val = get_antialiasing_val(dist, weight);
    final_color = get_formatted_color(color, anti_aliasing_val);
#endif

    return final_color;
}
float4 compute_final_color_sharp(float dist, float weight, uint color, uint glowColor)
{
    float4 final_color = float4(0.0f, 0.0f, 0.0f, 0.0f);

    
#ifdef ANALYTIC_HIGHLIGHT
        final_color = compute_highlight_sharp_color(dist, weight, color, glowColor, true);
#else
        float sharp_val = get_sharp_val(dist, weight);
        final_color = get_formatted_color(color, sharp_val);
#endif
    
    
    return final_color;
}

float4 compute_caps_final_color(float dist, float weight, uint color, uint glowColor,
    float2 cur_pos, float2 cap_center, float2 cap_dir, uint cap_type)
{
    float4 final_color;

#ifdef ANALYTIC_HIGHLIGHT
    final_color = compute_highlight_color(dist, weight, color, glowColor, true);
#else
        float anti_aliasing_val = get_cap_antialiasing_val(cur_pos, cap_type, cap_center, cap_dir, weight);
        final_color = get_formatted_color(color, anti_aliasing_val);
#endif

    return final_color;
}
float4 compute_sharp_caps_final_color(float dist, float weight, uint color, uint glowColor,
    float2 cur_pos, float2 cap_center, float2 cap_dir, uint cap_type)
{
    float4 final_color;

#ifdef ANALYTIC_HIGHLIGHT
        final_color = compute_highlight_sharp_color(dist, weight, color, glowColor, true);
#else
        float val = get_caps_sharp_val(cur_pos, cap_type, cap_center, cap_dir, weight);
        final_color = get_formatted_color(color, val);
#endif

    return final_color;
}

float4 compute_joint_final_color(float dist, float weight, uint color, uint glowColor,
    float2 cur_pos, float2 start_point, float2 end_point, float2 next_point, uint joint_type)
{
    float4 final_color;

#ifdef ANALYTIC_HIGHLIGHT
        final_color = compute_highlight_color(dist, weight, color, glowColor, false);
#else
        float anti_aliasing_val = get_joint_antialiasing_val(cur_pos, start_point, end_point, next_point, weight, joint_type);
        final_color = get_formatted_color(color, anti_aliasing_val);
#endif

    return final_color;
}
float4 compute_sharp_joint_final_color(float dist, float weight, uint color, uint glowColor,
    float2 cur_pos, float2 start_point, float2 end_point, float2 next_point, uint joint_type)
{
    float4 final_color;

#ifdef ANALYTIC_HIGHLIGHT
        final_color = compute_highlight_sharp_color(dist, weight, color, glowColor, true);
#else
        float val = get_joint_sharp_val(cur_pos, start_point, end_point, next_point, weight, joint_type);
        final_color = get_formatted_color(color, val);
#endif

    return final_color;
}

float2 screen_to_ndc_pos(float2 scr_pos)
{
    return scr_pos * gInvScreenSize * 2.0f - 1.0f;
}

float2 ndc_to_screen(float2 ndc_pos)
{
    float2 factor = gScreenSize * 0.5f;
    return ndc_pos*factor + float2(1.0f, 1.0f)*factor;
}

float2 screen_to_logic(float2 scr_pos)
{
    return ndc_to_logic(screen_to_ndc_pos(scr_pos));
}

float2 logic_to_screen(float2 logic_pos)
{
    float2 val = ndc_to_screen(logic_to_ndc(logic_pos));
    [branch]if (gNoAAMode != 0)
        return trunc(val) + float2(0.5f, 0.5f);
    else
        return val;
}

#endif
