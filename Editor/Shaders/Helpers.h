//
//  Helpers.h
//  SparclesDemoApp
//
//  Created by Demian Nezhdanov on 19/09/2023.
//
#include <metal_stdlib>

#ifndef Helpers_h
#define Helpers_h
using namespace metal;
float4x4 brightnessMatrix( float brightness );
float3 saturation(float3 rgb, float adj);
float3 blur(texture2d<float> tex, float2 uv, float r);
float3 rgb2hsv(float3 c);
float3 hsv2rgb(float3 c);

float3 palet(float v );





float saturateF(float x);
float3 highlight(float3 color, float intensity);







float3 screen( float3 s, float3 d );

float2 hash12(float p);
float hash21(float2 p);
float2 rotateUV(float2 uv, float rotation);
float dist(float3 a, float3 b);


float mod(float x, float y);
float2 mod(float2 x, float y);
float3 mod(float3 x, float3 y);


float Hash31( float3 p);

float3 hsl2rgb( float3 c );
float noise( float2 p );
float3 colorNoise( float2 p );

float3 darken(float3 s,float3 d);
float3 multiply(float3 s,float3 d);
float3 colorBurn(float3 s,float3 d);
float3 linearBurn(float3 s,float3 d);
float3 darkerColor(float3 s,float3 d);
float3 lighten(float3 s,float3 d);
float3 screen(float3 s,float3 d);
float3 colorDodge(float3 s,float3 d);
float3 linearDodge(float3 s,float3 d);
float3 lighterColor(float3 s,float3 d);
float3  overlay(float3 s,float3 d);
float3  softLight(float3 s,float3 d);
float3  hardLight(float3 s,float3 d);
float3  vividLight(float3 s,float3 d);
float3  linearLight(float3 s,float3 d);
float3  pinLight(float3 s,float3 d);
float3  hardMix(float3 s,float3 d);
float3  difference(float3 s,float3 d);
float3  exclusion(float3 s,float3 d);
float3  subtract(float3 s,float3 d);
float3  divideBlendMode(float3 s,float3 d);
float3  hue(float3 s,float3 d);
float3  color(float3 s,float3 d);
//float3  saturation(float3 s,float3 d);
float3  luminosity(float3 s,float3 d);

float3 blend( float3 s, float3 d, int mode );

#endif /* Helpers_h */
