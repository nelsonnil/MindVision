//
//  MetalUniforms.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 10/03/2024.
//

import Foundation
import simd

struct MetalUniforms{
    
    var u_time:Float = 0.0
    var u_res:float2
    var saturation:Float = 1.0
    var focus:Float = 0.1
    var brightness:Float = 0.0
    var rotation:Float = 0.0
    var onCameraView = false
    var sizeBoard:Float = 0
    var imageRotation:Float = 0
}

