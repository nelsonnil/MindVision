//
//  MainViewController.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 08/03/2024.
//

import AVFoundation
import MetalKit
import SwiftUI
import Photos
import os
import PranaCamKit

//
import UIKit


enum Mode: String, CaseIterable {
    case capture = "Photo"
    case preview = "Video"
    case recording = "Recording"

}

public enum FrameFormat: String, CaseIterable {
    case photo = "3:4"
    case hd = "16:9"
    case square = "1:1"
    
    mutating func next() {
        let allCases = type(of: self).allCases
        let currentIndex = allCases.firstIndex(of: self)!
        let nextIndex = allCases.index(after: currentIndex)
        self = allCases[nextIndex == allCases.endIndex ? allCases.startIndex : nextIndex]
    }
    
    mutating func previous() {
        let allCases = type(of: self).allCases
        let currentIndex = allCases.firstIndex(of: self)!
        let previousIndex = allCases.index(before: currentIndex)
        self = allCases[previousIndex == allCases.startIndex ? allCases.index(before: allCases.endIndex) : previousIndex]
    }
}
class Layer{
    
    var text:String = "text"
    var font:String = "Menlo-Regular"
    var size:Int = 12
    var position:float2 = float2(x: 0.0, y: 0.0)
    var rotation:Float = 0.0
    var uilabel:UILabel = UILabel(frame: .zero)
    
    
    var imageView:UIImageView = UIImageView(frame: .zero)
    var imageTextView:UIImageView = UIImageView(frame: .zero)
    
    var overlayImage:UIImage!
    var textImage:UIImage!
    
    public func setup(image: UIImage, text: String = "text", color: UIColor, font: String, fontSize: Int, textFrameSize: CGSize) {
        
        self.font = font
        //textImage
        imageTextView = UIImageView(frame: CGRect(origin: .zero, size: textFrameSize))
        uilabel = UILabel(frame: imageTextView.frame)
        uilabel.text = text
        uilabel.font = UIFont(name: font, size: CGFloat(fontSize))
        uilabel.textColor = color
        uilabel.textAlignment = .center
        
        // Allow text to overflow and wrap
        uilabel.numberOfLines = 0
        uilabel.lineBreakMode = .byWordWrapping
        
        uilabel.center = CGPoint(x: imageTextView.center.x + CGFloat(position.x) * imageTextView.center.x,
                                 y: imageTextView.center.y + CGFloat(position.y) * imageTextView.center.y)
        imageTextView.addSubview(uilabel)
        textImage = imageTextView.createImage()
        
        //coverImage
        overlayImage = image
    }

    
    public func update(pos:float2){
        position = pos
        uilabel.center = CGPoint(x:imageTextView.center.x + CGFloat(position.x) * imageTextView.center.x ,
                                 y:imageTextView.center.y + CGFloat(position.y) * imageTextView.center.y )
        print("uilabel.center")
        print(uilabel.center)
        textImage = imageTextView.createImage()
    }
    
    // ========= HERE =========
    public func update(size:CGFloat){
        uilabel.font = UIFont(name: self.font, size: size)
        textImage = imageTextView.createImage()
    }
    
    public func update(rotation:CGFloat){
        uilabel.transform = CGAffineTransform(rotationAngle: rotation)
        textImage = imageTextView.createImage()
    }
}

class MainViewController: ObservableObject, PlaybackPixelBufferDelegate, PCameraDelegate{

    deinit{
        
        print("MainViewController removed")
        
    }

    
    public var uilabel:UILabel = UILabel()
    public var mode:Mode = .capture
    public var layerVal = Layer()
    public var layer :Layer {
        get{
            return layerVal
        }
        set(val){
            layerVal = val
            
            metal.overlayImage1 = layerVal.overlayImage
            metal.overlayImage2 = layerVal.textImage
        }
    }
    @Published  var metal : MTLRenderer = MTLRenderer()
    public var camera: PVCaptureManager!
    
    public var victr: ViTRecorder!
    
    @Published var cameraPermissionGranted = false

    public var avReader:VAssetReader?
    
