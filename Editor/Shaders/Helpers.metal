//
//  AdjustTools.metal
//  SparclesDemoApp
//
//  Created by Demian Nezhdanov on 19/09/2023.
//

#include <metal_stdlib>
using namespace metal;
#import "Helpers.h"
constexpr metal::sampler sam(metal::filter::linear);





//MARK: ADJUSTMENT TOOLS
float4x4 brightnessMatrix( float brightness )
{
    // Map the brightness from range [-1, 1] to appropriate adjustment
    // When brightness is 0, we want no change
    // When brightness is positive, add brightness as before
    // When brightness is negative, we darken by scaling RGB values
    
    float adjustment = brightness;
    
    // For negative brightness, we'll map -1...0 to a scaling factor of 0.5...1
    // For positive brightness, we'll keep the same adding behavior
    if (brightness < 0) {
        // Apply as a multiplier that goes from 0.5 (at -1) to 1.0 (at 0)
        float multiplier = 1.0 + brightness * 0.5; // 1.0 at 0, 0.5 at -1
        return float4x4(
            multiplier, 0, 0, 0,
            0, multiplier, 0, 0,
            0, 0, multiplier, 0,
            0, 0, 0, 1
        );
    } else {
        // Original brightening behavior for 0...1
        return float4x4(
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            adjustment, adjustment, adjustment, 1
        );
    }
}

float3 saturation(float3 rgb, float adj)
{
    const float3 W = float3(0.2125, 0.7154, 0.0721);
    float3 intensity = float3(dot(rgb, W));
    return mix(intensity, rgb, adj);
}
float3 blur(texture2d<float> tex, float2 uv, float r){
    
     float3 blur = float3(0.0);
     float2 res = float2(tex.get_width(),tex.get_height());
         float sum = 0.0;
        //float r = rad;
         for(float u = -r; u<=r; u+=1.){
             for(float v = -r; v<=r; v+=1.){
 
                 float weight = r*10. - sqrt(u * u + v * v);
                // uv + (float2(u, v)/res)
                 blur += weight * tex.sample(sam,uv + (float2(u, v)/res)).rgb;
                 sum += weight;
             }
         }
         blur /= sum;
     
    return blur;
}



float3 rgb2hsv(float3 c)
{
    float4 k = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, k.wz), float4(c.gb, k.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c)
{
    float4 k = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
    return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}



float3 palet(float v ) {
    return (float3(0.26) + tan(1.09)*sin(1.09)*0.26 * cos(3.18318 * (v + float3(0.0,0.333,0.567)))).brg;
}






float saturateF(float x)
{
    return clamp(x, 0.,1.);
}
float3 highlight(float3 color, float intensity)
{
    const float a = 1.357697966704323E-01;
    const float b = 1.006045552016985E+00;
    const float c = 4.674339906510876E-01;
    const float d = 8.029414702292208E-01;
    const float e = 1.127806558508491E-01;
    
    float maxx = max(color.r, max(color.g, color.b));
    float minx = min(color.r, min(color.g, color.b));
    float lum = 0.5 * (maxx + minx);
    float x1 = abs(intensity);
    float x2 = lum;
    float lum_new =  lum < 0.5 ? lum : lum + a * sign(intensity) * exp(-0.5 * (((x1-b)/c)*((x1-b)/c) + ((x2-d)/e)*((x2-d)/e)));
    return color * lum_new / lum;
}
//MARK: ADJUSTMENT TOOLS






//MARK: BLEND MODES
float3 screen( float3 s, float3 d )
{
    return s + d - s * d;
}
float3 darken( float3 s, float3 d )
{
    return min(s,d);
}

float3 multiply( float3 s, float3 d )
{
    return s*d;
}

float3 colorBurn( float3 s, float3 d )
{
    return 1.0 - (1.0 - d) / s;
}

float3 linearBurn( float3 s, float3 d )
{
    return s + d - 1.0;
}

float3 darkerColor( float3 s, float3 d )
{
    return (s.x + s.y + s.z < d.x + d.y + d.z) ? s : d;
}

float3 lighten( float3 s, float3 d )
{
    return max(s,d);
}

