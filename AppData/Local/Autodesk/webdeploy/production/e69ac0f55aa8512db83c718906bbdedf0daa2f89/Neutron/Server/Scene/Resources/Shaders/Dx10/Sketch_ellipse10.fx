#include "Sketch_ellipse10.fxh"

// ellipse primitive texture
Texture2D<uint>  gEllipseIndexTex : EllipseIndexTexture;
Texture2D<float> gEllipticalArcDashDrawOrderZTex : EllipticalArcDashDrawOrderZTex;

// get primitive id
uint load_ellipse_prim_id(uint id)
{
    return load_prim_id_from_tex(gEllipseIndexTex, id);
}

VertexAttr_Ellipse Ellipse_Dash_VS(NullVertex_Input input)
{
    // load primitive index
    uint primID = load_ellipse_prim_id(input.InstanceID);

    // load ellipse information
    EllipseAttr_Dash ellipse_attr;
    load_ellipse_info(primID, ellipse_attr);

    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(input.InstanceID, gEllipticalArcDashDrawOrderZTex, ellipse_attr.drawZ);
    }
    else
    {
        adjust_ellipse(ellipse_attr);
    }

    return output_vertex_attr_ellipse(input, ellipse_attr);
}

OIT_PS_HEADER(Ellipse_Dash_PS, VertexAttr_Ellipse)
{
    float dist = ellipse_distance(input.radius, input.uv);

    if (!valid_range_ellipse(input.radius, input.uv, input.range, dist))
        discard;

    float width = adjust_line_width_wide_line(input.weight);
    float4 color;

    [branch] if (gNoAAMode != 0)
    {
#ifdef ANALYTIC_HIGHLIGHT
        if (!in_lw_ellipse(input.weight, dist) && not_in_ellipse(input))
            discard;

        bool in_sharp = in_lw_ellipse(width, dist) || !not_in_ellipse(input);
        color = compute_highlight_sharp_color(dist, width, input.color, input.glowColor, in_sharp);
#else
        if (!in_lw_ellipse(width, dist) && not_in_ellipse(input))
            discard;

        color = get_formatted_color(input.color, 1.0f);
#endif
    }
    else
    {
        color = compute_final_color(dist, width, input.color, input.glowColor);
    }

    OIT_PS_OUTPUT(color, input.position);
}

technique11 Ellipse_Dash
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Ellipse_Dash_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Ellipse_Dash_PS()));
    }
}

