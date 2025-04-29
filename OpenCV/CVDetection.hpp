//
//  CVDetection.hpp
//  Hip
//
//  Created by Demian Nezhdanov on 04.02.2021.
//  Copyright © 2021 Demian Nezhdanov. All rights reserved.
//


#include <opencv2/opencv.hpp>

using namespace cv;
using namespace std;

typedef struct {
    float x;
    float y;
    float z;
} float3;

class CVDetection {
    
public:

    Mat processAruco(Mat image,Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, float rotation);
    
    Mat processArucoNew(Mat image, Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, float rotation, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions);
    
    Mat processArucoNewWithText(Mat image, Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, int increaseBoardSizeY, float rotation, int displacementX, int displacementY, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions);
    
    Mat processArucoNewWithTextSeparated(Mat image, Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, int increaseBoardSizeY, float rotation, int displacementX, int displacementY, float textDisplacementX, float textDisplacementY, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions, Scalar frameColor, float frameWidth, int blurSize = 21);
    
    Mat processArucoNewWithMask(Mat image, Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, int increaseBoardSizeY, float rotation, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions, int red, int green, int blue, int redThreshold, int greenThreshold, int blueThreshold);
    
    Mat detectRedObjects(const Mat& image);
    
    Mat detectColorObjects(const Mat& image, int red, int green, int blue, int redThreshold, int greenThreshold, int blueThreshold);
    
    void Overlap_Frames_With_Alpha(
        Mat BaseFrame,
        Mat SecFrame,
        vector<Point2f> BoxCoordinates,
        Mat& OverlapedFrame,
        float displacementX,
        float displacementY,
        bool showBoundingBox = false,
        Scalar frameColor = Scalar(255,255,255),
        int frameThickness = 10,
        int blurSize = 21
    );
    
};