float3 colorDodge( float3 s, float3 d )
{
    return d / (1.0 - s);
}

float3 linearDodge( float3 s, float3 d )
{
    return s + d;
}

float3 lighterColor( float3 s, float3 d )
{
    return (s.x + s.y + s.z > d.x + d.y + d.z) ? s : d;
}

float overlay( float s, float d )
{
    return (d < 0.5) ? 2.0 * s * d : 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
}

float3 overlay( float3 s, float3 d )
{
    float3 c;
    c.x = overlay(s.x,d.x);
    c.y = overlay(s.y,d.y);
    c.z = overlay(s.z,d.z);
    return c;
}

float softLight( float s, float d )
{
    return (s < 0.5) ? d - (1.0 - 2.0 * s) * d * (1.0 - d)
        : (d < 0.25) ? d + (2.0 * s - 1.0) * d * ((16.0 * d - 12.0) * d + 3.0)
                     : d + (2.0 * s - 1.0) * (sqrt(d) - d);
}

float3 softLight( float3 s, float3 d )
{
    float3 c;
    c.x = softLight(s.x,d.x);
    c.y = softLight(s.y,d.y);
    c.z = softLight(s.z,d.z);
    return c;
}

float hardLight( float s, float d )
{
    return (s < 0.5) ? 2.0 * s * d : 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
}

float3 hardLight( float3 s, float3 d )
{
    float3 c;
    c.x = hardLight(s.x,d.x);
    c.y = hardLight(s.y,d.y);
    c.z = hardLight(s.z,d.z);
    return c;
}

float vividLight( float s, float d )
{
    return (s < 0.5) ? 1.0 - (1.0 - d) / (2.0 * s) : d / (2.0 * (1.0 - s));
}

float3 vividLight( float3 s, float3 d )
{
    float3 c;
    c.x = vividLight(s.x,d.x);
    c.y = vividLight(s.y,d.y);
    c.z = vividLight(s.z,d.z);
    return c;
}

float3 linearLight( float3 s, float3 d )
{
    return 2.0 * s + d - 1.0;
}

float pinLight( float s, float d )
{
    return (2.0 * s - 1.0 > d) ? 2.0 * s - 1.0 : (s < 0.5 * d) ? 2.0 * s : d;
}

float3 pinLight( float3 s, float3 d )
{
    float3 c;
    c.x = pinLight(s.x,d.x);
    c.y = pinLight(s.y,d.y);
    c.z = pinLight(s.z,d.z);
    return c;
}

float3 hardMix( float3 s, float3 d )
{
    return floor(s + d);
}

float3 difference( float3 s, float3 d )
{
    return abs(d - s);
}

float3 exclusion( float3 s, float3 d )
{
    return s + d - 2.0 * s * d;
}

float3 subtract( float3 s, float3 d )
{
    return s - d;
}

float3 divideBlendMode( float3 s, float3 d )
{
    return s / d;
}


float3 hue( float3 s, float3 d )
{
    d = rgb2hsv(d);
    d.x = rgb2hsv(s).x;
    return hsv2rgb(d);
}

float3 color( float3 s, float3 d )
{
    s = rgb2hsv(s);
    s.z = rgb2hsv(d).z;
    return hsv2rgb(s);
}

//float3 saturation( float3 s, float3 d )
//{
//    d = rgb2hsv(d);
//    d.y = rgb2hsv(s).y;
//    return hsv2rgb(d);
//}

float3 luminosity( float3 s, float3 d )
{
    float dLum = dot(d, float3(0.3, 0.59, 0.11));
    float sLum = dot(s, float3(0.3, 0.59, 0.11));
    float lum = sLum - dLum;
    float3 c = d + lum;
    float minC = min(min(c.x, c.y), c.z);
    float maxC = max(max(c.x, c.y), c.z);
    if(minC < 0.0) return sLum + ((c - sLum) * sLum) / (sLum - minC);
    else if(maxC > 1.0) return sLum + ((c - sLum) * (1.0 - sLum)) / (maxC - sLum);
    else return c;
}





