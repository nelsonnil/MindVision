//
//  MTLRenderer.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 10/03/2024.
//

import MetalKit
import AVFoundation
import MetalDevice
import CoreImage

class MTLRenderer {
    var timer = Timer()
    
    private var semaphore = DispatchSemaphore(value: 1)
    public var mtlView: UIView!
    var metalLayer = CAMetalLayer()
    private var vertData: MTLBuffer?
    private var uBuffer: MTLBuffer?
    private var cvBuffer: MTLBuffer?
    private let texLoader = MTKTextureLoader(device: MTDevice.shared.device)
    
    public var mtlUniforms: MetalUniforms
    public var mtlUniformsDefault: MetalUniforms
    
    public var outputTexure: MTLTexture?
    var videoTexture: MTLTexture!
    var layerTexture1: MTLTexture!
    var layerTexture2: MTLTexture!
  
    private let colorToDetect = CIColor(red: 0.0, green: 0.0, blue: 1.0)
      
    var imageOut: [float3] = []
    var cvpixels: CVPixelBuffer!

    public var ciimage: CIImage?
    public var overlayImage1: UIImage?
    public var overlayImage2: UIImage?

    private var mainPipeState = try? MTDevice.renderPipe(vertexFunctionName: "vertex_shader",
                                                       fragmentFunctionName: "main_fragment", pixelFormat: .bgra8Unorm)

    public var boardSize: Float = 0.0
    public var boardSizeY: Float = 0.0
    
    public var displacementX: Float = 0.0
    public var displacementY: Float = 0.0
    
    public var textDisplacementX: Float = 0.0
    public var textDisplacementY: Float = 0.0
    
    public var redThreshold: Float = 0.0
    public var greenThreshold: Float = 0.0
    public var blueThreshold: Float = 0.0
    
    public var rotationValue: Float = 0.0
    
    public var maskColor: UIColor = .white
    
    public var frameColor: UIColor = .red
    
    public var frameWidthValue: Float = 0.0
    
    public var blurSize: Float = 0.0
    
    deinit {
        print("MTLRender Removed")
    }
    
    // MARK: init
    public init() {
        mtlUniforms = MetalUniforms(u_res: float2(Float(VAssetModel.drawableSize.width), Float(VAssetModel.drawableSize.height)))
        
        mtlUniformsDefault = MetalUniforms(u_res: float2(Float(VAssetModel.drawableSize.width), Float(VAssetModel.drawableSize.height)))
        
        mtlView = UIView(frame: .zero)
        
        metalLayer = CAMetalLayer()
        metalLayer.device = MTDevice.shared.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        mtlView.layer.addSublayer(metalLayer)
        vertData = MTDevice.vertexBuffer()
        
        //
        uBuffer = MTDevice.shared.device.makeBuffer(bytes: &mtlUniformsDefault, length: MemoryLayout<MetalUniforms>.stride, options: .storageModeShared)!
        
    }
    
    public func startUpdating() {
         timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { timer in
             self.draw()
        }
    }

    public func setSizeBoard(_ size: Float) {
        boardSize = size
    }
    
    public func setSizeBoardY(_ sizeY: Float) {
        boardSizeY = sizeY
    }
    
    public func setDisplacementX(_ dispX: Float) {
        displacementX = dispX
    }
    
    public func setDisplacementY(_ dispY: Float) {
        displacementY = dispY
    }
    
    public func setTextDisplacementX(_ dispX: Float) {
        textDisplacementX = dispX
    }
    
    public func setTextDisplacementY(_ dispY: Float) {
        textDisplacementY = dispY
    }
    
    public func setRedThreshold(_ threshold: Float) {
        redThreshold = threshold
    }
    
    public func setGreenThreshold(_ threshold: Float) {
        greenThreshold = threshold
    }
    
    public func setBlueThreshold(_ threshold: Float) {
        blueThreshold = threshold
    }
    
    public func setRotation(_ rotation: Float) {
        rotationValue = rotation
    }
    
    public func setFrameColor(_ color: UIColor) {
        frameColor = color
    }
    
    public func setFrameWidth(_ width: Float) {
        frameWidthValue = width
    }
    
    public func setBlurSize(_ size: Float) {
        print("MTLRenderer: Cambiando blurSize a \(size)")
        blurSize = size
    }
    
    public func setFrame(_ size: CGSize) {
        mtlView.frame = CGRect(origin: .zero, size: size)
        
        metalLayer.frame = AVMakeRect(aspectRatio: VAssetModel.drawableSize, insideRect: mtlView.bounds)
        metalLayer.position = mtlView.center
        metalLayer.drawableSize = VAssetModel.drawableSize
        videoTexture = MTDevice.texture(VAssetModel.drawableSize)
    }
    
    public func setFsrame(_ size: CGSize) {
        mtlView.frame = CGRect(origin: CGPoint(x: 5, y: 5), size: CGSize(width: size.width + 10, height: size.height + 10))
        
        metalLayer.frame = mtlView.frame
        metalLayer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        metalLayer.drawableSize = VAssetModel.drawableSize
        videoTexture = MTDevice.texture(VAssetModel.drawableSize)
        if !timer.isValid {
            startUpdating()
        }
    }
    
