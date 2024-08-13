#ifndef _HQ_FX_MATH_HEADER__
#define _HQ_FX_MATH_HEADER__

static const float EPS = 0.000001f;
static const float PI = 3.141592653589793f;
static const float HALF_PI = PI*0.5f;
static const float ONE_HALF_PI = PI*1.5f;
static const float QUART_PI = PI*0.25f;
static const float TWO_PI = PI*2.0f;

// gauss_blur for anti-aliasing lines in acad.
// the sigma/theta are tuned by PD.
float gauss_blur(float dist, float weight, float theta, float sigma)
{
    float adjust_sigma = (0.02*sigma);
    float sigma_2 = -adjust_sigma*adjust_sigma*0.5f;

    float  adjust_theta = theta*0.01f + 1.0f;

    float amt;
    amt = dist - (weight - 1.0f)*0.5f;
    amt = max(0.0f, amt);

    return (adjust_theta*exp(amt*amt / sigma_2));
}

// compute distance from pixel to a line in screen space
float dist_pixel_to_line(float2 curPoint, float2 lineDir, float2 lineStartPoint)
{
    float2 delta = curPoint - lineStartPoint;
    return lineDir.x*delta.y - lineDir.y*delta.x;
}

// compute absolute distance from pixel to a line in screen space
float abs_dist_pixel_to_line(float2 curPoint, float2 lineDir, float2 lineStartPoint)
{
    return abs(dist_pixel_to_line(curPoint, lineDir, lineStartPoint));
}

float2 get_unit_pos(uint vid)
{
    uint a = vid & 0x1;
    uint b = (vid & 0x2) >> 1;

    return float2(a, b);
}

float2 get_rect_pos(uint vid)
{
    float2 unit_pos = get_unit_pos(vid);

    return float2(unit_pos.x*2.0f - 1.0f, unit_pos.y*2.0f - 1.0f);
}

#endif