float3 blend( float3 s, float3 d, int mode )
{
    if(mode==0)    return darken(s,d);
    if(mode==1)    return multiply(s,d);
    if(mode==2)    return colorBurn(s,d);
    if(mode==3)    return linearBurn(s,d);
    if(mode==4)    return darkerColor(s,d);
    if(mode==5)    return lighten(s,d);
    if(mode==6)    return screen(s,d);
    if(mode==7)    return colorDodge(s,d);
    if(mode==8)    return linearDodge(s,d);
    if(mode==9)    return lighterColor(s,d);
    if(mode==10)    return overlay(s,d);
    if(mode==11)    return softLight(s,d);
    if(mode==12)    return hardLight(s,d);
    if(mode==13)    return vividLight(s,d);
    if(mode==14)    return linearLight(s,d);
    if(mode==15)    return pinLight(s,d);
    if(mode==16)    return hardMix(s,d);
    if(mode==17)    return difference(s,d);
    if(mode==18)    return exclusion(s,d);
    if(mode==19)    return subtract(s,d);
    if(mode==20)    return divideBlendMode(s,d);
    if(mode==21)    return hue(s,d);
    if(mode==22)    return color(s,d);
//    if(mode==23)    return saturation(s,d);
    if(mode==24)    return luminosity(s,d);
    
    return float3(0.0);
}
//https://www.shadertoy.com/view/XdS3RW




//MARK: BLEND MODES












//MARK: GEOMETRY
float point(float2 pos, float2 uv, float2 res){
    uv -= pos;
    uv.y /= res.x/res.y;
  
    float d = length(uv);
    d = smoothstep(0.25, 0.0, d)/34.;
    return d;
}
//MARK: GEOMETRY















float hashh21(float2 p)  // replace this by something better
{
    p  = 50.0*fract( p*0.3183099 + float2(0.71,0.113));
    return -1.0+2.0*fract( p.x*p.y*(p.x+p.y) );
}

//MARK: MATH
float hash21(float2 p) {
    return fract(sin(dot(p.xy,
                         float2(12.9898,78.233)))*
        43758.5453123);
}

float2 hash12(float p) //1 in 2 out hash function
{
    float3 p3 = fract(float3(p) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx+p3.yz)*p3.zy) * 2. - 1.;

}
float2 rotateUV(float2 uv, float rotation)
{
    return float2(
        cos(rotation) * uv.x + sin(rotation) * uv.y,
        cos(rotation) * uv.y - sin(rotation) * uv.x
    );
}
float dist(float3 a, float3 b) { return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z); }


float mod(float x, float y) {
    return x - y * floor(x / y);
}
float2 mod(float2 x, float y){
    return x - y * floor(x/y);
}
float3 mod(float3 x, float3 y){
    return x - y * floor(x/y);
}



float Hash31( float3 p) {
     return fract(937.276 * cos(836.826 * p.x + 263.736 * p.y + 374.723 * p.z + 637.839));
}


float3 hsl2rgb( float3 c ){
    float3 rgb = clamp( abs(mod(c.x*6.0+float3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0,1.0);
    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}




//MARK: MATH
float noise( float2 p )
{
    
    float2 i = floor( p );
    float2 f = fract( p );
    float2 u = f*f*(3.0-2.0*f);
    return mix( mix(hashh21( i + float2(0.0,0.0) ),
                    hashh21( i + float2(1.0,0.0) ), u.x),
                mix(hashh21( i + float2(0.0,1.0) ),
                    hashh21( i + float2(1.0,1.0) ), u.x), u.y)*0.5 + 0.5;

}

float perlinNoise(float2 uv){
    float2x2 m = float2x2( 1.6,  1.2, -1.2,  1.6 );
   float f  = 0.5000*noise( uv ); uv = m*uv;
    f += 0.2500*noise( uv ); uv = m*uv;
    f += 0.1250*noise( uv ); uv = m*uv;
    f += 0.0625*noise( uv ); uv = m*uv;
    return f;
}

float3 colorNoise( float2 p )
{
    
    float r = perlinNoise(p*1.1);
    float g = perlinNoise(p);
    float b = perlinNoise(p*1.2);
    
    
    
    
    
    return float3(r,g,b);
}