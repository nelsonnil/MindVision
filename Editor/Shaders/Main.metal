//
//  Main.metal
//  SparclesDemoApp
//
//  Created by Demian Nezhdanov on 20/07/2023.
//

#include <metal_stdlib>
#import "Common.h"

using namespace metal;


float2 reduceAspectRatio(float2 uv, float2 source_res,float2 main_resolution){
    float aspectMain = main_resolution.y/main_resolution.x;
    float aspectSource = source_res.y/source_res.x;

            if(aspectSource >= aspectMain){
                uv -= 0.5;
                uv.x *= aspectSource;
                uv.x /= aspectMain;
                uv += 0.5;
            }else{
                uv -= 0.5;
                uv.y /= aspectSource;
                uv.y *= aspectMain;
                uv += 0.5;
            }
//
    return uv;
}



vertex VertexOut vertex_shader(constant VertexIn* vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]]) {
     
     VertexIn vertexData = vertexArray[vid];
     VertexOut vertexDataOut;
     vertexDataOut.position = float4(vertexData.position.x, vertexData.position.y, 0.0, 1.0);
     vertexDataOut.textureCoorinates = vertexData.textureCoorinates.xy;
     return vertexDataOut;
}






fragment float4 main_fragment(VertexOut fragmentIn [[stage_in]],
                      texture2d<float, access::sample> video [[texture(0)]],
                      texture2d<float, access::sample> cvTexture [[texture(1)]],
                              texture2d<float, access::sample> layerTexture [[texture(2)]],
                              constant bool &orientation [[buffer(10)]],
                              constant MetalUniforms &values [[buffer(12)]]) {
     
     constexpr sampler sam(mag_filter::linear, min_filter::linear);
     
     float2 res = float2(video.get_width(),video.get_height());
    float2 resMap = float2(cvTexture.get_width(),cvTexture.get_height());
     float2 uv = fragmentIn.textureCoorinates;
   
    if (!values.onCameraView){
//        uv = uv.yx;
//        uv = float2(uv.x, 1.0 - uv.y);
    }
//    uv = float2(uv.x, 1.0 - uv.y);
    float2 first_uv = reduceAspectRatio(uv, resMap, res);
    if(values.rotation != 0.0){
        uv -= 0.5;
        uv = rotateUV(uv, values.rotation);
        uv += 0.5;
    }
    
    
    
    


    float4 videoC = video.sample(sam,  uv);//fastBloom(uv.xy*res,res.xy,tex) + blur(tex, uv, 2.);
    uv.y = 1.0 - uv.y;
    float4 overlayColor = cvTexture.sample(sam,  uv);
    float3 cvColor = mix(overlayColor.rgb,blur(cvTexture,uv,values.focus * 5),values.focus);// cvTexture.sample(sam,  uv);
    float a = (cvColor.r + overlayColor.b + overlayColor.g)/3;
    float alpha = overlayColor.a;
    if((overlayColor.g == 1.0)&&
       (overlayColor.r == 0.0)&&
       (overlayColor.b == 0.0)){
        return float4(videoC);
    }
    if((alpha > 0.01)){
        
        cvColor = saturation(cvColor,values.saturation);
        
        cvColor = (brightnessMatrix(values.brightness) * float4(cvColor, 1.0)).rgb;
        
        videoC.rgb = cvColor;
    }
//    videoC.rgb *= 1.0 - cvColor.rgb;
//    videoC.rgb += cvColor.rgb;
//    videoC = float3(0.5,0.2,1.0);
     return float4(videoC);
   
}
