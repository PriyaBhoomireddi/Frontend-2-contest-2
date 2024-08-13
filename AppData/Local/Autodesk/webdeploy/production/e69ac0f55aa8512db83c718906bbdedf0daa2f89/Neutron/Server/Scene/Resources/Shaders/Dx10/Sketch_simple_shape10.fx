#include "Sketch_oit_def10.fxh"
#include "Sketch_primitive10.fxh"

#ifdef ANALYTIC_STIPPLE
  #include "Sketch_stipple10.fxh"
#endif

// Simple shape primitive texture.
// 1. center (2 floats)
// 2. size (2 floats)
// 3. depth and logical flag shared value (1 float)
// 4. shape + flags (1 float)
// 5. stipple index + glow radius (1 float)
// 6. reserved (1 float)
// 7. rotate + roundness (2 floats)
// 8. color + glow color (2 floats)
Texture2D<float4> gSimpleShapePrimTex : PrimitiveTexture;

// Simple shape index texture.
Texture2D<uint>  gSimpleShapeIndexTex : SimpleShapeIndexTexture;
Texture2D<float> gSimpleShapeDrawOrderZTex : SimpleShapeDrawOrderZTexture;

struct SimpleShapeAttr
{
    float2 center;
    float2 size;

    uint shape;
    float rotate;
    float roundness;

    bool isLogical;
    float drawZ;
    uint color;
    uint glowColor;

#ifdef ANALYTIC_STIPPLE
    uint stippleIndex;
#endif
};

struct VertexAttr_SimpleShape
{
    noperspective float4 position : SV_Position; // transformed vertex position

    nointerpolation float2 center : CENTER; // center
    nointerpolation float2 size : SIZE; // size
    nointerpolation float rotate : ROTATE; // rotate
    nointerpolation float roundness : ROUNDNESS; // roundness

    nointerpolation uint shape : SHAPE; // shape
    nointerpolation uint color : COLOR; // color
    nointerpolation uint glowColor : GLOW; // color

#ifdef ANALYTIC_STIPPLE
    nointerpolation uint stippleIndex : STPIDX; // stipple index
#endif
};

// rotate the local position relative to center in screen space
float2 get_rotate_pos(float2 center, float sin_rot, float cos_rot, float2 model_pos)
{
    // rotate model pos
    float2 rot_pos;
    rot_pos.x = model_pos.x * cos_rot - model_pos.y * sin_rot;
    rot_pos.y = model_pos.x * sin_rot + model_pos.y * cos_rot;

    // mirror model pos
    rot_pos *= neutron_sketch_lcs_matrix_scale_sign();

    // get screen pos
    return center + rot_pos;
}

// transform from local position to ndc position
float2 get_ndc_pos(float2 center, float sin_rot, float cos_rot, float2 model_pos)
{
    float2 scr_pos = get_rotate_pos(center, sin_rot, cos_rot, model_pos);
    float2 ndc_pos = scr_pos * gInvScreenSize * 2.0f - 1.0f;
    return ndc_pos;
}

// load the simple shape index from index texture
uint load_simple_shape_id_from_tex(Texture2D<uint> indexTex, uint id)
{
    int2 tex_offset = get_ptex_offset(id); 
    return indexTex.Load(int3(tex_offset, 0));
}

// load the vertex info from primitive texture
void load_vertex_info(uint instance_id, uint vertex_id, uint simple_shape_id, out SimpleShapeAttr attr)
{
    int2 offset = get_ptex_offset(simple_shape_id * 3);
    float4 val = gSimpleShapePrimTex.Load(int3(offset, 0));
    attr.center = val.xy;
    attr.size = val.zw;

    offset = get_ptex_offset(simple_shape_id * 3 + 1);
    val = gSimpleShapePrimTex.Load(int3(offset, 0));
    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(instance_id, gSimpleShapeDrawOrderZTex, attr.drawZ);
        attr.isLogical = true;
    }
    else
    {
        attr.drawZ = abs(val.x);
        attr.isLogical = get_logical_space(val.x);
    }
    attr.shape = asuint(val.y) & 0xffff;
