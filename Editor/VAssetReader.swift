//
//  Player.swift
//  ScnWraper
//
//  Created by Demian Nezhdanov on 05.06.2021.
//

import AVFoundation
import UIKit
import MetalKit

public protocol PlaybackPixelBufferDelegate:AnyObject{
    func updatePixelBuffer(pixels: CVPixelBuffer,times: CMTime)

}

public struct AssetTime{
    public init(){}
    public var finalClipRange:CMTimeRange = CMTimeRange(start: .zero, duration: .zero)
    public var clipDuration:CMTime = .zero
    public var currentTime:CMTime = .zero
}

public class VAssetModel{
    
    public init(){}
    public static var land = false
    public static var rotation:Float = 0
    public static var rotationGif:Float = 0
    public static var aspectRatio:CGFloat = 0
    public static var drawableSize:CGSize = CGSize(width: 1080, height: 1920)
    public static var duration:CMTime! = .zero
    public static var landscape = false
}




public protocol VAssetRaderDelegate{
    func seekTo(time:CMTime)
    func readBuffer() -> CVPixelBuffer?
    func playAsset()
    func pauseAsset()
    func setTimeRange(_ timeRange:CMTimeRange)
}


public class VAssetReader:VAssetRaderDelegate{
  
    
    
    weak public var delegate: PlaybackPixelBufferDelegate?
    
    public var asset:AVAsset!
    var videoOutput: AVPlayerItemVideoOutput!
    public var player :AVPlayer?
    public  var playerItem: AVPlayerItem!
    public  var assetTime = AssetTime()
    public var pixelBuffer: CVPixelBuffer?
    
    public var isLoop:Bool = true
    
    public var isPlaying: Bool {
        return player?.timeControlStatus == .playing
    }

    public init(_ url:URL){
         asset = AVAsset(url:url)
         
          
             assetTime.finalClipRange.duration = asset.duration
//         }
        
         playerItem = AVPlayerItem(asset: asset)
         player = AVPlayer(playerItem: playerItem)
         let videoSettings = [
              kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
         ]
         videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes:videoSettings)
         player?.currentItem?.add(videoOutput)
         player!.play()
//         sound = Sound(url: url)
//         turnOnSound(false)
         
         VAssetModel.duration = asset.duration
        //if (abs(asset!.videoSize().width) > abs(asset!.videoSize().height)){
        //     VAssetModel.landscape = true
        //}else{VAssetModel.landscape = false}
        VAssetModel.drawableSize.width = abs(asset!.videoSize().width) //1280
        VAssetModel.drawableSize.height = abs(asset!.videoSize().height) //720
        VAssetModel.aspectRatio = abs(asset!.videoSize().width) / abs(asset!.videoSize().height) //1280/720
        if (VAssetModel.drawableSize.width > VAssetModel.drawableSize.height){
            VAssetModel.landscape = true
        }else{VAssetModel.landscape = false}
        
        if let videoTransform  = asset.tracks(withMediaType: .video).first?.preferredTransform {
            print("videoTransform")
            print(videoTransform)
            VAssetModel.land = videoTransform.a == 0
            if videoTransform.a == 0{
                if abs(videoTransform.b) == 1{
                    VAssetModel.rotation = .pi/2
                    VAssetModel.rotationGif = -.pi/2
                }
            }else{
                if videoTransform.a == 1{
                    if  VAssetModel.drawableSize.height >  VAssetModel.drawableSize.width{
                        VAssetModel.rotation = -.pi
                    }else{
                        VAssetModel.rotation = .pi*2
                    }
                    VAssetModel.rotationGif = .pi
                }
            }
        } else{
            print("NO transform data for video")
        }
 
         let displayLink = CADisplayLink(target: self, selector: #selector(update))
         displayLink.add(to: .current, forMode: .common)

     }
    @objc func update() {
        
        guard let pb = readBuffer() else{return}
        delegate?.updatePixelBuffer(pixels: pb, times: player!.currentTime())
    }
    public func turnOnSound(_ isOn:Bool){
        player!.volume = isOn ? 1.0 : 0.0
    }
    
    public func seekTuStart(){
        
        player!.currentItem!.seek(to: assetTime.finalClipRange.start, completionHandler: { _ in
             self.player!.pause()
       })
        
    }
    
    public func seekTo(time:CMTime){
        
        player!.currentItem!.seek(to: assetTime.finalClipRange.start, completionHandler: { _ in
             self.player!.play()
       })
        
    }
    
    
    public func loop() {
          if  player!.currentTime().seconds  >=  assetTime.finalClipRange.end.seconds {
              player!.currentItem!.seek(to: assetTime.finalClipRange.start, completionHandler: { _ in
                   self.player!.play()
             })
       }
       
     }
     
     
    
    public  func playAsset() {
        player!.play()
    }
    
    public  func pauseAsset() {
        player!.pause()
    }
    
    public  func setTimeRange(_ timeRange: CMTimeRange) {
        assetTime.finalClipRange = timeRange
    }
  

     
    public  func readBuffer() -> CVPixelBuffer?{
        // ==== HERE'S THE LOOP ====
        if self.isLoop {
            loop()
        }
         let itemTime = CMTimeMakeWithSeconds(Float64(player!.currentTime().seconds), preferredTimescale: Int32(6000))
          if videoOutput.hasNewPixelBuffer(forItemTime: itemTime) {
               self.pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
              return pixelBuffer
          }else{return nil}
         
     }
   
 
    
     
}








public extension AVAsset{
     
    func videoSize()->CGSize{
          let tracks = self.tracks(withMediaType: AVMediaType.video)
          if (tracks.count > 0){
               let videoTrack = tracks[0]
               let size = videoTrack.naturalSize
               let txf = videoTrack.preferredTransform
               let realVidSize = size.applying(txf)
               
               return realVidSize
          }
          return CGSize(width: 0, height: 0)
     }
    
    func videoDuration() -> Double {
        let tracks = self.tracks(withMediaType: AVMediaType.video)
        if tracks.count > 0 {
            let videoTrack = tracks[0]
            return CMTimeGetSeconds(videoTrack.timeRange.duration)
        }
        return 0.0
    }
     
}
