//
//  OpenCV.swift
//  FaceBodyTools
//
//  Created by Demian Nezhdanov on 08/07/2023.
//


import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import UIKit
import simd
import SceneKit

public struct ArucoData{
    public var image:UIImage
    public var id:Int
    public var position:float3
    public var rotation:float3
    public var size:float3
}

public class CVProccessor{
    
    
    public init(){}
    
    
    static var firstFrame = true
    
    
    static func resize(mtlTexture: MTLTexture,minSize:CGSize) -> UIImage?{
    
    if let image = CIImage(mtlTexture: mtlTexture){
        let scale = CGAffineTransform(scaleX: 480 / image.extent.size.width, y: 640 / image.extent.size.height)
        let resizedImage = image.transformed(by: scale)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(resizedImage, from: resizedImage.extent) else { return nil}
        
        let finalImage = UIImage(cgImage: cgImage)
        return finalImage
    }else{
        return nil
    }
}
    
    static func resizeAcuro(mtlTexture: MTLTexture) -> UIImage?{
    
    if let image = CIImage(mtlTexture: mtlTexture){
        let scale = CGAffineTransform(scaleX: 0.5, y: 0.5)
        let resizedImage = image.transformed(by: scale)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(resizedImage, from: resizedImage.extent) else { return nil}
        
        let finalImage = UIImage(cgImage: cgImage)
        return finalImage
    }else{
        return nil
    }
}
    
    public static func arucoDetection(rotationValue:Float, boardSize:Float, boardSizeY:Float, displacementX:Float, displacementY:Float, textDisplacementX:Float, textDisplacementY:Float, inputImg:UIImage, overlayImage:UIImage, textImage:UIImage, color:UIColor, redThreshold:Float, greenThreshold:Float, blueThreshold:Float, frameColor:UIColor, frameWidth:Float, blurSize:Float = 21.0) -> ArucoData{
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        var rf: CGFloat = 0, gf: CGFloat = 0, bf: CGFloat = 0, af: CGFloat = 0
        frameColor.getRed(&rf, green: &gf, blue: &bf, alpha: &af)
        
        let image = CVDetectionBridge().arucoDetection(with: inputImg,secondImage: overlayImage, imageText: textImage, boardSize: boardSize, boardSizeY: boardSizeY, rotationValue: rotationValue, displacementX: displacementX, displacementY: displacementY, textDisplacementX:textDisplacementX, textDisplacementY: textDisplacementY, red: Int32(r*255), green: Int32(g*255), blue: Int32(b*255), redT: Int32(redThreshold), greenT: Int32(greenThreshold), blueT: Int32(blueThreshold), frameRed: Int32(rf*255), frameGreen: Int32(gf*255), frameBlue: Int32(bf*255), frameWidth: frameWidth, blurSize: Int32(blurSize))!
        let data = ArucoData(image: image, id: 0, position: float3(0,0,0), rotation: float3(0,0,0), size: float3(0,0,0))
        return data
    }
    
    static func textureToUiimage(mtlTexture: MTLTexture) -> UIImage?{
    
    if let image = CIImage(mtlTexture: mtlTexture){
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil}
        
        let finalImage = UIImage(cgImage: cgImage)
        return finalImage
    }else{
        return nil
    }
}
    
    static func textureToUiimage(mtlTexture: MTLTexture, _ threshold:Float) -> UIImage?{
            
    if let image = CIImage(mtlTexture: mtlTexture){
        let exposureAdjust = CIFilter(name: "CIExposureAdjust")
        exposureAdjust?.setValue(image, forKey: kCIInputImageKey)
        exposureAdjust?.setValue(threshold/5, forKey: kCIInputEVKey)
        let filtered = exposureAdjust!.outputImage!

        
        let flippedImage = filtered.transformed(by: CGAffineTransform(scaleX: 1, y: -1)).transformed(by: CGAffineTransform(translationX: 0, y: filtered.extent.height))
        
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(flippedImage, from: flippedImage.extent) else { return nil}

        
        let finalImage = UIImage(cgImage: cgImage)
        return finalImage
    }else{
        return nil
    }
}
    
    public static func processImg(uiimg:UIImage) -> CIImage?{
        
        let newOutput = CIImage(image: uiimg)!
//      let outputImage = newOutput.oriented(CGImagePropertyOrientation(uiimg.imageOrientation))
        return newOutput
     }
}


extension Float{
    
    static func dist(_ a:float2,_ b:float2) -> Float{
        
        let d:Float = sqrt(pow((a.x - b.x), 2) + pow(a.y - b.y , 2))
        
        
        
        return d
    }
    static func dist(_ a:Float,_ b:Float) -> Float{
        
        let d:Float = sqrt(pow((a - b), 2) )
        
        
        
        return d
    }
    
}
public extension MTLTexture{
    
    func getColor(x: CGFloat, y: CGFloat) -> float3? {

         
            var pixel: [CUnsignedChar] = [0, 0, 0, 0]  // bgra
        

        let bytesPerRow = self.width * 4
            let y =  y
        try! self.getBytes(&pixel, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(Int(x - 1), Int(Int(y - 1) ), 1, 1), mipmapLevel: 0)
                    let red = Float(pixel[2]) / 255.0
                    let green = Float(pixel[1]) / 255.0
                    let blue = Float(pixel[0]) / 255.0
                    let alpha = Float(pixel[3]) / 255.0
                    let color = float3(red, green, blue)
                    return color
        }
    
    
    public var size:CGSize{
        
        return CGSize(width: width, height: height)
    }
}