#ifdef ANALYTIC_STIPPLE
    attr.stippleIndex = asuint(val.z) & 0xffff;
#endif

    offset = get_ptex_offset(simple_shape_id * 3 + 2);
    val = gSimpleShapePrimTex.Load(int3(offset, 0));
    attr.rotate = val.x;
    attr.roundness = val.y;
    attr.color = asuint(val.z);
    attr.glowColor = asuint(val.w);
}

// set properties of simple shape for pixel shader
void set_simple_shape_properties(uint vertex_id, SimpleShapeAttr attr, out VertexAttr_SimpleShape output)
{
    float2 center = attr.center;
    float2 adjusted_size = attr.size;

    float sin_rot, cos_rot;
    sincos(attr.rotate, sin_rot, cos_rot);

    [branch] if (gRetainMode)
    {
        center = logic_to_ndc(center);
        center = ndc_to_screen(center);

        adjusted_size = neutron_sketch_radius_to_screen(adjusted_size * 0.5f) * 2.0f;
    }
    else
    {
        if (attr.isLogical)
        {
            center = logic_to_ndc(center);
            center = ndc_to_screen(center);

            adjusted_size = neutron_sketch_radius_to_screen(adjusted_size * 0.5f) * 2.0f;
        }
        else
        {
            if (attr.size.x == 0) adjusted_size.x = 1.0f;
            if (attr.size.y == 0) adjusted_size.y = 1.0f;
        }
    }

    // LINE_WEIGHT_EXPAND + wide line expand on both sides
    float2 adjusted_size_expand = adjusted_size + 2.0f * (float2(1.0f, 1.0f) + float2(1.0f, 1.0f));
    float2 pos;
    if (vertex_id == 0)
        pos = 0.5f * -adjusted_size_expand;
    else if (vertex_id == 1)
        pos = 0.5f * float2(adjusted_size_expand.x, -adjusted_size_expand.y);
    else if (vertex_id == 2)
        pos = 0.5f * float2(-adjusted_size_expand.x, adjusted_size_expand.y);
    else
        pos = 0.5f * adjusted_size_expand;

    output.position.xy = get_ndc_pos(center, sin_rot, cos_rot, pos);
    output.position.z = attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.center = center;
    output.size = adjusted_size;
    output.rotate = attr.rotate;
    output.roundness = attr.roundness;

    output.shape = attr.shape;
    output.color = attr.color;
    output.glowColor = attr.glowColor;

#ifdef ANALYTIC_STIPPLE
    output.stippleIndex = attr.stippleIndex;
#endif
}

VertexAttr_SimpleShape SimpleShape_VS(NullVertex_Input input)
{
    uint simple_shape_id = load_simple_shape_id_from_tex(gSimpleShapeIndexTex, input.InstanceID);

    SimpleShapeAttr attr = (SimpleShapeAttr)0;
    load_vertex_info(input.InstanceID, input.VertexID, simple_shape_id, attr);

    VertexAttr_SimpleShape output = (VertexAttr_SimpleShape)0;
    set_simple_shape_properties(input.VertexID, attr, output);

    return output;
}

// check if a pixel is in a wide-line's region.
bool inLineRegion(float2 curPos, float2 startPoint, float2 endPoint, float width, float2 dir)
{
    // get line len
    float2 delta_line = endPoint - startPoint;
    float  line_len = length(delta_line);

    bool ret = true;

    // ignore degrading line.
    if (abs(line_len) < EPS)
        ret = false;

    // check distance to start and distance to end
    float2 delta_to_start = curPos - startPoint;
    float dist_to_start = dot(delta_to_start, dir);

    float2 delta_to_end = curPos - endPoint;
    float dist_to_end = dot(delta_to_end, -dir);

    // ignore out of distance range pixels.
    if ((dist_to_start > line_len + EPS))
        ret = false;

    if ((dist_to_end > line_len + EPS))
        ret = false;

    // check distance to line center line
    float2 distance = endPoint - startPoint;

    float dist = abs(delta_line.x * delta_to_start.y - delta_line.y * delta_to_start.x) / line_len;

    // ignore the pixels far from current line
    if (ret)
        return dist < width / 2.0f + EPS;
    else
        return false;
}

