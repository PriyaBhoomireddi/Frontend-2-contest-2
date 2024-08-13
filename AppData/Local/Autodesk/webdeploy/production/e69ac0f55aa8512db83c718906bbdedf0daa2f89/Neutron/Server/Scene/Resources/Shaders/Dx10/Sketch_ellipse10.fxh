#ifndef _HQ_FX_ELLIPSE_H__
#define _HQ_FX_ELLIPSE_H__

#include "Sketch_circle_ellipse10.fxh"

// adjust closed ellipse according to the intersection points between ellipse and two axises
// please refer to https://wiki.autodesk.com/display/AGS/Maestro+Analytic+Curve+Precision.
void adjust_closed_ellipse(inout EllipseAttr_Dash attr)
{
    float s1, c1;
    sincos(attr.rotate, s1, c1);

    float s2 = s1 * s1;
    float c2 = c1 * c1;
    float sc = s1 * c1;

    float x_axis_c = attr.radius.x * c1;
    float x_axis_s = attr.radius.x * s1;
    float x_axis_x1 = round(attr.center.x + x_axis_c);
    float x_axis_y1 = round(attr.center.y + x_axis_s);
    float x_axis_x2 = round(attr.center.x - x_axis_c);
    float x_axis_y2 = round(attr.center.y - x_axis_s);

    float y_axis_c = attr.radius.y * -s1;
    float y_axis_s = attr.radius.y * c1;
    float y_axis_x1 = round(attr.center.x + y_axis_c);
    float y_axis_y1 = round(attr.center.y + y_axis_s);
    float y_axis_x2 = round(attr.center.x - y_axis_c);
    float y_axis_y2 = round(attr.center.y - y_axis_s);

    float x_axis_x12 = x_axis_x1 + x_axis_x2;
    float y_axis_x12 = y_axis_x1 + y_axis_x2;
    float x_axis_y12 = x_axis_y1 + x_axis_y2;
    float y_axis_y12 = y_axis_y1 + y_axis_y2;

    attr.center.x = (s2 * y_axis_x12 + c2 * x_axis_x12 + sc * (x_axis_y12 - y_axis_y12)) / 2.0f;
    attr.center.y = (s2 * x_axis_y12 + c2 * y_axis_y12 + sc * (x_axis_x12 - y_axis_x12)) / 2.0f;

    attr.radius.x = abs(c1 * (x_axis_x2 - x_axis_x1) + s1 * (x_axis_y2 - x_axis_y1)) / 2.0f;
    attr.radius.y = abs(s1 * (y_axis_x2 - y_axis_x1) - c1 * (y_axis_y2 - y_axis_y1)) / 2.0f;
}

float ellipse_distance(float2 radius, float2 uv)
{
    // compute distance to ellipse
    float x_len = radius.x;
    float y_len = radius.y;

    float a = uv.x / x_len;
    float b = uv.y / y_len;

    float2 dx = ddx(uv);
    float2 dy = ddy(uv);

    float x_len_2 = x_len*x_len;
    float y_len_2 = y_len*y_len;

    float x_2 = uv.x*uv.x;
    float y_2 = uv.y*uv.y;

    float dfx = (2 * uv.x) / x_len_2 * dx.x + (2 * uv.y) / y_len_2 * dx.y;
    float dfy = (2 * uv.x) / x_len_2 * dy.x + (2 * uv.y) / y_len_2 * dy.y;

    float dist = 0.0f;
    float df_2 = dfx * dfx + dfy * dfy;

    if (df_2 > 0.0f)
        dist = (x_2 / x_len_2 + y_2 / y_len_2 - 1) * rsqrt(df_2);

    return abs(dist);
}

float get_ajusted_ellipse_angle(float2 radius, float2 uv, float dist)
{
    // get cur angle
    float x_len = radius.x;
    float y_len = radius.y;

    float cur_angle = atan2(uv.y / y_len, uv.x / x_len);

    if (cur_angle < 0)
        cur_angle = cur_angle + TWO_PI;


    float sin_angle = sin(cur_angle);
    float cos_angle = cos(cur_angle);

    // get ellipse point
    float2 e_point;
    e_point.x = radius.x*cos_angle;
    e_point.y = radius.y*sin_angle;

    float2 delta = uv - e_point;
    float delta_len = length(delta);

    if (delta_len < EPS) // if on ellipse
        return cur_angle;

    float2 delta_dir = delta / delta_len;

    // get ellipse point tangent
    float2 e_tan;
    e_tan.x = -radius.x*sin_angle;
    e_tan.y = radius.y*cos_angle;
    e_tan = normalize(e_tan);

    float dist_tan = dot(delta, e_tan);

    if (abs(dist_tan) < EPS)
        return cur_angle;


    float2 new_point = e_point + e_tan*(dist_tan);


    float new_cur_angle = atan2(new_point.y / y_len, new_point.x / x_len);

    if (new_cur_angle < 0)
        new_cur_angle = new_cur_angle + TWO_PI;

    return new_cur_angle;

}

// adjust ellipse for precision. don't need to do adjustment in logic CS since this ellipse is
// represented with float type and is precise.
void adjust_ellipse(inout EllipseAttr_Dash attr)
{
    if (!attr.isLogical)
    {
        if (is_closed_arc(attr.range))
            adjust_closed_ellipse(attr);
        else
            adjust_elliptical_arc(attr);

        updateOffset(attr.center);
    }
}

bool valid_range_ellipse(float2 radius, float2 uv, float2 range, float dist)
{
    float cur_angle = get_ajusted_ellipse_angle(radius, uv, dist);

    return angle_is_in_range(cur_angle, range);
}

#endif
