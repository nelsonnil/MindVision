//
//  Common.h
//  SparclesDemoApp
//
//  Created by Demian Nezhdanov on 20/07/2023.
//
#import "Helpers.h"
#ifndef Common_h
#define Common_h


constexpr metal::sampler sam(metal::filter::linear);

struct MetalUniforms{
    
    float u_time = float(0);
    float2 res = float2(1080,1920);
    
    float saturation = 1.0;
    float focus = 1.0;
    float brightness = 0.5;
    float rotation = 0.0;
    bool onCameraView = false;
};



struct VertexIn {
    float2 position [[attribute(0)]];
    float2 textureCoorinates [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoorinates;
};






#endif /* Vertecies_h */


