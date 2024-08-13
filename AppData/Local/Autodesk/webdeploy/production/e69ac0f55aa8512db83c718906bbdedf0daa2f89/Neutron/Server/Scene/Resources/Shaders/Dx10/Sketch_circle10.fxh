#ifndef _HQ_FX_CIRCLE_H__
#define _HQ_FX_CIRCLE_H__

#include "Sketch_circle_ellipse10.fxh"

// adjust closed circle according to bounding box of circle
void adjust_closed_circle(inout EllipseAttr_Dash attr)
{
    float bounds_min_x = round(attr.center.x - attr.radius.x);
    float bounds_min_y = round(attr.center.y - attr.radius.y);
    float bounds_max_x = round(attr.center.x + attr.radius.x);
    float bounds_max_y = round(attr.center.y + attr.radius.y);

    attr.center.x = (bounds_min_x + bounds_max_x) / 2.0f;
    attr.center.y = (bounds_min_y + bounds_max_y) / 2.0f;
    attr.radius.x = (bounds_max_x - bounds_min_x + bounds_max_y - bounds_min_y) / 4.0f;
    attr.radius.y = attr.radius.x;
}

// adjust circle arc based on "three points not in a line can determine a circle"
// please refer to https://wiki.autodesk.com/display/AGS/Maestro+Analytic+Curve+Precision.
void adjust_circle_arc(inout EllipseAttr_Dash attr)
{
    float2 old_center = attr.center.xy;
    // calculate start point, end point and middle point.
    float s1, c1;
    sincos(attr.rotate + attr.range.x, s1, c1);
    float x_start = round(attr.center.x + attr.radius.x * c1);
    float y_start = round(attr.center.y + attr.radius.y * s1);
    sincos(attr.rotate + attr.range.y, s1, c1);
    float x_end = round(attr.center.x + attr.radius.x * c1);
    float y_end = round(attr.center.y + attr.radius.y * s1);
    sincos(attr.rotate + (attr.range.x + attr.range.y) / 2, s1, c1);
    float x_middle = round(attr.center.x + attr.radius.x * c1);
    float y_middle = round(attr.center.y + attr.radius.y * s1);

    // if start point is equal to or very near to end point, adjust this arc as closed circle.
    if ((x_start == x_end && y_start == y_end)
        || distance(float2(x_start + x_middle - 2 * x_end, y_start + y_middle - 2 * y_end), float2(0.0f, 0.0f)) < 0.35f)
    {
        adjust_closed_circle(attr);
        return;
    }

    // if the difference of start angle and end angle is less than PI/4, then adjust this arc as elliptical arc.
    float range = attr.range.y - attr.range.x;
    range = range - int(range / (TWO_PI)) * TWO_PI;
    range = TWO_PI - range;
    if (range < QUART_PI)
    {
        adjust_elliptical_arc(attr);
        return;
    }

    // calculate new range and center based on "three points not in a line can determine a circle"
    float A = 2 * ((x_start - x_middle) * (y_end - y_middle) - (x_end - x_middle) * (y_start - y_middle));
    float B = ((x_start * x_start + y_start * y_start) - (x_middle * x_middle + y_middle * y_middle)) / A;
    float C = ((x_end * x_end + y_end * y_end) - (x_middle * x_middle + y_middle * y_middle)) / A;

    attr.center.x = B * (y_end - y_middle) - C * (y_start - y_middle);
    attr.center.y = -B * (x_end - x_middle) + C * (x_start - x_middle);
    attr.radius.x = distance(attr.center, float2(x_end, y_end));
    attr.radius.y = attr.radius.x;
    attr.rotate = 0.0;

    float adjust_angle = min(0.25f / attr.radius.x, 0.01f);
    attr.range.x = get_circle_arc_angle(attr.center.x, attr.center.y, x_start, y_start, attr.radius.x) - adjust_angle;
    attr.range.y = get_circle_arc_angle(attr.center.x, attr.center.y, x_end, y_end, attr.radius.x) + adjust_angle;

    float2 middle = float2(x_middle, y_middle);
    float2 to_old_center = normalize(old_center - middle);
    float2 to_new_center = normalize(attr.center.xy - middle);
    float dot_old_new = dot(to_old_center, to_new_center);
    if (dot_old_new < 0.0f)
    {
        float t = attr.range.y;
        attr.range.y = attr.range.x;
        attr.range.x = t;
    }   

    if (attr.range.y < attr.range.x)
        attr.range.y += TWO_PI;
}

// adjust circle for precision. Don't need to do adjustment in logic CS since this circle is represented with float type
// and is precise.
void adjust_circle(inout EllipseAttr_Dash attr)
{
    if (!attr.isLogical)
    {
        if (is_closed_arc(attr.range))
            adjust_closed_circle(attr);
        else
            adjust_circle_arc(attr);

        updateOffset(attr.center);
    }
}

#endif
