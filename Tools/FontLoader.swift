//
//  FontLoader.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 16/03/2024.
//

import Foundation
import UIKit
public class FontLoader {
    static public var fontName:String = "Arcade"
    static public var fontScale:CGFloat = 1.0
    
 

    
//    · Text color: #FDC400
//    · Glow color: #AA0101
    static public func prcssTexture(fontName:String,fontSize:CGFloat, string:String,_ size:CGSize) -> CIImage{
        
        let text = string
        let uilabel = UILabel(frame: CGRect(origin: .zero, size: CGSize(width: 50 * text.count / 2 , height: 50)))
//        uilabel.text = string + " " + dateString()
        uilabel.text =  string//dateString()
        uilabel.font = UIFont(name: fontName, size: fontSize)
        uilabel.textColor = .white

        let uiview = UIView(frame: CGRect(origin: .zero, size: size))
        uilabel.frame.origin.y = uiview.frame.height * 0.8
        uilabel.frame.origin.x = uiview.frame.width * 0.6
        uiview.addSubview(uilabel)
        let uiimage = uiview.createImage()
        let ciimage = CIImage(cgImage: uiimage.cgImage!)
        return ciimage
    }
    
    static public var allFonts:[String] = []
    static  func loadAllFonts(){
        var fonts:[String] = []
        for family in UIFont.familyNames {

         let sName: String = family as String
         print("family: \(sName)")
                
         for name in UIFont.fontNames(forFamilyName: sName) {
              print("name: \(name as String)")
             fonts.append(name as String)
         }
    }
        allFonts = fonts
    }
    
    static  func fonts(){

    for family in UIFont.familyNames {

         let sName: String = family as String
         print("family: \(sName)")
                
         for name in UIFont.fontNames(forFamilyName: sName) {
              print("name: \(name as String)")
         }
    }
    }
  
    
    
}

public extension UIView{
    public func createImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: self.frame.width, height: self.frame.height), false, 1)
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}
