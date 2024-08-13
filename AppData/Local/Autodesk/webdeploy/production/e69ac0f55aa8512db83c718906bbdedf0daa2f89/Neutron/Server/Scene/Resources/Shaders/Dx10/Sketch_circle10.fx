#include "Sketch_circle10.fxh"

// circle primitive index texture
Texture2D<uint>   gCircleIndexTex : CircleIndexTexture;
Texture2D<float>  gCircleArcDashDrawOrderZTex : CircleArcDashDrawOrderZTex;

// load primitive id
uint load_circle_prim_id(uint id)
{
    return load_prim_id_from_tex(gCircleIndexTex, id);
}

VertexAttr_Ellipse Circle_Dash_VS(NullVertex_Input input)
{
    // load primitive index
    uint primID = load_circle_prim_id(input.InstanceID);

    // load ellipse information
    EllipseAttr_Dash ellipse_attr;
    load_ellipse_info(primID, ellipse_attr);

    [branch] if (gRetainMode)
    {
        load_dynamic_draworderz(input.InstanceID, gCircleArcDashDrawOrderZTex, ellipse_attr.drawZ);
    }
    else
    {
        adjust_circle(ellipse_attr);
    }

    adjust_circle_range(ellipse_attr.range, ellipse_attr.rotate);

    return output_vertex_attr_ellipse(input, ellipse_attr);
}

bool valid_range_circle(VertexAttr_Ellipse input)
{
    return valid_range(input.radius, input.uv, input.range);
}
float circle_distance(VertexAttr_Ellipse input)
{
    return abs(sqrt(input.uv.x * input.uv.x + input.uv.y * input.uv.y) - input.radius.x);
}

OIT_PS_HEADER(Circle_Dash_PS, VertexAttr_Ellipse)
{
    if (!valid_range_circle(input))
        discard;

    float width = adjust_line_width_wide_line(input.weight);
    float dist = circle_distance(input);

    float4 color;

    [branch] if (gNoAAMode != 0)
    {
#ifdef ANALYTIC_HIGHLIGHT
        if (not_in_circle(input, input.weight))
            discard;

        bool in_sharp = !not_in_circle(input, width);
        color = compute_highlight_sharp_color(dist, width, input.color, input.glowColor, in_sharp);
#else
        if (not_in_circle(input, width))
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

technique11 Circle_Dash
{
    pass P0
    {
        SetVertexShader(CompileShader(vs_5_0, Circle_Dash_VS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(ps_5_0, Circle_Dash_PS()));
    }
}