    @Published var isRecording = false
    public var sourceVideoUrl:URL?
    public var recording:Bool{
        get{
            return victr.recording
        }
        set(val){
            if val{
                
                victr.reset()
                victr.startRec()

            }else{
                if victr.finishRec(){
                    victr.saveVideoToCameraRoll {
                        self.victr.reset()
                    }
                }
            }
            
        }
    }
    public var metalRun:Bool{
        get{
            return metal.timer.isValid
        }
        set(val){
            if val{
                metal.startUpdating()
            }else{
                metal.timer.invalidate()
                }
            }
            
        }
    
    public var currentTexture: MTLTexture? // Ensure this property exists
    
    @Published var frameFormat: FrameFormat = .photo
    @Published var sourceVideoFrame: CGSize = CGSize(width: 1920, height: 1080)
    init(){
            PermissionsHandler.requestCameraPermission() { result in
                switch result {
                case .accessed:
                    self.initCamera()
                    self.cameraPermissionGranted = true
                case .denied:
                    self.cameraPermissionGranted = false
                }
        }
    }
    
    
    public func stopRunning(){
        // Save overlay images before stopping
        let savedOverlay1 = metal.overlayImage1
        let savedOverlay2 = metal.overlayImage2
        
        // Save overlays to UserDefaults for more reliable restoration
        if let imageOverlay = savedOverlay1, let imageData = imageOverlay.pngData() {
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("lastOverlayImage_backup.png")
                try? imageData.write(to: fileURL)
                UserDefaults.standard.set(fileURL.path, forKey: "lastOverlayImageBackupPath")
                print("Saved backup overlay in stopRunning to: \(fileURL)")
            }
        }
        
        camera.delegate = nil
        camera.stopCaptureSession()
        avReader?.delegate = nil
        avReader?.player?.pause()
        avReader = nil
        metalRun = false
        
