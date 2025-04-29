//
//  CVDetectionBridge.h
//  Hip
//
//  Created by Demian Nezhdanov on 04.02.2021.
//  Copyright © 2021 Demian Nezhdanov. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <simd/simd.h>
@interface CVDetectionBridge : NSObject
    
- (UIImage *) arucoDetectionWithImage: (UIImage *)image secondImage:(UIImage *)imageOverlay imageText:(UIImage*) text boardSize:(float)boardSize boardSizeY:(float)boardSizeY rotationValue:(float)rotationVal displacementX:(float)displacementX displacementY:(float)displacementY textDisplacementX:(float)tdX textDisplacementY:(float)tdY red:(int)redColor green:(int)greenColor blue:(int)blueColor redT:(int)redThreshold greenT:(int)greenThreshold blueT:(int)blueThreshold frameRed:(int) frameR frameGreen:(int)frameG frameBlue:(int)frameB frameWidth:(float)frameWidthVal blurSize:(int)blurSizeVal;

    
@end
