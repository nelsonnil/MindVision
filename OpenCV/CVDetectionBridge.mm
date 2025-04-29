//
//  CVDetectionBridge.m
//  Hip
//
//  Created by Demian Nezhdanov on 04.02.2021.
//  Copyright © 2021 Demian Nezhdanov. All rights reserved.
//
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/videoio/cap_ios.h>
#import <Foundation/Foundation.h>
#import "CVDetectionBridge.h"
#include "CVDetection.hpp"

#include <SceneKit/SceneKit.h>

#include <simd/simd.h>

#include <iostream>

using namespace cv;
using namespace simd;
using namespace std;

@implementation CVDetectionBridge


typedef struct {
    float x;
    float y;
} float2;


typedef struct {
    float x;
    float y;
    float z;
} Float3;

static std::vector<cv::Point2f> boxCoordinates_last;
static int increaseBoardSize = 0;
static int increaseBoardSizeY = 0;
static int displacementX = 0;
static int displacementY = 0;
static float textDisplacementX = 0;
static float textDisplacementY = 0;



- (UIImage *) arucoDetectionWithImage:(UIImage *)image secondImage:(UIImage *)imageOverlay imageText:(UIImage*) text boardSize:(float)boardSize boardSizeY:(float)boardSizeY rotationValue:(float)rotationVal displacementX:(float)displacementX displacementY:(float)displacementY textDisplacementX:(float)tdX textDisplacementY:(float)tdY red:(int)redColor green:(int) greenColor blue:(int)blueColor redT:(int)redThreshold greenT:(int)greenThreshold blueT:(int)blueThreshold frameRed:(int) frameR frameGreen:(int)frameG frameBlue:(int)frameB frameWidth:(float)frameWidthVal blurSize:(int)blurSizeVal {
    
    Mat opencvImage, opencvImageOverlay, opencvImageText;
    UIImageToMat(image, opencvImage, true);
    UIImageToMat(imageOverlay, opencvImageOverlay, true);
    UIImageToMat(text, opencvImageText, true);
    
    
    cv::Mat convertedColorSpaceImage;
    cv::cvtColor(opencvImage, convertedColorSpaceImage, COLOR_RGBA2GRAY);
    
    
    CVDetection CVDetector;
    increaseBoardSize = boardSize;
    increaseBoardSizeY = boardSizeY;
    displacementX = displacementX;
    displacementY = displacementY;
    textDisplacementX = tdX;
    textDisplacementY = tdY;
    
    //cout << " ==== boxCoordinates_last = " << boxCoordinates_last;
    
    //std::vector<cv::Point2f> offset = { cv::Point2f(100.0f, 100.0f) };
    std::vector<cv::Point2f> overlayPositions = { Point2f(0, 0) };
    
    cv::Scalar color(frameR, frameG, frameB, 255); //Opacity set to 1 for now
    
    Mat overlayImageTransformed = CVDetector.processArucoNewWithTextSeparated(opencvImage, opencvImageOverlay, boxCoordinates_last, increaseBoardSize, increaseBoardSizeY, rotationVal, displacementX, displacementY, textDisplacementX, textDisplacementY, opencvImageText, overlayPositions, color, frameWidthVal, blurSizeVal);
    
    Mat output;
    
    overlayImageTransformed.convertTo(output, CV_8UC1);
    
    return MatToUIImage(output);
}



    
    @end