        // Restore overlay images after stopping
        DispatchQueue.main.async {
            self.metal.overlayImage1 = savedOverlay1
            self.metal.overlayImage2 = savedOverlay2
            
            // If overlays failed to restore, try from backup
            if self.metal.overlayImage1 == nil, 
               let backupPath = UserDefaults.standard.string(forKey: "lastOverlayImageBackupPath"),
               let backupImage = UIImage(contentsOfFile: backupPath) {
                print("Restoring overlay from backup in stopRunning")
                self.metal.overlayImage1 = backupImage
            }
        }
    }
    
    
    public func setupOverlay(image:UIImage, text:UIImage) {
        metal.overlayImage1 = image
        metal.overlayImage2 = text
    }
    public func setup(mode:Mode) {
        // Save overlay images before setup
        let savedOverlay1 = metal.overlayImage1
        let savedOverlay2 = metal.overlayImage2
        
        self.mode = mode
        switch mode {
         case .capture:
            metal.mtlUniformsDefault.onCameraView = true
            PermissionsHandler.requestCameraPermission() { result in
                switch result {
                case .accessed:
                    self.camera.delegate = self
//                    self.camera.startSession()
                    self.camera.changeCamera()
//                    self.metal = MetalRenderer(self.camera.bufferSize, preset: self.camPresets[0])
                    self.cameraPermissionGranted = true
                case .denied:
                    self.cameraPermissionGranted = false
                }
            }
            VAssetModel.drawableSize = camera.bufferSize
         case .preview:
            
            if camera.captureSession != nil,
               camera.captureSession!.isRunning{
                camera.stopCaptureSession()
            }
            
            metal.mtlUniformsDefault.onCameraView = false
//            guard let sourceUrl = Bundle.main.url(forResource: "IMG_5568", withExtension: "mov") else {return}
            if sourceVideoUrl != nil{
                avReader = VAssetReader(sourceVideoUrl!)
                sourceVideoFrame = VAssetModel.drawableSize
                avReader?.delegate = self
                avReader?.player?.play()
//                setFrame(sourceVideoFrame)
                metal.mtlUniformsDefault.rotation = VAssetModel.rotation
            }else{return}
        case .recording:
            if camera.captureSession != nil,
               camera.captureSession!.isRunning{
                camera.stopCaptureSession()
            }
            
            metal.mtlUniformsDefault.onCameraView = false
            if sourceVideoUrl != nil{
                avReader = VAssetReader(sourceVideoUrl!)
                avReader?.isLoop = false
                sourceVideoFrame = VAssetModel.drawableSize
                avReader?.delegate = self
                // ==== Here we're trying to reduce the rendering time (NO WE'RE NOT)
                // avReader?.player?.rate = 3.0
                avReader?.player?.play()
                metal.mtlUniformsDefault.rotation = VAssetModel.rotation
            }else{return}
        }
        metalRun = true
        victr = ViTRecorder(drawableSize: VAssetModel.drawableSize)
        
        // Restore overlay images after setup
        DispatchQueue.main.async {
            if self.metal.overlayImage1 == nil && savedOverlay1 != nil {
                print("Restoring image overlay after mode setup")
                self.metal.overlayImage1 = savedOverlay1
            }
            
            if self.metal.overlayImage2 == nil && savedOverlay2 != nil {
                print("Restoring text overlay after mode setup")
                self.metal.overlayImage2 = savedOverlay2
            }
        }
    }
    
    
    public func initCamera() {
        var  avPreset:AVCaptureSession.Preset = AVCaptureSession.Preset.photo
        switch frameFormat {
        case .photo:
            avPreset = .photo
        case .hd:
            avPreset = .hd1280x720
        case .square:
            avPreset = .hd1920x1080
        }
        
        avPreset = .hd1920x1080
        camera = PVCaptureManager(avPreset)
       
        camera.startCamera { accessed in
        
            if accessed {
                self.camera.startSession()
            
            }
            
        
            
        }
        
      
    }
    
    func updatePixelBuffer(pixels: CVPixelBuffer, times: CMTime) {
        metal.update(pixelBuffer: pixels, timestamp: times)

        if let outputTexture = metal.outputTexure {
            currentTexture = outputTexture // Assign latest texture
            victr.flush(mtlTexture: outputTexture, recTime: times)
        }
    }

    func updatePixelBuffer(camera: CVPixelBuffer, timestamp: CMTime, recordedTime: CMTime, frontCamera: Bool) {
        metal.update(pixelBuffer: camera, timestamp: timestamp)

        if let outputTexture = metal.outputTexure {
            currentTexture = outputTexture // Assign latest texture
            victr.flush(mtlTexture: outputTexture, recTime: timestamp)
        }
    }
      
    public func setSize(_ size: Float) {
        metal.setSizeBoard(size)
    }
    
    public func setSizeY(_ sizeY: Float) {
        metal.setSizeBoardY(sizeY)
    }
    
    public func setDisplacementX(_ dispX: Float) {
        metal.setDisplacementX(dispX)
    }
    
    public func setDisplacementY(_ dispY: Float) {
        metal.setDisplacementY(dispY)
    }
    
    public func setTextDisplacementX(_ dispX: Float) {
        metal.setTextDisplacementX(dispX)
    }
    
    public func setTextDisplacementY(_ dispY: Float) {
        metal.setTextDisplacementY(dispY)
    }
    
    public func setRed(_ red: Float) {
        metal.setRedThreshold(red)
    }
    
    public func setGreen(_ green: Float) {
        metal.setGreenThreshold(green)
    }
    
    public func setBlue(_ blue: Float) {
        metal.setBlueThreshold(blue)
    }
    
    
    public func setRotation(_ rotation: Float) {
        metal.setRotation(rotation)
        
    }
    
    public func setFrameColor(_ color: UIColor) {
        //metal.setRotation(rotation)
        metal.setFrameColor(color)
    }
    
    public func setFrameWidth(_ width: Float) {
        metal.setFrameWidth(width)
    }
    
    public func setBlurSize(_ size: Float) {
        metal.setBlurSize(size)
    }
    
    public func setFrame(_ size: CGSize) {
        metal.setFrame(size)
        
    }
    public func switchCam() {
        camera.changeCamera()
    }
    
    
    
    public    var uniforms:MetalUniforms {
        
        get {
            
            
            return  metal.mtlUniforms
            
            
        }
        set (newVal) {
            
            metal.mtlUniforms = newVal
            
        }
    }
    
    public var defaultUniforms:MetalUniforms {
        get {
            
            
            return  metal.mtlUniformsDefault
            
            
        }
        set (newVal) {
            
            metal.mtlUniformsDefault = newVal
            
        }
    }
    
    public  var mtlView : UIView {
        
        
        get {
            return  metal.mtlView
        }
        set (newVal) {
            metal.mtlView = newVal
            
      }
       
     
    }
 
    
    
    func exportVideo(path: String) {
        //
    }
    
  
    
    func capturePhoto(photo: CVPixelBuffer, metadata: CFDictionary) {
//        metal.drawView(pixels: camera, timestamp: timestamp)
    }
    
    func getPixelColor(at location: CGPoint, in frame: CGRect) -> UIColor {
        guard let texture = currentTexture else { return .clear } // Ensure texture exists

        // Convert to texture coordinates
        let textureX = Int((location.x / frame.width) * CGFloat(texture.width))
        let textureY = Int((location.y / frame.height) * CGFloat(texture.height))

        // Read pixel data
        var pixel = [UInt8](repeating: 0, count: 4) // RGBA buffer
        let region = MTLRegionMake2D(textureX, textureY, 1, 1)

        texture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)

        //bgr!
        let color = UIColor(
            red: CGFloat(pixel[2]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[0]) / 255.0,
            alpha: CGFloat(pixel[3]) / 255.0
        )
        
        metal.maskColor = color

        return color
    }
    
    public func setTextBlur(_ blur: Float) {
        // Store the existing overlays before update
        let savedImageOverlay = metal.overlayImage1
        let savedTextOverlay = metal.overlayImage2
        
        // Apply blur to the text by using CoreImage filters
        if let textImage = layer.textImage, blur > 0 {
            // Create a CIImage from the UIImage
            let ciImage = CIImage(image: textImage)
            
            // Create the Gaussian blur filter
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            
            // Set the blur radius based on the slider value (0-10 range works well for text)
            let blurAmount = blur * 10.0 // Scale to a reasonable range
            filter?.setValue(blurAmount, forKey: kCIInputRadiusKey)
            
            // Get the output CIImage
            if let outputImage = filter?.outputImage {
                // Create a CIContext to render the image
                let context = CIContext(options: nil)
                
                // Calculate a larger extent to account for blur radius causing image expansion
                let extent = outputImage.extent.insetBy(dx: -CGFloat(blurAmount * 2), dy: -CGFloat(blurAmount * 2))
                
                // Render the CIImage to a CGImage
                if let cgImage = context.createCGImage(outputImage, from: extent) {
                    // Convert back to UIImage
                    let blurredImage = UIImage(cgImage: cgImage)
                    
                    // Update the text overlay with the blurred version
                    metal.overlayImage2 = blurredImage
                    
                    print("Applied text blur: \(blur)")
                }
            }
        } else {
            // If blur is 0 or we can't apply the filter, restore the original text
            metal.overlayImage2 = savedTextOverlay
        }
        
        // Ensure the image overlay is preserved
        if savedImageOverlay != nil {
            metal.overlayImage1 = savedImageOverlay
        }
    }
    
    public func setTextOpacity(_ opacity: Float) {
        // Store the existing overlays before update
        let savedImageOverlay = metal.overlayImage1
        let savedTextOverlay = metal.overlayImage2
        
        // Apply opacity to the text
        if let textImage = layer.textImage, opacity < 1.0 {
            // Create a CIImage from the UIImage
            let ciImage = CIImage(image: textImage)
            
            // Create a transparent black color (alpha channel will control opacity)
            let opaqueColor = CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(opacity))
            
            // Create the color overlay filter
            let filter = CIFilter(name: "CIColorMatrix")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            
            // Scale the alpha channel by the opacity value
            // This preserves the color but adjusts transparency
            let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
            filter?.setValue(alphaVector, forKey: "inputAVector")
            
            // Get the output CIImage
            if let outputImage = filter?.outputImage {
                // Create a CIContext to render the image
                let context = CIContext(options: nil)
                
                // Render the CIImage to a CGImage
                if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                    // Convert back to UIImage with proper alpha
                    let transparentImage = UIImage(cgImage: cgImage)
                    
                    // Update the text overlay with the transparent version
                    metal.overlayImage2 = transparentImage
                    
                    print("Applied text opacity: \(opacity)")
                }
            }
        } else if opacity >= 1.0 {
            // If opacity is 1 (fully opaque), restore the original text
            metal.overlayImage2 = savedTextOverlay
        }
        
        // Ensure the image overlay is preserved
        if savedImageOverlay != nil {
            metal.overlayImage1 = savedImageOverlay
        }
    }
}