OIT_PS_HEADER(SimpleShape_PS, VertexAttr_SimpleShape)
{
    float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // get screen pos
    float2 pixelPos = input.position.xy;
    pixelPos.y = gScreenSize.y - pixelPos.y;

    // rotation
    float sin_rot, cos_rot;
    sincos(input.rotate, sin_rot, cos_rot);

    // change handness if mirror
    float det_sign = neutron_sketch_lcs_matrix_det_sign();

    if (input.shape == 0) // FLAG_SHAPE_ROUND_RECT
    {
        // radius of the round corners (circle only!)
        float radius = input.roundness * min(input.size.x, input.size.y) * 0.5f;

        // the centers of the round corners
        float2 inner_size = input.size - radius * 2.0f;
        if (inner_size.x <= 0.01f) inner_size.x = 0.01f;
        if (inner_size.y <= 0.01f) inner_size.y = 0.01f;
        float2 refs[4], dirs[4];
        refs[0] = get_rotate_pos(input.center, sin_rot, cos_rot, 0.5f * -inner_size);
        refs[1] = get_rotate_pos(input.center, sin_rot, cos_rot, 0.5f * float2(inner_size.x, -inner_size.y));
        refs[2] = get_rotate_pos(input.center, sin_rot, cos_rot, 0.5f * inner_size);
        refs[3] = get_rotate_pos(input.center, sin_rot, cos_rot, 0.5f * float2(-inner_size.x, inner_size.y));
        dirs[0] = normalize(refs[1] - refs[0]);
        dirs[1] = normalize(refs[2] - refs[1]);
        dirs[2] = normalize(refs[3] - refs[2]);
        dirs[3] = normalize(refs[0] - refs[3]);

        // if the pixel is on the same side of the 4 lines, it's inside the rectangle
        float4 fill_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float4 dist;
        dist.x = det_sign * dist_pixel_to_line(pixelPos, dirs[0], refs[0]);
        dist.y = det_sign * dist_pixel_to_line(pixelPos, dirs[1], refs[1]);
        dist.z = det_sign * dist_pixel_to_line(pixelPos, dirs[2], refs[2]);
        dist.w = det_sign * dist_pixel_to_line(pixelPos, dirs[3], refs[3]);
        if (all(dist >= float4(0.0f, 0.0f, 0.0f, 0.0f)))
        {
            // inside, as if in the center of a wide line
            float d = 0.0f;
            float w = max(inner_size.x, inner_size.y);
#ifdef ANALYTIC_STIPPLE
            fill_color = compute_final_color_stipple(d, w, input.color, input.glowColor, pixelPos, input.stippleIndex);
#else
            fill_color = compute_final_color(d, w, input.color, input.glowColor);
#endif
        }

        // if the pixel is on the same side of the 3 lines, it's outside the 4th line
        float4 line_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float line_w;
        float dist_to_line = -1.0f;
        if (radius < 0.5f)
        {
            // sharp, 1px line on the border
            line_w = get_extended_line_weight(1.0f);
                 if (inLineRegion(pixelPos, refs[0], refs[1], line_w + 2.0f, dirs[0])) dist_to_line = abs(dist.x);
            else if (inLineRegion(pixelPos, refs[1], refs[2], line_w + 2.0f, dirs[1])) dist_to_line = abs(dist.y);
            else if (inLineRegion(pixelPos, refs[2], refs[3], line_w + 2.0f, dirs[2])) dist_to_line = abs(dist.z);
            else if (inLineRegion(pixelPos, refs[3], refs[0], line_w + 2.0f, dirs[3])) dist_to_line = abs(dist.w);
            if (dist_to_line >= 0.0f) dist_to_line = get_extended_dist_to_center(dist_to_line);
        }
        else if (any(dist <= float4(0.0f, 0.0f, 0.0f, 0.0f)))
        {
            // rounded, half of the wide line body
            line_w = radius * 2.0f;
                 if (all(dist.yzw >= float3(0.0f, 0.0f, 0.0f))) dist_to_line = abs(dist.x);
            else if (all(dist.xzw >= float3(0.0f, 0.0f, 0.0f))) dist_to_line = abs(dist.y);
            else if (all(dist.xyw >= float3(0.0f, 0.0f, 0.0f))) dist_to_line = abs(dist.z);
            else if (all(dist.xyz >= float3(0.0f, 0.0f, 0.0f))) dist_to_line = abs(dist.w);
        }
        if (dist_to_line >= 0.0f)
        {
            // side, as if on the side of a wide line
            float d = dist_to_line;
            float w = line_w;
#ifdef ANALYTIC_STIPPLE
            line_color = compute_final_color_stipple(d, w, input.color, input.glowColor, pixelPos, input.stippleIndex);
#else
            line_color = compute_final_color(d, w, input.color, input.glowColor);
#endif
        }

        // if the pixel is on the same other side of the 2 lines, it's the corner
        float4 cap_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float dist_to_cap = -1.0f;
             if (all(dist.wx <= float2(0.0f, 0.0f))) dist_to_cap = sqrt(dot(dist.wx, dist.wx));
        else if (all(dist.xy <= float2(0.0f, 0.0f))) dist_to_cap = sqrt(dot(dist.xy, dist.xy));
        else if (all(dist.yz <= float2(0.0f, 0.0f))) dist_to_cap = sqrt(dot(dist.yz, dist.yz));
        else if (all(dist.zw <= float2(0.0f, 0.0f))) dist_to_cap = sqrt(dot(dist.zw, dist.zw));
        if (dist_to_cap >= 0.0f && dist_to_cap <= line_w)
        {
            // corner, as if on the cap of a wide line
            float d = radius < 0.5f ? get_extended_dist_to_center(dist_to_cap) : dist_to_cap;
            float w = line_w;
#ifdef ANALYTIC_STIPPLE
            cap_color = compute_final_color_stipple(d, w, input.color, input.glowColor, pixelPos, input.stippleIndex);
#else
            cap_color = compute_final_color(d, w, input.color, input.glowColor);
#endif
        }

        // select
        color = fill_color;
        if (color.a < line_color.a) color = line_color;
        if (color.a < cap_color.a)  color = cap_color;
    }
    else if (input.shape == 1) // FLAG_SHAPE_OCTAGON
    {
        // the corners of the octagon
        float2 hlen = input.size * (sqrt(2.0f) - 1.0f) * 0.5f;
        float2 hsize = input.size * 0.5f;
        float2 refs[8], dirs[8];
        refs[0] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(-hsize.x, -hlen.y));
        refs[1] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(-hlen.x, -hsize.y));
        refs[2] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(hlen.x, -hsize.y));
        refs[3] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(hsize.x, -hlen.y));
        refs[4] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(hsize.x, hlen.y));
        refs[5] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(hlen.x, hsize.y));
        refs[6] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(-hlen.x, hsize.y));
        refs[7] = get_rotate_pos(input.center, sin_rot, cos_rot, float2(-hsize.x, hlen.y));
        dirs[0] = normalize(refs[1] - refs[0]);
        dirs[1] = normalize(refs[2] - refs[1]);
        dirs[2] = normalize(refs[3] - refs[2]);
        dirs[3] = normalize(refs[4] - refs[3]);
        dirs[4] = normalize(refs[5] - refs[4]);
        dirs[5] = normalize(refs[6] - refs[5]);
        dirs[6] = normalize(refs[7] - refs[6]);
        dirs[7] = normalize(refs[0] - refs[7]);

        // if the pixel is on the same side of the 8 lines, it's inside the octagon
        float4 fill_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float4 ldist, hdist;
        ldist.x = det_sign * dist_pixel_to_line(pixelPos, dirs[0], refs[0]);
        ldist.y = det_sign * dist_pixel_to_line(pixelPos, dirs[1], refs[1]);
        ldist.z = det_sign * dist_pixel_to_line(pixelPos, dirs[2], refs[2]);
        ldist.w = det_sign * dist_pixel_to_line(pixelPos, dirs[3], refs[3]);
        hdist.x = det_sign * dist_pixel_to_line(pixelPos, dirs[4], refs[4]);
        hdist.y = det_sign * dist_pixel_to_line(pixelPos, dirs[5], refs[5]);
        hdist.z = det_sign * dist_pixel_to_line(pixelPos, dirs[6], refs[6]);
        hdist.w = det_sign * dist_pixel_to_line(pixelPos, dirs[7], refs[7]);
        if (all(ldist >= float4(0.0f, 0.0f, 0.0f, 0.0f)) && all(hdist >= float4(0.0f, 0.0f, 0.0f, 0.0f)))
        {
            // inside, as if in the center of a wide line
            float d = 0.0f;
            float w = max(input.size.x, input.size.y);
#ifdef ANALYTIC_STIPPLE
            fill_color = compute_final_color_stipple(d, w, input.color, input.glowColor, pixelPos, input.stippleIndex);
#else
            fill_color = compute_final_color(d, w, input.color, input.glowColor);
#endif
        }

        // if the pixel is on the border of the octagon
        float4 line_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float line_w = get_extended_line_weight(1.0f);
        float dist_to_line = -1.0f;
             if (inLineRegion(pixelPos, refs[0], refs[1], line_w + 2.0f, dirs[0])) dist_to_line = abs(ldist.x);
        else if (inLineRegion(pixelPos, refs[1], refs[2], line_w + 2.0f, dirs[1])) dist_to_line = abs(ldist.y);
        else if (inLineRegion(pixelPos, refs[2], refs[3], line_w + 2.0f, dirs[2])) dist_to_line = abs(ldist.z);
        else if (inLineRegion(pixelPos, refs[3], refs[4], line_w + 2.0f, dirs[3])) dist_to_line = abs(ldist.w);
        else if (inLineRegion(pixelPos, refs[4], refs[5], line_w + 2.0f, dirs[4])) dist_to_line = abs(hdist.x);
        else if (inLineRegion(pixelPos, refs[5], refs[6], line_w + 2.0f, dirs[5])) dist_to_line = abs(hdist.y);
        else if (inLineRegion(pixelPos, refs[6], refs[7], line_w + 2.0f, dirs[6])) dist_to_line = abs(hdist.z);
        else if (inLineRegion(pixelPos, refs[7], refs[0], line_w + 2.0f, dirs[7])) dist_to_line = abs(hdist.w);
        if (dist_to_line >= 0.0f)
        {
            // border, as if on the body of a wide line
            float d = get_extended_dist_to_center(dist_to_line);
            float w = line_w;
            line_color = compute_final_color(d, w, input.color, input.glowColor);
        }

        // if the pixel is on the same other side of the 2 lines, it's the corner
        float4 cap_color = float4(0.0f, 0.0f, 0.0f, 0.0f);
        float4 link1 = float4(hdist.w, ldist.x, ldist.w, hdist.x);
        float dist_to_cap = -1.0f;
             if (all(link1.xy <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[0]);
        else if (all(ldist.xy <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[1]);
        else if (all(ldist.yz <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[2]);
        else if (all(ldist.zw <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[3]);
        else if (all(link1.zw <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[4]);
        else if (all(hdist.xy <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[5]);
        else if (all(hdist.yz <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[6]);
        else if (all(hdist.zw <= float2(0.0f, 0.0f))) dist_to_cap = distance(pixelPos, refs[7]);
        if (dist_to_cap >= 0.0f && dist_to_cap <= line_w)
        {
            // corner, as if on the cap of a wide line
            float d = get_extended_dist_to_center(dist_to_cap);
            float w = line_w;
            cap_color = compute_final_color(d, w, input.color, input.glowColor);
        }

        // select
        color = fill_color;
        if (color.a < line_color.a) color = line_color;
        if (color.a < cap_color.a)  color = cap_color;
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 SimpleShape
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, SimpleShape_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, SimpleShape_PS()));
    }
}