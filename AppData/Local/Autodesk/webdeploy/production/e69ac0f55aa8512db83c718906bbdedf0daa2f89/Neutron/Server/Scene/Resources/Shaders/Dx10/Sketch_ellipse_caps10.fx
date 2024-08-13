#include "Sketch_ellipse_caps10.fxh"
#include "Sketch_ellipse10.fxh"

// ellipse caps primitive texture
Texture2D<uint>  gCapsIndexTex : CapsIndexTexture;
Texture2D<float> gEllipticalArcCapsDrawOrderZTex : EllipticalArcCapsDrawOrderZTex;

// load caps primitive id
uint load_caps_prim_id(uint id)
{
    return load_prim_id_from_tex(gCapsIndexTex, id);
}

VertexAttr_Caps Ellipse_Caps_VS(NullVertex_Input input)
{
    // load primitive index
    uint primID = load_caps_prim_id(input.InstanceID);

    // load ellipse information
    EllipseAttr_Dash ellipse_attr;
    load_ellipse_info(primID, ellipse_attr);

    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(input.InstanceID, gEllipticalArcCapsDrawOrderZTex, ellipse_attr.drawZ);
    }
    else
    {
        adjust_caps(ellipse_attr);
    }

    // initialize
    VertexAttr_Caps output = (VertexAttr_Caps)0;

    // update geometry info
    float2 center = float2(ellipse_attr.center.x, ellipse_attr.center.y);
    output.range = ellipse_attr.range;

    float2 adjusted_radius = ellipse_attr.radius;

    [branch] if (gRetainMode)
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
            if (ellipse_attr.radius.x == 0) adjusted_radius.x = 1.0f;
            if (ellipse_attr.radius.y == 0) adjusted_radius.y = 1.0f;
        }
    }

    output.radius = adjusted_radius;

    float sin_rot, cos_rot;
    sincos(ellipse_attr.rotate, sin_rot, cos_rot);

    // expand range when have line weight
    float weight_expand = get_screen_weight_expand(ellipse_attr.weight);

    // get the radius
    output.position.xy = get_vertex_pos_caps(input.VertexID, output.range, output.radius.x, output.radius.y,
        weight_expand, center, sin_rot, cos_rot, output.uv, output.ref);

    // update other properties
    output.weight = ellipse_attr.weight;
    output.position.z = ellipse_attr.drawZ;
    output.position.xyz = output.position.xyz;
    output.position.w = 1.0f;

    output.color = ellipse_attr.color; // move color assignment to last will fix an Intel compiler issue.
                                        // since the color assignment will affect position result on Intel cards.

    output.glowColor = ellipse_attr.glowColor;

    output.capType = ellipse_attr.capType;

    return output;
}

bool valid_range_caps(VertexAttr_Caps input)
{
    if (abs(input.radius.x - input.radius.y) < EPS)
        return valid_range(input.radius, input.uv, input.range);
    else
    {
        float dist = ellipse_distance(input.radius, input.uv);
        return valid_range_ellipse(input.radius, input.uv, input.range, dist);
    }
}

OIT_PS_HEADER(Ellipse_Caps_PS, VertexAttr_Caps)
{
    float2 delta = input.uv - input.ref.xy;
    float dis_to_ref = length(delta);
    float dis_to_border = dot(delta, input.ref.zw);
    float abs_dis_to_border = abs(dis_to_border);

    if (close_to_caps_border(abs_dis_to_border))// if close to border
    {
        if (valid_range_caps(input)) // if inside ellipse
            discard;
    }
    float dist = abs(dis_to_ref);

    float width = adjust_line_width_wide_line(input.weight);

    float4 color;
    [branch] if (gNoAAMode != 0)
    {
        color = compute_sharp_caps_final_color(dist, width, input.color, input.glowColor,
            input.uv, input.ref.xy, input.ref.zw, input.capType);
    }
    else
    {
        color = compute_caps_final_color(dist, width, input.color, input.glowColor,
            input.uv, input.ref.xy, input.ref.zw, input.capType);
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Ellipse_Caps
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Ellipse_Caps_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Ellipse_Caps_PS()));
    }
}