    public func processLayer(_ layer: Layer, secondLayer: Layer?) {
        layerTexture1 = MTDevice.shared.ciTexture(CIImage(image: layer.overlayImage), size: CIImage(image: layer.overlayImage)!.extent.size)
        if let secondLayer = secondLayer {
            layerTexture2 = MTDevice.shared.ciTexture(CIImage(image: secondLayer.overlayImage), size: CIImage(image: secondLayer.overlayImage)!.extent.size)
        } else {
            layerTexture2 = nil
        }
    }

    func updateBuffer() {
        uBuffer = MTDevice.shared.device.makeBuffer(bytes: &mtlUniformsDefault, length: MemoryLayout<MetalUniforms>.stride, options: .storageModeShared)!
    }
    
    // 1
    func preprocessOverlayImage(_ image: UIImage, uniforms: MetalUniforms) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext(options: nil)
        
        // Apply brightness
        let brightnessFilter = CIFilter(name: "CIColorControls")
        brightnessFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        brightnessFilter?.setValue(uniforms.brightness, forKey: kCIInputBrightnessKey)
        
        // Apply saturation
        let saturationFilter = CIFilter(name: "CIColorControls")
        saturationFilter?.setValue(brightnessFilter?.outputImage, forKey: kCIInputImageKey)
        saturationFilter?.setValue(uniforms.saturation, forKey: kCIInputSaturationKey)
        
        // Apply rotation
        let rotationFilter = CIFilter(name: "CIAffineTransform")
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: CGFloat(uniforms.rotation))
        rotationFilter?.setValue(saturationFilter?.outputImage, forKey: kCIInputImageKey)
        rotationFilter?.setValue(transform, forKey: kCIInputTransformKey)
        
        guard let outputImage = rotationFilter?.outputImage else { return nil }
        
        // Convert CIImage to UIImage
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return nil
    }

    func draw() {
        var orientation = false
        let commandBuffer = MTDevice.shared.newCommandBuffer()
        
        mtlUniforms.u_time += 0.3
        mtlUniformsDefault.u_time += 0.3
        if let pixelBuffer = cvpixels {
            videoTexture = MTDevice.shared.cVTexture(buffer: cvpixels)
        } else {
            return
        }
        
        updateBuffer()
        
        let image = UIImage(cgImage: videoTexture!.cgImage!)
        
        let processedOverlayImage1 = preprocessOverlayImage(overlayImage1 ?? UIImage(named: "hypno")!, uniforms: mtlUniforms)
        
        var cvTexture: MTLTexture = MTDevice.texture(image.size)!
        measureExecutionTime("\(#function)") {
            let arucoData = CVProccessor.arucoDetection(rotationValue: rotationValue, boardSize: boardSize, boardSizeY: boardSizeY, displacementX: displacementX, displacementY: displacementY, textDisplacementX: textDisplacementX, textDisplacementY: textDisplacementY, inputImg: image, overlayImage: processedOverlayImage1 ?? UIImage(named: "hypno")!, textImage: overlayImage2 ?? UIImage(named: "hypno")!, color: maskColor, redThreshold: redThreshold, greenThreshold: greenThreshold, blueThreshold: blueThreshold, frameColor: frameColor, frameWidth: frameWidthValue, blurSize: blurSize)
            let ciimage = CVProccessor.processImg(uiimg: arucoData.image)
            cvTexture = MTDevice.shared.ciTexture(ciimage, size: (ciimage?.extent.size)!)!
        }
        
        if let drawable = metalLayer.nextDrawable(),
           let renderPipelineState = mainPipeState {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
            
            if let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                commandEncoder.setRenderPipelineState(renderPipelineState)
                commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
                //
                commandEncoder.setFragmentBuffer(uBuffer, offset: 0, index: 12)
                commandEncoder.setFragmentBytes(&orientation, length: MemoryLayout<Bool>.stride, index: 10)
                commandEncoder.setFragmentTexture(videoTexture, index: 0)
                commandEncoder.setFragmentTexture(cvTexture, index: 1)
                commandEncoder.setFragmentTexture(layerTexture1, index: 2)
                commandEncoder.setFragmentTexture(layerTexture2, index: 3)
                
                commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                commandEncoder.endEncoding()
            }
            
            drawable.present()
            commandBuffer.addCompletedHandler { _ in
                self.semaphore.signal()
            }
            
            commandBuffer.commit()
            outputTexure = drawable.texture
            self.semaphore.wait()
        }
    }

    public func update(pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        measureExecutionTime("\(#function)") {
            cvpixels = pixelBuffer
        }
    }
}

// MARK: - Extensions

extension CGPoint {
    func convert(rect: CGRect) -> float2 {
        let p = CGPoint(x: (x * rect.width) + rect.origin.x, y: (y * rect.height) + rect.origin.y)
        return float2(Float(p.x), Float(1 - p.y))
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        }
    }
}

extension MTLTexture {
    public var cgImage: CGImage? {
        let options = [CIImageOption.colorSpace: CGColorSpaceCreateDeviceRGB(),
                       CIContextOption.outputPremultiplied: true,
                       CIContextOption.useSoftwareRenderer: false] as! [CIImageOption : Any]
        
        guard let image = CIImage(mtlTexture: self, options: options) else {
            print("CIImage not created")
            return nil
        }
        
        let flipped = image.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
        return CIContext().createCGImage(flipped,
                                         from: flipped.extent,
                                         format: CIFormat.RGBA8,
                                         colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }
}

public func measureExecutionTime(_ functionName: String, _ function: () -> Void) {
    let startTime = CFAbsoluteTimeGetCurrent()
    function()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
}

