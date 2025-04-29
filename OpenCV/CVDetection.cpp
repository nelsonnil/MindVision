#include "CVDetection.hpp"


//#include <opencv2/highgui.hpp>
#include <opencv2/aruco.hpp>
#include <filesystem> // Include para trabajar con rutas de archivo en C++
#include <algorithm>
#include <iostream>

#import "opencv2/objdetect/aruco_detector.hpp"
#import "opencv2/objdetect/aruco_dictionary.hpp"

#define distancia 1

using namespace cv;
using namespace std;
using namespace aruco;

namespace fs = std::filesystem;

class MovingAverageFilter {
public:
    MovingAverageFilter(int window_size) : window_size_(window_size) {}

    cv::Point2f apply(const cv::Point2f& new_point) {
        if (points_.size() == window_size_) {
            points_.pop_front();
        }
        points_.push_back(new_point);

        cv::Point2f avg_point(0, 0);
        for (const auto& point : points_) {
            avg_point += point;
        }
        avg_point.x /= points_.size();
        avg_point.y /= points_.size();

        return avg_point;
    }

private:
    int window_size_;
    std::deque<cv::Point2f> points_;
};


// Camera parameters reader. In this function we read an .xml with relevant paremeters from camera.
static bool readCameraParameters(Mat& camMatrix, Mat& distCoeffs, int width , int height) {
    
    // Resolución original y nueva
    int originalWidth = 1920;
    int originalHeight = 1080;
    float scaleX, scaleY;
    // Factores de escalado
    int aux_width, aux_height;
    if (width > height){
        aux_width = width;
        aux_height = height;
        scaleX = (float)aux_width / (float)originalWidth;
        scaleY = (float)aux_height / (float)originalHeight;
    }
    else{
        aux_width = height;
        aux_height = width;
        scaleX = (float)aux_width / (float)originalWidth;
        scaleY = (float)aux_height / (float)originalHeight;
    }
    
    //scaleX = (float)aux_width / (float)originalWidth;
    //scaleY = (float)aux_height / (float)originalHeight;

    // Matriz de la cámara ajustada
    camMatrix = (cv::Mat_<float>(3, 3) <<
        1.66237451e+03 * scaleX, 0., 9.48036011e+02 * scaleX,
        0., 1.67200171e+03 * scaleY, 5.49524719e+02 * scaleY,
        0., 0., 1.);

    // Coeficientes de distorsión (estos generalmente no cambian con la resolución)
    distCoeffs = (cv::Mat_<float>(1, 5) <<
        1.87421173e-01, -7.93662250e-01, -1.08619721e-03,
        -8.61240027e-04, 1.23946273e+00); 
    return true;
}

void ProjectiveTransform(Mat Frame, vector<Point2f> Coordinates, Mat& TransformedFrame, int displacementX, int displacementY)
{
    int Height = Frame.rows, Width = Frame.cols;
    
    cv::Point2f InitialPoints[4], FinalPoints[4];
    InitialPoints[0] = cv::Point2f(0, 0);
    InitialPoints[1] = cv::Point2f(Width - 1, 0);
    InitialPoints[2] = cv::Point2f(Width - 1, Height - 1);
    InitialPoints[3] = cv::Point2f(0, Height - 1);

    
    FinalPoints[0] = cv::Point2f(Coordinates[0].x + displacementX, Coordinates[0].y + displacementY);
    FinalPoints[1] = cv::Point2f(Coordinates[1].x + displacementX, Coordinates[1].y + displacementY);
    FinalPoints[2] = cv::Point2f(Coordinates[2].x + displacementX, Coordinates[2].y + displacementY);
    FinalPoints[3] = cv::Point2f(Coordinates[3].x + displacementX, Coordinates[3].y + displacementY);
    
    for (int i = 0; i < 4; ++i) {
        std::cout << " - FinalPoints[" << i << "]: ("
                  << FinalPoints[i].x << ", "
                  << FinalPoints[i].y << ")" << std::endl;
    }

    Mat ProjectiveMatrix;//(2, 4, CV_32FC1);
    ProjectiveMatrix = cv::getPerspectiveTransform(InitialPoints, FinalPoints);
    warpPerspective(Frame, TransformedFrame, ProjectiveMatrix, TransformedFrame.size(), INTER_LINEAR, BORDER_CONSTANT);
}


// ========================== ADD DISPLACEMENT WITH PERSPECTIVE
void ProjectiveTransformWithInternalDisplacement(Mat Frame, vector<Point2f> Coordinates, Mat& TransformedFrame, float dx_local, float dy_local)
{
    int Height = Frame.rows, Width = Frame.cols;

    // Step 1: define corners of the original image
    std::vector<cv::Point2f> InitialPoints = {
        cv::Point2f(0.0f, 0.0f),
        cv::Point2f(static_cast<float>(Width - 1), 0.0f),
        cv::Point2f(static_cast<float>(Width - 1), static_cast<float>(Height - 1)),
        cv::Point2f(0.0f, static_cast<float>(Height - 1))
    };

    // Step 2: Compute homography from the original image to the quadrilateral
    Mat H = cv::getPerspectiveTransform(InitialPoints, Coordinates);

    // Step 3: Swap dx_local and dy_local
    float dx = dy_local;
    float dy = dx_local;

    vector<Point2f> LocalInitial = {
        {0, 0}, {1, 0}, {1, 1}, {0, 1}
    };

    vector<Point2f> LocalDisplaced = {
        {dx, dy},
        {1 + dx, dy},
        {1 + dx, 1 + dy},
        {dx, 1 + dy}
    };

    // Step 4: Map normalized space to the destination quad
    vector<Point2f> DisplacedQuad(4);
    for (int i = 0; i < 4; ++i) {
        cv::Point2f vecX = Coordinates[1] - Coordinates[0];
        cv::Point2f vecY = Coordinates[3] - Coordinates[0];
        DisplacedQuad[i] = Coordinates[0] + LocalDisplaced[i].x * vecX + LocalDisplaced[i].y * vecY;
    }

    // Step 5: Get the updated homography with displacement
    Mat H_displaced = getPerspectiveTransform(InitialPoints, DisplacedQuad);

    // Step 6: Apply warp
    warpPerspective(Frame, TransformedFrame, H_displaced, TransformedFrame.size(), INTER_LINEAR, BORDER_CONSTANT);
}
// ===========================================


// ----------------------------- RAFAEL MODIFICATION
// This function calculates a point vector around to a reference point.
vector<Point> calculeContour(vector<Point> Points_IN, Mat imagenInput)
{
    vector<Point> contorno;
    Mat plantilla= Mat::zeros(imagenInput.rows, imagenInput.cols, CV_8UC1);
    Point punto;
    for (int i = 0; i < 4; i++)
    {
        line(plantilla, Points_IN[i], Points_IN[(i + 1) % 4], 255, 2, LINE_AA);
    }
        
    for (int i = 0; i < plantilla.rows; i++) {
        for (int j = 0; j < plantilla.cols; j++) {
            if (plantilla.at<uchar>(i, j) == 255)
            {
                punto.x = i;
                punto.y = j;
                contorno.push_back(punto);
            }
        }
    }
    return contorno;
}

// This function suavize an image contours
bool SmoothContour(vector<Point> Contorno_IN, Mat inputImagen)
{
    Mat MatResult = inputImagen.clone();
    Mat MatResult_R, MatResult_G, MatResult_B;
    vector<Point>vecinos, borde;
    Vec3b pixel;

    if(Contorno_IN.size()>=4)
        borde = calculeContour(Contorno_IN, inputImagen);

    return true;
}


// Function to show magic image into the board
void Overlap_Frames(Mat BaseFrame, Mat SecFrame, vector<Point2f> BoxCoordinates, Mat& OverlapedFrame)
{
    int j, z;
    Vec3b pixel;
    //cv::cvtColor(SecFrame, SecFrame, COLOR_BGRA2BGR);
    Mat BaseFrame_Copy = BaseFrame.clone();

    // Finding transformed image
    Mat TransformedFrame = BaseFrame.clone();
    
    //InvertRegionVertical(TransformedFrame, BoxCoordinates);
    //InvertRegionHor(TransformedFrame,BoxCoordinates);
    ProjectiveTransform(SecFrame, BoxCoordinates, TransformedFrame, 0, 0);

    // Overlaping frames
    Mat SecFrame_Mask = Mat::zeros(Size(BaseFrame.cols, BaseFrame.rows), CV_8UC3);
    std::vector<cv::Point> BoxCoordinates_Converted;
    for (std::size_t i = 0; i < BoxCoordinates.size(); i++)
        BoxCoordinates_Converted.push_back(cv::Point(BoxCoordinates[i].x, BoxCoordinates[i].y));

    fillConvexPoly(SecFrame_Mask, BoxCoordinates_Converted, cv::Scalar(255,255,255), LINE_AA);

    Mat SecFrame_Mask_not;
    bitwise_not(SecFrame_Mask, SecFrame_Mask_not); // hasta aqui lo hace bien
    
    OverlapedFrame=BaseFrame.clone();
    
    OverlapedFrame = SecFrame_Mask;
    bitwise_and(BaseFrame, SecFrame_Mask_not, BaseFrame_Copy);
    //OverlapedFrame = BaseFrame.clone();
    bitwise_or(BaseFrame_Copy, TransformedFrame, OverlapedFrame);
    //bitwise_or(BaseFrame_Copy, SecFrame_Mask, OverlapedFrame);
    
    if (BoxCoordinates_Converted.size() > 0)
    {
        // Vec3b color = image.at<Vec3b>(Point(x,y));
        Vec3b Color = SecFrame.at<Vec3b>(Point(20, 20));
        int color_R = Color[0]; if (color_R < 0) color_R = 0;
        int color_G = Color[1]; if (color_G < 0) color_G = 0;
        int color_B = Color[2]; if (color_B < 0) color_B = 0;


        for (int i = 0; i < 4; i++)
        {
         
        line(OverlapedFrame, BoxCoordinates_Converted[i], BoxCoordinates_Converted[(i + 1) % 4], Scalar(color_R, color_G, color_B), 2, LINE_AA);
        }
    }

}

// ============== THIS WORKS ===================

// Helper func
void DrawBox(Mat& frame, const vector<Point>& points, Scalar color, int thickness = 2)
{
    CV_Assert(points.size() >= 4 && (frame.channels() == 3 || frame.channels() == 4));

    if (frame.channels() == 4)
    {
        vector<Mat> channels(4);
        split(frame, channels);

        Mat colorFrame;
        merge(vector<Mat>{channels[0], channels[1], channels[2]}, colorFrame);

        for (int i = 0; i < 4; i++)
        {
            line(colorFrame, points[i], points[(i + 1) % 4], color, thickness, LINE_AA);
        }

        vector<Mat> bgrChannels(3);
        split(colorFrame, bgrChannels);
        merge(vector<Mat>{bgrChannels[0], bgrChannels[1], bgrChannels[2], channels[3]}, frame);
    }
    else
    {
        for (int i = 0; i < 4; i++)
        {
            line(frame, points[i], points[(i + 1) % 4], color, thickness, LINE_AA);
        }
    }
}

// Let's make it softer <3
void DrawBlurredBox(Mat& frame, const vector<Point>& points, Scalar color,
                 int thickness = 10, int blurSize = 21, float intensity = 1.0f)
{
    CV_Assert(points.size() >= 4 && (frame.channels() == 3 || frame.channels() == 4));
    CV_Assert(blurSize % 2 == 1); // Must be odd for GaussianBlur

    cout << "DrawBlurredBox usando blurSize: " << blurSize << endl;

    Mat mask = Mat::zeros(frame.size(), CV_8UC1);

    for (int i = 0; i < 4; i++)
    {
        line(mask, points[i], points[(i + 1) % 4], Scalar(255), thickness, LINE_AA);
    }

    // Let's blur the mask to soften the edges
    GaussianBlur(mask, mask, Size(blurSize, blurSize), 0);

    Mat colorLayer(frame.size(), frame.type(), Scalar(color[0], color[1], color[2], 0));

    if (frame.channels() == 4)
        colorLayer = Mat(frame.size(), CV_8UC4, Scalar(color[0], color[1], color[2], 255));

    Mat maskF;
    mask.convertTo(maskF, CV_32F, intensity / 255.0);

    if (frame.channels() == 4)
    {
        vector<Mat> frameChannels(4);
        split(frame, frameChannels);

        vector<Mat> colorChannels(4);
        split(colorLayer, colorChannels);

        for (int c = 0; c < 3; ++c) // only B,G,R
        {
            frameChannels[c].convertTo(frameChannels[c], CV_32F);
            colorChannels[c].convertTo(colorChannels[c], CV_32F);
            frameChannels[c] = frameChannels[c].mul(1.0f - maskF) + colorChannels[c].mul(maskF);
            frameChannels[c].convertTo(frameChannels[c], CV_8U);
        }

        merge(frameChannels, frame);
    }
    else
    {
        vector<Mat> frameChannels(3);
        split(frame, frameChannels);

        vector<Mat> colorChannels(3);
        split(colorLayer, colorChannels);

        for (int c = 0; c < 3; ++c)
        {
            frameChannels[c].convertTo(frameChannels[c], CV_32F);
            colorChannels[c].convertTo(colorChannels[c], CV_32F);
            frameChannels[c] = frameChannels[c].mul(1.0f - maskF) + colorChannels[c].mul(maskF);
            frameChannels[c].convertTo(frameChannels[c], CV_8U);
        }

        merge(frameChannels, frame);
    }
}

// Now the real thing
void CVDetection::Overlap_Frames_With_Alpha(
    Mat BaseFrame,
    Mat SecFrame,
    vector<Point2f> BoxCoordinates,
    Mat& OverlapedFrame,
    float displacementX,
    float displacementY,
    bool showBoundingBox,
    Scalar frameColor,
    int frameThickness,
    int blurSize
)
{
    int j, z;
    Vec4b pixel;
    
    // Ensure BaseFrame has 4 channels
    if (BaseFrame.channels() == 3)
        cvtColor(BaseFrame, BaseFrame, COLOR_BGR2BGRA);
    
    // Ensure SecFrame has 4 channels
    if (SecFrame.channels() == 3)
        cvtColor(SecFrame, SecFrame, COLOR_BGR2BGRA);
    
    Mat BaseFrame_Copy = BaseFrame.clone();
    Mat TransformedFrame = Mat::zeros(BaseFrame.size(), CV_8UC4); // Ensure 4 channels for alpha support

    // Projective transformation
    ProjectiveTransformWithInternalDisplacement(SecFrame, BoxCoordinates, TransformedFrame, displacementX, displacementY);

    // Create a mask for the transformed region
    Mat SecFrame_Mask = Mat::zeros(BaseFrame.size(), CV_8UC1);
    std::vector<cv::Point> BoxCoordinates_Converted;
    for (const auto& point : BoxCoordinates)
        BoxCoordinates_Converted.push_back(cv::Point(point.x, point.y));
    
    fillConvexPoly(SecFrame_Mask, BoxCoordinates_Converted, Scalar(255), LINE_AA);
    
    // Invert mask
    Mat SecFrame_Mask_not;
    bitwise_not(SecFrame_Mask, SecFrame_Mask_not);

    // Separate alpha channel from SecFrame
    std::vector<Mat> SecFrame_Channels;
    split(TransformedFrame, SecFrame_Channels);
    Mat SecFrame_Alpha;
    if (SecFrame.channels() == 4)
        SecFrame_Alpha = SecFrame_Channels[3];
    else
        SecFrame_Alpha = Mat::ones(SecFrame.size(), CV_8UC1) * 255;

    // Convert alpha mask to 4-channel
    Mat AlphaMaskF;
    SecFrame_Alpha.convertTo(AlphaMaskF, CV_32F, 1.0 / 255);
    std::vector<Mat> AlphaMaskChannels(4, AlphaMaskF);
    merge(AlphaMaskChannels, AlphaMaskF);

    // Convert images to float for blending
    Mat BaseFrameF, TransformedFrameF;
    BaseFrame.convertTo(BaseFrameF, CV_32FC4);
    TransformedFrame.convertTo(TransformedFrameF, CV_32FC4);

    // Perform alpha blending
    Mat BlendedFrame;
    multiply(BaseFrameF, Scalar::all(1.0) - AlphaMaskF, BaseFrameF);
    multiply(TransformedFrameF, AlphaMaskF, TransformedFrameF);
    add(BaseFrameF, TransformedFrameF, BlendedFrame);

    // Convert back to 8-bit
    BlendedFrame.convertTo(OverlapedFrame, CV_8UC4);

    // ======== UNCOMMENT TO DEBUG ==========
    // ETA: Now an optional feature
    if (showBoundingBox && BoxCoordinates_Converted.size() >= 4 && frameThickness > 0)
    {
        DrawBlurredBox(OverlapedFrame, BoxCoordinates_Converted, frameColor, frameThickness, blurSize);
    }

}

// =========================

/*void Overlap_Frames_With_Alpha(Mat& BaseFrame, Mat& SecFrame, vector<Point2f>& BoxCoordinates, Mat& OverlapedFrame) {
    
    flip(SecFrame, SecFrame, 1);
    
    // Find the perspective transform
    vector<Point2f> SecFrameCorners = { Point2f(0, 0), Point2f(SecFrame.cols - 1, 0), Point2f(SecFrame.cols - 1, SecFrame.rows - 1), Point2f(0, SecFrame.rows - 1) };
    Mat H = getPerspectiveTransform(SecFrameCorners, BoxCoordinates);
    
    // Calculate the size of the transformed SecFrame
    vector<Point2f> transformedCorners(4);
    perspectiveTransform(SecFrameCorners, transformedCorners, H);
    Rect boundingBox = boundingRect(transformedCorners);
    
    // Adjust the base frame size to include overflow
    int newWidth = max(boundingBox.x + boundingBox.width, BaseFrame.cols);
    int newHeight = max(boundingBox.y + boundingBox.height, BaseFrame.rows);
    int offsetX = min(boundingBox.x, 0);
    int offsetY = min(boundingBox.y, 0);
    newWidth = max(newWidth, BaseFrame.cols - offsetX);
    newHeight = max(newHeight, BaseFrame.rows - offsetY);

    Mat newBaseFrame = Mat::zeros(newHeight - offsetY, newWidth - offsetX, BaseFrame.type());
    BaseFrame.copyTo(newBaseFrame(Rect(-offsetX, -offsetY, BaseFrame.cols, BaseFrame.rows)));
    
    // Warp the SecFrame into the size of the new base frame
    Mat SecFrameTransformed = Mat::zeros(newHeight - offsetY, newWidth - offsetX, SecFrame.type());
    warpPerspective(SecFrame, SecFrameTransformed, H, SecFrameTransformed.size(), INTER_LINEAR, BORDER_TRANSPARENT);

    // Handle transparency
    Mat mask;
    if (SecFrameTransformed.channels() == 4) {
        vector<Mat> channels;
        split(SecFrameTransformed, channels);
        mask = channels[3];
        channels.pop_back();
        merge(channels, SecFrameTransformed);
    } else {
        cvtColor(SecFrameTransformed, mask, COLOR_BGR2GRAY);
    }

    // Ensure mask is binary
    threshold(mask, mask, 1, 255, THRESH_BINARY);

    // Convert mask to 3 channels
    Mat mask3;
    Mat maskChannels[] = { mask, mask, mask };
    merge(maskChannels, 3, mask3);

    // Invert the mask
    Mat mask3_inv;
    bitwise_not(mask3, mask3_inv);

    // Create the foreground and background
    Mat background;
    bitwise_and(newBaseFrame, mask3_inv, background);
    Mat foreground;
    bitwise_and(SecFrameTransformed, mask3, foreground);

    // Combine the background and foreground
    add(background, foreground, OverlapedFrame);
}*/

Mat GetOverlapMatrix(Mat& BaseFrame, Mat& SecFrame, vector<Point2f>& BoxCoordinates, Mat& OverlapedFrame) {
    // Find the perspective transform
    vector<Point2f> SecFrameCorners = { Point2f(0, 0), Point2f(SecFrame.cols - 1, 0), Point2f(SecFrame.cols - 1, SecFrame.rows - 1), Point2f(0, SecFrame.rows - 1) };
    Mat H = getPerspectiveTransform(SecFrameCorners, BoxCoordinates);

    return H; // Return the transformation matrix
}

Mat EdicionImagen(Mat frameIn, Mat frameImagenIn, Mat& frameVideoInRotated) {

    if (frameImagenIn.cols > frameImagenIn.rows)
    {
        frameVideoInRotated = Mat(frameImagenIn.rows, frameImagenIn.cols, frameImagenIn.type());
    }
    else {
        frameVideoInRotated = Mat(frameImagenIn.cols, frameImagenIn.rows, frameImagenIn.type());
    }


    if (frameImagenIn.cols > frameImagenIn.rows)
    {
        frameIn.copyTo(frameVideoInRotated);
    }
    else {
        rotate(frameIn, frameVideoInRotated, ROTATE_90_CLOCKWISE);
    }



    return frameVideoInRotated;
}

void rotateImage(const cv::Mat& src, int rotationCode) {
    switch (rotationCode) {
        case 0: // 0 degrees
            break;
        case 1: // 90 degrees clockwise
            cv::rotate(src, src, cv::ROTATE_90_CLOCKWISE);
            break;
        case 2: // 180 degrees
            cv::rotate(src, src, cv::ROTATE_180);
            break;
        case 3: // 270 degrees clockwise (or 90 degrees counterclockwise)
            cv::rotate(src, src, cv::ROTATE_90_COUNTERCLOCKWISE);
            break;
        default:
            std::cerr << "Invalid rotation code. It should be 0, 1, 2, or 3." << std::endl;
    }
}

// ==== HERE ====
void rotateImage(const cv::Mat& src, cv::Mat& dst, int rotationCode) {
    if (src.empty()) {
        std::cerr << "rotateImage: Source image is empty!" << std::endl;
        return;
    }

    // Perform rotation
    switch (rotationCode) {
        case 0: // No rotation
            dst = src.clone();
            return;
        case 1: // 90 degrees clockwise
            cv::rotate(src, dst, cv::ROTATE_90_CLOCKWISE);
            break;
        case 2: // 180 degrees
            cv::rotate(src, dst, cv::ROTATE_180);
            break;
        case 3: // 270 degrees clockwise (or 90 degrees counterclockwise)
            cv::rotate(src, dst, cv::ROTATE_90_COUNTERCLOCKWISE);
            break;
        default:
            std::cerr << "rotateImage: Invalid rotation code. Must be 0, 1, 2, or 3." << std::endl;
            dst = src.clone();
            return;
    }

    // Aspect Ratio Correction: Ensure output size is adjusted properly
    if (rotationCode == 1 || rotationCode == 3) { // 90° or 270°
        int newWidth = src.rows;
        int newHeight = src.cols;
        cv::resize(dst, dst, cv::Size(newWidth, newHeight));
    }
}

// HELPER
Point2f getCenter(const vector<Point2f>& BoxCoordinates) {
    Point2f center(0.0f, 0.0f);
    for (const auto& point : BoxCoordinates) {
        center.x += point.x;
        center.y += point.y;
    }
    center.x /= BoxCoordinates.size();
    center.y /= BoxCoordinates.size();
    return center;
}

// Original
Mat CVDetection::processAruco(Mat image,Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, float rotation) {
    Mat ImagenMarcadores;//(1920, 1080, CV_8UC3,Scalar(0,0,0));
    Mat overlayRotated;
    Mat overlayRGB;
    int i_rotationImage = static_cast<int>(std::round(rotation));
    if (image.channels() == 4) {
        cv::cvtColor(image, ImagenMarcadores, COLOR_BGRA2BGR);
    }
    
    if (overlay.channels() == 4) {
        cv::cvtColor(overlay, overlayRGB, COLOR_BGRA2BGR);
    }
    
    // A continuacion giramos la imagen de overlay dependiendo del slider
    rotateImage(overlayRGB,i_rotationImage);
    EdicionImagen(overlayRGB, overlayRGB, overlayRotated);
    
    //Mat src = image.clone(); // Create a copy of the input image to avoid modifying the original
    //image.copyTo(src);
    Mat OverlapedFrame = ImagenMarcadores.clone();
    
    Size s = ImagenMarcadores.size();
    double w = s.width;
    double h = s.height;
    
    //RAFAEL MODIFICATIONS: variables related with the board creation
    int markerX = 5;
    int markerY = 7;
    float markerLength = 70;//2112;//70;//70;//0.022;//70;
    float markerSeparation = 7;//288;//7;//7;//0.003;//7;
    int dictionaryId = DICT_6X6_250;
    Mat camMatrix, distCoeffs;
    Vec3d rvec, tvec;
    Mat grayImagenMarcadores;
    //double lapmin, lapmax;

    std::vector<int> markerIds;
    std::vector<std::vector<cv::Point2f>> markerCorners, rejectedCandidates;
    cv::aruco::DetectorParameters detectorParams = cv::aruco::DetectorParameters();
    cv::aruco::Dictionary dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
    cv::Ptr<cv::aruco::Dictionary> dictionaryPtr = cv::makePtr<cv::aruco::Dictionary>(dictionary);
    cv::aruco::ArucoDetector detector(dictionary, detectorParams);
    std::vector<cv::Point2f> BoxCoordinates;
    vector<Point3f> MarcoBoard;
    map<int, vector<Point2f>> farthestCorners;
    // ---------------------------- RAFAEL MODIFICATIONS
    // ----------------- PARAMETROS QUE PUEDES MODIFICAR NIL PARA MEJORAR LA DETECCION DE MARCADORES .vibracion --------
    detectorParams.adaptiveThreshWinSizeMin = 5;
    detectorParams.adaptiveThreshWinSizeMax = 25;
    detectorParams.adaptiveThreshWinSizeStep = 5;
    detectorParams.minMarkerPerimeterRate = 0.02;
    detectorParams.maxMarkerPerimeterRate = 0.5;
    detectorParams.polygonalApproxAccuracyRate = 0.02;
    detectorParams.minCornerDistanceRate = 0.05;
    detectorParams.minDistanceToBorder = 3;
    detectorParams.minMarkerDistanceRate = 0.05;
    // ------------------ FIN DE PARAMETROS QUE PUEDES MODIFICAR -------------------------------------------
    
    // Filtro de Kalman para suavizar rvec y tvec
    
    cv::KalmanFilter kf(6, 6, 0);
    cv::Mat state(6, 1, CV_32F); // [x, y, z, dx, dy, dz]
    cv::Mat meas(6, 1, CV_32F);  // [x, y, z, dx, dy, dz]

    // Inicializar el filtro de Kalman
    kf.transitionMatrix = (cv::Mat_<float>(6, 6) <<
                           1, 0, 0, 1, 0, 0,
                           0, 1, 0, 0, 1, 0,
                           0, 0, 1, 0, 0, 1,
                           0, 0, 0, 1, 0, 0,
                           0, 0, 0, 0, 1, 0,
                           0, 0, 0, 0, 0, 1);

    setIdentity(kf.measurementMatrix);
    setIdentity(kf.processNoiseCov, cv::Scalar::all(1e-5));
    setIdentity(kf.measurementNoiseCov, cv::Scalar::all(1e-1));
    setIdentity(kf.errorCovPost, cv::Scalar::all(1));
    // Step 1: Read camera parameters:
    bool readOk = readCameraParameters(camMatrix, distCoeffs, image.size().width, image.size().height);
    if (!readOk) {
       cout << "Invalid camera file" << endl;
    }
    
    //vibracion probar
    static std::vector<MovingAverageFilter> filters(4, MovingAverageFilter(1));
    
    for (int i = 0; i < 4; ++i) {
           filters.emplace_back(MovingAverageFilter(1));
    }
    
    // Step 2: creation of Pointer to board.
    // Ptr<aruco::GridBoard>gridboard=aruco::GridBoard.create(markerX,markerY,markerLength,markerSeparation,dictionary);
    aruco::Board gridboard = GridBoard(Size(markerX, markerY), markerLength, markerSeparation, dictionary);
    cv::Ptr<aruco::Board> gridboardPtr = cv::makePtr<aruco::Board>(gridboard);
    
    // Step 3: Markers detection
    int markersOfBoardDetected = 0; // Variable to know how many markers the program has found.
    
    cvtColor(ImagenMarcadores, grayImagenMarcadores, COLOR_BGR2GRAY);
    aruco::detectMarkers(grayImagenMarcadores, dictionaryPtr, markerCorners,markerIds);
    // Step 4: Estimate the position of the board.
    if (markerIds.size()>=4 && readOk)
    {
        markersOfBoardDetected =aruco::estimatePoseBoard(markerCorners, markerIds, gridboardPtr, camMatrix, distCoeffs, rvec, tvec);
        
        if(!ImagenMarcadores.empty() && markerCorners.size()>0 && false){
            aruco::drawDetectedMarkers(ImagenMarcadores, markerCorners, markerIds, Scalar(0, 255, 0));
        }
        //float LongitudPoroyeccionLargo = ((float)max(markerX, markerY) * ((markerLength + markerSeparation)-1) );
        //float LongitudPoroyeccionAlto = ((float)min(markerX, markerY) * ((markerLength + markerSeparation) -1));
        
        float LongitudPoroyeccionLargo = ((float)max(markerX, markerY) * markerLength) + ((float)max(markerX, markerY) - 1)*markerSeparation;
        float LongitudPoroyeccionAlto = ((float)min(markerX, markerY) * markerLength) + ((float)min(markerX, markerY) - 1)*markerSeparation;
        if (markersOfBoardDetected > 0)
        {
            float newSize = (float)increaseBoardSize/50;
            MarcoBoard.push_back(Point3f(-newSize*LongitudPoroyeccionAlto, -newSize*LongitudPoroyeccionLargo,0));
            MarcoBoard.push_back(Point3f(-newSize*LongitudPoroyeccionAlto, LongitudPoroyeccionLargo*(1 + newSize),0));
            MarcoBoard.push_back(Point3f(LongitudPoroyeccionAlto*(1 + newSize), LongitudPoroyeccionLargo *(1 + newSize),0));
            MarcoBoard.push_back(Point3f(LongitudPoroyeccionAlto*(1 + newSize) , -newSize*LongitudPoroyeccionLargo,0));
                 
            cv::projectPoints(MarcoBoard, rvec, tvec, camMatrix, distCoeffs, BoxCoordinates);
         
            
            // Comparation between actual point array with the previous one.
            if (BoxCoordinates.size()>3 && boxCoordinates_last.size() > 3 && distancia>0)
            {
                
                for (size_t i = 0; i < BoxCoordinates.size(); ++i) {
                    BoxCoordinates[i] = filters[i].apply(BoxCoordinates[i]);
                }
                int X1_ini = boxCoordinates_last[0].x;
                int X2_ini = boxCoordinates_last[1].x;
                int Y1_ini = boxCoordinates_last[0].y;
                int Y2_ini = boxCoordinates_last[1].y;
                int X1_fin = BoxCoordinates[0].x;
                int X2_fin = BoxCoordinates[1].x;
                int Y1_fin = BoxCoordinates[0].y;
                int Y2_fin = BoxCoordinates[1].y;
                float P1_distancia = sqrt(pow((X1_fin - X1_ini), 2) + pow((Y1_fin - Y1_ini),2));
                float P2_distancia = sqrt(pow((X2_fin - X2_ini), 2) + pow((Y2_fin - Y2_ini), 2));
                if ((P1_distancia < distancia) || (P2_distancia < distancia)) {
                     BoxCoordinates = boxCoordinates_last;
                }

            }
            
            boxCoordinates_last = BoxCoordinates;
        }
        
         Overlap_Frames(ImagenMarcadores, overlayRotated, BoxCoordinates, OverlapedFrame);
        
        
    }
        
         OverlapedFrame.convertTo(OverlapedFrame, -1, 1, -20);
        
         cv::GaussianBlur(OverlapedFrame, OverlapedFrame, Size(3,3), BORDER_CONSTANT);
         
         
         return OverlapedFrame;
         
    
}

/********************************/

Mat CVDetection::processArucoNew(Mat image,Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, float rotation, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions) {
    Mat ImagenMarcadores;//(1920, 1080, CV_8UC3,Scalar(0,0,0));
    Mat overlayRotated;
    Mat overlayRGB;
    Mat overlayText;
    Mat transformMatrix;
    int i_rotationImage = static_cast<int>(std::round(rotation));
    if (image.channels() == 4) {
        cv::cvtColor(image, ImagenMarcadores, COLOR_BGRA2BGR);
    }
    
    if (overlay.channels() == 4) {
        cv::cvtColor(overlay, overlayRGB, COLOR_BGRA2BGR);
    }
    
    // A continuacion giramos la imagen de overlay dependiendo del slider
    rotateImage(overlayRGB,i_rotationImage);
    EdicionImagen(overlayRGB, overlayRGB, overlayRotated);
    
    //Mat src = image.clone(); // Create a copy of the input image to avoid modifying the original
    //image.copyTo(src);
    Mat OverlapedFrame = ImagenMarcadores.clone();
    Mat OverlapedFrame2 = ImagenMarcadores.clone();
    
    Size s = ImagenMarcadores.size();
    double w = s.width;
    double h = s.height;
    
    /****************************************/
    
    //RAFAEL MODIFICATIONS: variables related with the board creation
    int markerX = 5;
    int markerY = 7;
    float markerLength = 70;//2112;//70;//70;//0.022;//70;
    float markerSeparation = 7;//288;//7;//7;//0.003;//7;
    int dictionaryId = DICT_6X6_250;
    Mat camMatrix, distCoeffs;
    Vec3d rvec, tvec;
    Mat grayImagenMarcadores;
    //double lapmin, lapmax;

    std::vector<int> markerIds;
    std::vector<std::vector<cv::Point2f>> markerCorners, rejectedCandidates;
    cv::aruco::DetectorParameters detectorParams = cv::aruco::DetectorParameters();
    cv::aruco::Dictionary dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
    cv::Ptr<cv::aruco::Dictionary> dictionaryPtr = cv::makePtr<cv::aruco::Dictionary>(dictionary);
    cv::aruco::ArucoDetector detector(dictionary, detectorParams);
    std::vector<cv::Point2f> BoxCoordinates;
    vector<Point3f> MarcoBoard;
    map<int, vector<Point2f>> farthestCorners;
    // ---------------------------- RAFAEL MODIFICATIONS
    // ----------------- PARAMETROS QUE PUEDES MODIFICAR NIL PARA MEJORAR LA DETECCION DE MARCADORES .vibracion --------
    detectorParams.adaptiveThreshWinSizeMin = 5;
    detectorParams.adaptiveThreshWinSizeMax = 25;
    detectorParams.adaptiveThreshWinSizeStep = 5;
    detectorParams.minMarkerPerimeterRate = 0.02;
    detectorParams.maxMarkerPerimeterRate = 0.5;
    detectorParams.polygonalApproxAccuracyRate = 0.02;
    detectorParams.minCornerDistanceRate = 0.05;
    detectorParams.minDistanceToBorder = 3;
    detectorParams.minMarkerDistanceRate = 0.05;
    // ------------------ FIN DE PARAMETROS QUE PUEDES MODIFICAR -------------------------------------------
    
    // Filtro de Kalman para suavizar rvec y tvec
    
    cv::KalmanFilter kf(6, 6, 0);
    cv::Mat state(6, 1, CV_32F); // [x, y, z, dx, dy, dz]
    cv::Mat meas(6, 1, CV_32F);  // [x, y, z, dx, dy, dz]

    // Inicializar el filtro de Kalman
    kf.transitionMatrix = (cv::Mat_<float>(6, 6) <<
                           1, 0, 0, 1, 0, 0,
                           0, 1, 0, 0, 1, 0,
                           0, 0, 1, 0, 0, 1,
                           0, 0, 0, 1, 0, 0,
                           0, 0, 0, 0, 1, 0,
                           0, 0, 0, 0, 0, 1);

    setIdentity(kf.measurementMatrix);
    setIdentity(kf.processNoiseCov, cv::Scalar::all(1e-5));
    setIdentity(kf.measurementNoiseCov, cv::Scalar::all(1e-1));
    setIdentity(kf.errorCovPost, cv::Scalar::all(1));
    // Step 1: Read camera parameters:
    bool readOk = readCameraParameters(camMatrix, distCoeffs, image.size().width, image.size().height);
    if (!readOk) {
       cout << "Invalid camera file" << endl;
    }
    
    //vibracion probar
    static std::vector<MovingAverageFilter> filters(4, MovingAverageFilter(1));
    
    for (int i = 0; i < 4; ++i) {
           filters.emplace_back(MovingAverageFilter(1));
    }
    
    // Step 2: creation of Pointer to board.
    // Ptr<aruco::GridBoard>gridboard=aruco::GridBoard.create(markerX,markerY,markerLength,markerSeparation,dictionary);
    aruco::Board gridboard = GridBoard(Size(markerX, markerY), markerLength, markerSeparation, dictionary);
    cv::Ptr<aruco::Board> gridboardPtr = cv::makePtr<aruco::Board>(gridboard);
    
    // Step 3: Markers detection
    int markersOfBoardDetected = 0; // Variable to know how many markers the program has found.
    
    cvtColor(ImagenMarcadores, grayImagenMarcadores, COLOR_BGR2GRAY);
    aruco::detectMarkers(grayImagenMarcadores, dictionaryPtr, markerCorners,markerIds);
    // Step 4: Estimate the position of the board.
    if (markerIds.size()>=4 && readOk)
    {
        markersOfBoardDetected =aruco::estimatePoseBoard(markerCorners, markerIds, gridboardPtr, camMatrix, distCoeffs, rvec, tvec);
        
        if(!ImagenMarcadores.empty() && markerCorners.size()>0 && false){
            aruco::drawDetectedMarkers(ImagenMarcadores, markerCorners, markerIds, Scalar(0, 255, 0));
        }
        //float LongitudPoroyeccionLargo = ((float)max(markerX, markerY) * ((markerLength + markerSeparation)-1) );
        //float LongitudPoroyeccionAlto = ((float)min(markerX, markerY) * ((markerLength + markerSeparation) -1));
        
        float LongitudPoroyeccionLargo = ((float)max(markerX, markerY) * markerLength) + ((float)max(markerX, markerY) - 1)*markerSeparation;
        float LongitudPoroyeccionAlto = ((float)min(markerX, markerY) * markerLength) + ((float)min(markerX, markerY) - 1)*markerSeparation;
        if (markersOfBoardDetected > 0)
        {
            float newSize = (float)increaseBoardSize/50;
            MarcoBoard.push_back(Point3f(-newSize*LongitudPoroyeccionAlto, -newSize*LongitudPoroyeccionLargo,0));
            MarcoBoard.push_back(Point3f(-newSize*LongitudPoroyeccionAlto, LongitudPoroyeccionLargo*(1 + newSize),0));
            MarcoBoard.push_back(Point3f(LongitudPoroyeccionAlto*(1 + newSize), LongitudPoroyeccionLargo *(1 + newSize),0));
            MarcoBoard.push_back(Point3f(LongitudPoroyeccionAlto*(1 + newSize) , -newSize*LongitudPoroyeccionLargo,0));
                 
            cv::projectPoints(MarcoBoard, rvec, tvec, camMatrix, distCoeffs, BoxCoordinates);
            
            // Comparation between actual point array with the previous one.
            if (BoxCoordinates.size()>3 && boxCoordinates_last.size() > 3 && distancia>0)
            {
                
                for (size_t i = 0; i < BoxCoordinates.size(); ++i) {
                    BoxCoordinates[i] = filters[i].apply(BoxCoordinates[i]);
                }
                int X1_ini = boxCoordinates_last[0].x;
                int X2_ini = boxCoordinates_last[1].x;
                int Y1_ini = boxCoordinates_last[0].y;
                int Y2_ini = boxCoordinates_last[1].y;
                int X1_fin = BoxCoordinates[0].x;
                int X2_fin = BoxCoordinates[1].x;
                int Y1_fin = BoxCoordinates[0].y;
                int Y2_fin = BoxCoordinates[1].y;
                float P1_distancia = sqrt(pow((X1_fin - X1_ini), 2) + pow((Y1_fin - Y1_ini),2));
                float P2_distancia = sqrt(pow((X2_fin - X2_ini), 2) + pow((Y2_fin - Y2_ini), 2));
                if ((P1_distancia < distancia) || (P2_distancia < distancia)) {
                     BoxCoordinates = boxCoordinates_last;
                }

            }
            
            boxCoordinates_last = BoxCoordinates;
        }
        
        Mat CurrentFrame = ImagenMarcadores.clone();
        Overlap_Frames(CurrentFrame, overlayRotated, BoxCoordinates, OverlapedFrame);
        // ==== HERE ====
        //The following two lines add the image exactly over the QR
        CurrentFrame = OverlapedFrame.clone();
        transformMatrix = GetOverlapMatrix(CurrentFrame, overlayRotated, BoxCoordinates, OverlapedFrame);
        //
        this->Overlap_Frames_With_Alpha(CurrentFrame, additionalOverlay, BoxCoordinates, OverlapedFrame, 0, 0);

        
    }
        
    OverlapedFrame.convertTo(OverlapedFrame, -1, 1, -20);
        
    cv::GaussianBlur(OverlapedFrame, OverlapedFrame, Size(3,3), BORDER_CONSTANT);
    
    /*Mat transformedAdditionalOverlay;

    try {
        warpPerspective(additionalOverlay, transformedAdditionalOverlay, transformMatrix, image.size(), INTER_LINEAR, BORDER_TRANSPARENT);
        //Size newSize(transformedAdditionalOverlay.cols * 2, transformedAdditionalOverlay.rows * 2);
            //resize(transformedAdditionalOverlay, transformedAdditionalOverlay, newSize, 0, 0, INTER_LINEAR);
        } catch (const Exception& e) {
            cerr << "Error: " << e.what() << endl;
        } catch (...) {
            cerr << "An unknown error occurred." << endl;
        }
    
        if (!transformedAdditionalOverlay.empty() && transformedAdditionalOverlay.channels() == 4 && BoxCoordinates.size() > 3) {
            Point2f center = getCenter(BoxCoordinates);
            int xCenter = static_cast<int>(center.x);
            int yCenter = static_cast<int>(center.y);

            // Calculate the top-left corner of the overlay
            int startX = xCenter - transformedAdditionalOverlay.cols / 2;
            int startY = yCenter - transformedAdditionalOverlay.rows / 2;

            // Mirror the overlay over the X axis
            Mat mirroredOverlay;
            flip(transformedAdditionalOverlay, mirroredOverlay, 0); // 0 means flipping around the x-axis

            for (int i = 0; i < mirroredOverlay.rows; i++) {
                for (int j = 0; j < mirroredOverlay.cols; j++) {
                    int yPos = startY + i;
                    int xPos = startX + j;

                    if (yPos >= 0 && yPos < OverlapedFrame.rows && xPos >= 0 && xPos < OverlapedFrame.cols) {
                        Vec4b& srcPixel = mirroredOverlay.at<Vec4b>(i, j);
                        if (srcPixel[3] > 0) { // Check alpha channel
                            Vec3b& dstPixel = OverlapedFrame.at<Vec3b>(yPos, xPos);
                            float alpha = srcPixel[3] / 255.0;
                            for (int c = 0; c < 3; c++) {
                                dstPixel[c] = (1 - alpha) * dstPixel[c] + alpha * srcPixel[c];
                            }
                        }
                    }
                }
            }
        }*/


    
    // Overlay the additional image at each specified position
       /* if (!additionalOverlay.empty() && additionalOverlay.channels() == 4 && BoxCoordinates.size()>3) {
            Point2f center = getCenter(BoxCoordinates);
            for (const auto& overlayPosition : overlayPositions) {
                int x = static_cast<int>(center.x);
                int y = static_cast<int>(center.y);
                
                for (int i = 0; i < additionalOverlay.rows; i++) {
                    for (int j = 0; j < additionalOverlay.cols; j++) {
                        if (y + i >= 0 && y + i < OverlapedFrame.rows && x + j >= 0 && x + j < OverlapedFrame.cols) {
                            Vec4b& srcPixel = additionalOverlay.at<Vec4b>(i, j);
                            if (srcPixel[3] > 0) { // Check alpha channel
                                Vec3b& dstPixel = OverlapedFrame.at<Vec3b>(y + i, x + j);
                                float alpha = srcPixel[3] / 255.0;
                                for (int c = 0; c < 3; c++) {
                                    dstPixel[c] = (1 - alpha) * dstPixel[c] + alpha * srcPixel[c];
                                }
                            }
                        }
                    }
                }
            }
        }*/
         
         
         return OverlapedFrame;
         
    
}

// ========================== THIS WORKS ============================
Mat CVDetection::processArucoNewWithText(Mat image,Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, int increaseBoardSizeY, float rotation,  int displacementX, int displacementY, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions) {
    Mat ImagenMarcadores;//(1920, 1080, CV_8UC3,Scalar(0,0,0));
    Mat overlayText, transformMatrix, combinedOverlay;
    // Ensure overlays retain their alpha channel
    Mat overlayRGBA, overlayRGBA_temp, additionalOverlayRGBA;
    
    int i_rotationImage = static_cast<int>(std::round(rotation));
    
    if (image.channels() == 4) {
        ImagenMarcadores = image.clone();
    } else {
        cv::cvtColor(image, ImagenMarcadores, COLOR_BGR2BGRA);
    }

    if (!overlay.empty()) {
        if (overlay.channels() == 4) {
            overlayRGBA_temp = overlay.clone();
        } else {
            cv::cvtColor(overlay, overlayRGBA_temp, COLOR_BGR2BGRA);
        }
        // Apply rotation before combining
        rotateImage(overlayRGBA_temp, overlayRGBA, i_rotationImage);
        // THIS NO
        //EdicionImagen(overlayRGBA_temp, overlayRGBA_temp, overlayRGBA);
    }

    if (!additionalOverlay.empty()) {
        if (additionalOverlay.channels() == 4) {
            additionalOverlayRGBA = additionalOverlay.clone();
        } else {
            cv::cvtColor(additionalOverlay, additionalOverlayRGBA, COLOR_BGR2BGRA);
        }
    }

    // Validate before proceeding
    if (overlayRGBA.empty() || additionalOverlayRGBA.empty()) {
        throw std::runtime_error("One or both overlay images are empty!");
    }
    
    // Scale overlay
       float scaleX = 1.0f + (static_cast<float>(increaseBoardSize) / 20.0f);
       float scaleY = 1.0f + (static_cast<float>(increaseBoardSizeY) / 20.0f);
       Mat scaledOverlay;
       resize(overlayRGBA, scaledOverlay, Size(), scaleX, scaleY, INTER_LINEAR);

       // Define final dimensions
       int combinedHeight = scaledOverlay.rows + additionalOverlayRGBA.rows;
       int maxWidth = std::max(scaledOverlay.cols, additionalOverlayRGBA.cols);
       combinedOverlay = Mat(combinedHeight, maxWidth, CV_8UC4, Scalar(0, 0, 0, 0));

       // Positioning for stacking
       int scaledOverlayX = (maxWidth - scaledOverlay.cols) / 2;
       int scaledOverlayY = 0;
       int additionalOverlayX = (maxWidth - additionalOverlayRGBA.cols) / 2;
       int additionalOverlayY = scaledOverlay.rows; // Ensure proper stacking

       // Copy overlays into combinedOverlay
       scaledOverlay.copyTo(combinedOverlay(Rect(scaledOverlayX, scaledOverlayY, scaledOverlay.cols, scaledOverlay.rows)));
       additionalOverlayRGBA.copyTo(combinedOverlay(Rect(additionalOverlayX, additionalOverlayY, additionalOverlayRGBA.cols, additionalOverlayRGBA.rows)));

       Mat OverlapedFrame = ImagenMarcadores.clone();
       Mat OverlapedFrame2 = ImagenMarcadores.clone();
    
    Size s = ImagenMarcadores.size();
    double w = s.width;
    double h = s.height;
    
    // ******************** RAFAEL MODIFICATIONS: variables related with the board creation
    int markerX = 5;
    int markerY = 7;
    float markerLength = 70;//2112;//70;//70;//0.022;//70;
    float markerSeparation = 7;//288;//7;//7;//0.003;//7;
    int dictionaryId = DICT_6X6_250;
    Mat camMatrix, distCoeffs;
    Vec3d rvec, tvec;
    Mat grayImagenMarcadores;
    //double lapmin, lapmax;

    std::vector<int> markerIds;
    std::vector<std::vector<cv::Point2f>> markerCorners, rejectedCandidates;
    cv::aruco::DetectorParameters detectorParams = cv::aruco::DetectorParameters();
    cv::aruco::Dictionary dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
    cv::Ptr<cv::aruco::Dictionary> dictionaryPtr = cv::makePtr<cv::aruco::Dictionary>(dictionary);
    cv::aruco::ArucoDetector detector(dictionary, detectorParams);
    std::vector<cv::Point2f> BoxCoordinates;
    vector<Point3f> MarcoBoard;
    map<int, vector<Point2f>> farthestCorners;
    // ---------------------------- RAFAEL MODIFICATIONS
    // ----------------- PARAMETROS QUE PUEDES MODIFICAR NIL PARA MEJORAR LA DETECCION DE MARCADORES .vibracion --------
    detectorParams.adaptiveThreshWinSizeMin = 5;
    detectorParams.adaptiveThreshWinSizeMax = 25;
    detectorParams.adaptiveThreshWinSizeStep = 5;
    detectorParams.minMarkerPerimeterRate = 0.02;
    detectorParams.maxMarkerPerimeterRate = 0.5;
    detectorParams.polygonalApproxAccuracyRate = 0.02;
    detectorParams.minCornerDistanceRate = 0.05;
    detectorParams.minDistanceToBorder = 3;
    detectorParams.minMarkerDistanceRate = 0.05;
    // ------------------ FIN DE PARAMETROS QUE PUEDES MODIFICAR -------------------------------------------
    
    // Filtro de Kalman para suavizar rvec y tvec
    
    cv::KalmanFilter kf(6, 6, 0);
    cv::Mat state(6, 1, CV_32F); // [x, y, z, dx, dy, dz]
    cv::Mat meas(6, 1, CV_32F);  // [x, y, z, dx, dy, dz]

    // Inicializar el filtro de Kalman
    kf.transitionMatrix = (cv::Mat_<float>(6, 6) <<
                           1, 0, 0, 1, 0, 0,
                           0, 1, 0, 0, 1, 0,
                           0, 0, 1, 0, 0, 1,
                           0, 0, 0, 1, 0, 0,
                           0, 0, 0, 0, 1, 0,
                           0, 0, 0, 0, 0, 1);

    setIdentity(kf.measurementMatrix);
    setIdentity(kf.processNoiseCov, cv::Scalar::all(1e-5));
    setIdentity(kf.measurementNoiseCov, cv::Scalar::all(1e-1));
    setIdentity(kf.errorCovPost, cv::Scalar::all(1));
    // Step 1: Read camera parameters:
    bool readOk = readCameraParameters(camMatrix, distCoeffs, image.size().width, image.size().height);
    if (!readOk) {
       cout << "Invalid camera file" << endl;
    }
    
    //vibracion probar
    static std::vector<MovingAverageFilter> filters(4, MovingAverageFilter(1));
    
    for (int i = 0; i < 4; ++i) {
           filters.emplace_back(MovingAverageFilter(1));
    }
    
    // Step 2: creation of Pointer to board.

    aruco::Board gridboard = GridBoard(Size(markerX, markerY), markerLength, markerSeparation, dictionary);
    cv::Ptr<aruco::Board> gridboardPtr = cv::makePtr<aruco::Board>(gridboard);
    
    // Step 3: Markers detection
    int markersOfBoardDetected = 0; // Variable to know how many markers the program has found.
    
    cvtColor(ImagenMarcadores, grayImagenMarcadores, COLOR_BGR2GRAY);
    aruco::detectMarkers(grayImagenMarcadores, dictionaryPtr, markerCorners,markerIds);
    // Step 4: Estimate the position of the board.
    if (markerIds.size()>=4 && readOk)
    {
        markersOfBoardDetected =aruco::estimatePoseBoard(markerCorners, markerIds, gridboardPtr, camMatrix, distCoeffs, rvec, tvec);
        
        if(!ImagenMarcadores.empty() && markerCorners.size()>0 && false){
            aruco::drawDetectedMarkers(ImagenMarcadores, markerCorners, markerIds, Scalar(0, 255, 0));
        }
        
        if (markersOfBoardDetected > 0)
        {
            float scaleFactor = static_cast<float>(increaseBoardSize) / 20;
            float scaleFactorY = static_cast<float>(increaseBoardSizeY) / 20;
            float boardWidth = (max(markerX, markerY) * markerLength) + ((max(markerX, markerY) - 1) * markerSeparation);
            float boardHeight = (min(markerX, markerY) * markerLength) + ((min(markerX, markerY) - 1) * markerSeparation);

            MarcoBoard.push_back(Point3f(-scaleFactorY * boardHeight, -scaleFactor * boardWidth, 0));
            MarcoBoard.push_back(Point3f(-scaleFactorY * boardHeight, boardWidth * (1 + scaleFactor), 0));
            MarcoBoard.push_back(Point3f(boardHeight * (1 + scaleFactorY), boardWidth * (1 + scaleFactor), 0));
            MarcoBoard.push_back(Point3f(boardHeight * (1 + scaleFactorY), -scaleFactor * boardWidth, 0));
                 
            cv::projectPoints(MarcoBoard, rvec, tvec, camMatrix, distCoeffs, BoxCoordinates);
            
            // Comparation between actual point array with the previous one.
            if (BoxCoordinates.size()>3 && boxCoordinates_last.size() > 3 && distancia>0)
            {
                
                for (size_t i = 0; i < BoxCoordinates.size(); ++i) {
                    BoxCoordinates[i] = filters[i].apply(BoxCoordinates[i]);
                }
                int X1_ini = boxCoordinates_last[0].x;
                int X2_ini = boxCoordinates_last[1].x;
                int Y1_ini = boxCoordinates_last[0].y;
                int Y2_ini = boxCoordinates_last[1].y;
                int X1_fin = BoxCoordinates[0].x;
                int X2_fin = BoxCoordinates[1].x;
                int Y1_fin = BoxCoordinates[0].y;
                int Y2_fin = BoxCoordinates[1].y;
                float P1_distancia = sqrt(pow((X1_fin - X1_ini), 2) + pow((Y1_fin - Y1_ini),2));
                float P2_distancia = sqrt(pow((X2_fin - X2_ini), 2) + pow((Y2_fin - Y2_ini), 2));
                if ((P1_distancia < distancia) || (P2_distancia < distancia)) {
                     BoxCoordinates = boxCoordinates_last;
                }

            }
            
            boxCoordinates_last = BoxCoordinates;
        }
        
        // ==== HERE ====
        cv::rotate(combinedOverlay, combinedOverlay, cv::ROTATE_90_COUNTERCLOCKWISE);
        
        //The following two lines add the image exactly over the QR
        Mat CurrentFrame = OverlapedFrame.clone();
        
        // What does this do?
        /*transformMatrix = GetOverlapMatrix(CurrentFrame, combinedOverlay, BoxCoordinates, OverlapedFrame);*/
        
        this->Overlap_Frames_With_Alpha(CurrentFrame, combinedOverlay, BoxCoordinates, OverlapedFrame, displacementX, displacementY);

    }
        
    OverlapedFrame.convertTo(OverlapedFrame, -1, 1, -20);
        
    cv::GaussianBlur(OverlapedFrame, OverlapedFrame, Size(3,3), BORDER_CONSTANT);
    
    // Flip the image vertically to correct the upside-down issue
    cv::flip(OverlapedFrame, OverlapedFrame, 0);
         
    return OverlapedFrame;
   
}
// =====================================================

// =============== EXPERIMENT: SEPARATED LAYERS =======================
Mat CVDetection::processArucoNewWithTextSeparated(Mat image,Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, int increaseBoardSizeY, float rotation,  int displacementX, int displacementY, float textDisplacementX, float textDisplacementY, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions, Scalar frameColor, float frameWidth, int blurSize) {
    Mat ImagenMarcadores;//(1920, 1080, CV_8UC3,Scalar(0,0,0));
    Mat overlayText, transformMatrix;
    // Ensure overlays retain their alpha channel
    Mat overlayRGBA, overlayRGBA_temp, additionalOverlayRGBA;
    
    int i_rotationImage = static_cast<int>(std::round(rotation));
    
    if (image.channels() == 4) {
        ImagenMarcadores = image.clone();
    } else {
        cv::cvtColor(image, ImagenMarcadores, COLOR_BGR2BGRA);
    }

    if (!overlay.empty()) {
        if (overlay.channels() == 4) {
            overlayRGBA_temp = overlay.clone();
        } else {
            cv::cvtColor(overlay, overlayRGBA_temp, COLOR_BGR2BGRA);
        }
        // Apply rotation before combining
        rotateImage(overlayRGBA_temp, overlayRGBA, i_rotationImage);
        // THIS NO
        //EdicionImagen(overlayRGBA_temp, overlayRGBA_temp, overlayRGBA);
    }

    if (!additionalOverlay.empty()) {
        if (additionalOverlay.channels() == 4) {
            additionalOverlayRGBA = additionalOverlay.clone();
        } else {
            cv::cvtColor(additionalOverlay, additionalOverlayRGBA, COLOR_BGR2BGRA);
        }
    }

    // Validate before proceeding
    if (overlayRGBA.empty() || additionalOverlayRGBA.empty()) {
        throw std::runtime_error("One or both overlay images are empty!");
    }
    
    // Scale overlay
    float scaleX = 1.0f + (static_cast<float>(increaseBoardSize) / 20.0f);
    float scaleY = 1.0f + (static_cast<float>(increaseBoardSizeY) / 20.0f);
    Mat scaledOverlay;
    resize(overlayRGBA, scaledOverlay, Size(), scaleX, scaleY, INTER_LINEAR);

    Mat OverlapedFrame = ImagenMarcadores.clone();
    
    Size s = ImagenMarcadores.size();
    double w = s.width;
    double h = s.height;
    
    // ==================== RAFAEL MODIFICATIONS: variables related with the board creation
    int markerX = 5;
    int markerY = 7;
    float markerLength = 70;//2112;//70;//70;//0.022;//70;
    float markerSeparation = 7;//288;//7;//7;//0.003;//7;
    int dictionaryId = DICT_6X6_250;
    Mat camMatrix, distCoeffs;
    Vec3d rvec, tvec;
    Mat grayImagenMarcadores;
    //double lapmin, lapmax;

    std::vector<int> markerIds;
    std::vector<std::vector<cv::Point2f>> markerCorners, rejectedCandidates;
    cv::aruco::DetectorParameters detectorParams = cv::aruco::DetectorParameters();
    cv::aruco::Dictionary dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
    cv::Ptr<cv::aruco::Dictionary> dictionaryPtr = cv::makePtr<cv::aruco::Dictionary>(dictionary);
    cv::aruco::ArucoDetector detector(dictionary, detectorParams);
    std::vector<cv::Point2f> BoxCoordinates;
    vector<Point3f> MarcoBoard;
    map<int, vector<Point2f>> farthestCorners;
    // ---------------------------- RAFAEL MODIFICATIONS
    // ----------------- PARAMETROS QUE PUEDES MODIFICAR NIL PARA MEJORAR LA DETECCION DE MARCADORES .vibracion --------
    detectorParams.adaptiveThreshWinSizeMin = 5;
    detectorParams.adaptiveThreshWinSizeMax = 25;
    detectorParams.adaptiveThreshWinSizeStep = 5;
    detectorParams.minMarkerPerimeterRate = 0.02;
    detectorParams.maxMarkerPerimeterRate = 0.5;
    detectorParams.polygonalApproxAccuracyRate = 0.02;
    detectorParams.minCornerDistanceRate = 0.05;
    detectorParams.minDistanceToBorder = 3;
    detectorParams.minMarkerDistanceRate = 0.05;
    // ------------------ FIN DE PARAMETROS QUE PUEDES MODIFICAR -------------------------------------------
    
    // Filtro de Kalman para suavizar rvec y tvec
    
    cv::KalmanFilter kf(6, 6, 0);
    cv::Mat state(6, 1, CV_32F); // [x, y, z, dx, dy, dz]
    cv::Mat meas(6, 1, CV_32F);  // [x, y, z, dx, dy, dz]

    // Inicializar el filtro de Kalman
    kf.transitionMatrix = (cv::Mat_<float>(6, 6) <<
                           1, 0, 0, 1, 0, 0,
                           0, 1, 0, 0, 1, 0,
                           0, 0, 1, 0, 0, 1,
                           0, 0, 0, 1, 0, 0,
                           0, 0, 0, 0, 1, 0,
                           0, 0, 0, 0, 0, 1);

    setIdentity(kf.measurementMatrix);
    setIdentity(kf.processNoiseCov, cv::Scalar::all(1e-5));
    setIdentity(kf.measurementNoiseCov, cv::Scalar::all(1e-1));
    setIdentity(kf.errorCovPost, cv::Scalar::all(1));
    // Step 1: Read camera parameters:
    bool readOk = readCameraParameters(camMatrix, distCoeffs, image.size().width, image.size().height);
    if (!readOk) {
       cout << "Invalid camera file" << endl;
    }
    
    //vibracion probar
    static std::vector<MovingAverageFilter> filters(4, MovingAverageFilter(1));
    
    for (int i = 0; i < 4; ++i) {
           filters.emplace_back(MovingAverageFilter(1));
    }
    
    // Step 2: creation of Pointer to board.

    aruco::Board gridboard = GridBoard(Size(markerX, markerY), markerLength, markerSeparation, dictionary);
    cv::Ptr<aruco::Board> gridboardPtr = cv::makePtr<aruco::Board>(gridboard);
    
    // Step 3: Markers detection
    int markersOfBoardDetected = 0; // Variable to know how many markers the program has found.
    
    cvtColor(ImagenMarcadores, grayImagenMarcadores, COLOR_BGR2GRAY);
    aruco::detectMarkers(grayImagenMarcadores, dictionaryPtr, markerCorners,markerIds);
    // Step 4: Estimate the position of the board.
    if (markerIds.size()>=4 && readOk)
    {
        markersOfBoardDetected =aruco::estimatePoseBoard(markerCorners, markerIds, gridboardPtr, camMatrix, distCoeffs, rvec, tvec);
        
        if(!ImagenMarcadores.empty() && markerCorners.size()>0 && false){
            aruco::drawDetectedMarkers(ImagenMarcadores, markerCorners, markerIds, Scalar(0, 255, 0));
        }
        
        if (markersOfBoardDetected > 0)
        {
            float scaleFactor = static_cast<float>(increaseBoardSize) / 20;
            float scaleFactorY = static_cast<float>(increaseBoardSizeY) / 20;
            float boardWidth = (max(markerX, markerY) * markerLength) + ((max(markerX, markerY) - 1) * markerSeparation);
            float boardHeight = (min(markerX, markerY) * markerLength) + ((min(markerX, markerY) - 1) * markerSeparation);

            MarcoBoard.push_back(Point3f(-scaleFactorY * boardHeight, -scaleFactor * boardWidth, 0));
            MarcoBoard.push_back(Point3f(-scaleFactorY * boardHeight, boardWidth * (1 + scaleFactor), 0));
            MarcoBoard.push_back(Point3f(boardHeight * (1 + scaleFactorY), boardWidth * (1 + scaleFactor), 0));
            MarcoBoard.push_back(Point3f(boardHeight * (1 + scaleFactorY), -scaleFactor * boardWidth, 0));
                 
            cv::projectPoints(MarcoBoard, rvec, tvec, camMatrix, distCoeffs, BoxCoordinates);
            
            // Comparation between actual point array with the previous one.
            if (BoxCoordinates.size()>3 && boxCoordinates_last.size() > 3 && distancia>0)
            {
                
                for (size_t i = 0; i < BoxCoordinates.size(); ++i) {
                    BoxCoordinates[i] = filters[i].apply(BoxCoordinates[i]);
                }
                int X1_ini = boxCoordinates_last[0].x;
                int X2_ini = boxCoordinates_last[1].x;
                int Y1_ini = boxCoordinates_last[0].y;
                int Y2_ini = boxCoordinates_last[1].y;
                int X1_fin = BoxCoordinates[0].x;
                int X2_fin = BoxCoordinates[1].x;
                int Y1_fin = BoxCoordinates[0].y;
                int Y2_fin = BoxCoordinates[1].y;
                float P1_distancia = sqrt(pow((X1_fin - X1_ini), 2) + pow((Y1_fin - Y1_ini),2));
                float P2_distancia = sqrt(pow((X2_fin - X2_ini), 2) + pow((Y2_fin - Y2_ini), 2));
                if ((P1_distancia < distancia) || (P2_distancia < distancia)) {
                     BoxCoordinates = boxCoordinates_last;
                }

            }
            
            boxCoordinates_last = BoxCoordinates;
        }
        
        // ==== HERE ====
        cv::rotate(scaledOverlay, scaledOverlay, cv::ROTATE_90_COUNTERCLOCKWISE);
        cv::rotate(additionalOverlayRGBA, additionalOverlayRGBA, cv::ROTATE_90_COUNTERCLOCKWISE);
        
        //The following two lines add the image exactly over the QR
        Mat CurrentFrame = OverlapedFrame.clone();
        
        this->Overlap_Frames_With_Alpha(
            CurrentFrame, 
            scaledOverlay, 
            BoxCoordinates, 
            OverlapedFrame, 
            displacementX, 
            displacementY,
            true,
            frameColor,
            frameWidth,
            blurSize
        );
        // ==== OH BOY...
        this->Overlap_Frames_With_Alpha(OverlapedFrame, additionalOverlayRGBA, BoxCoordinates, OverlapedFrame, textDisplacementX, textDisplacementY);

    }
        
    OverlapedFrame.convertTo(OverlapedFrame, -1, 1, -20);
        
    cv::GaussianBlur(OverlapedFrame, OverlapedFrame, Size(3,3), BORDER_CONSTANT);
    
    // Flip the image vertically to correct the upside-down issue
    cv::flip(OverlapedFrame, OverlapedFrame, 0);
         
    return OverlapedFrame;
   
}
// =============================

Mat CVDetection::processArucoNewWithMask(Mat image, Mat overlay, std::vector<cv::Point2f>& boxCoordinates_last, int increaseBoardSize, int increaseBoardSizeY, float rotation, Mat additionalOverlay, std::vector<cv::Point2f> overlayPositions, int red, int green, int blue, int redThreshold, int greenThreshold, int blueThreshold) {
    Mat ImagenMarcadores;
    Mat overlayRotated, overlayRGB, overlayText, transformMatrix;
    int i_rotationImage = static_cast<int>(std::round(rotation));

    if (image.channels() == 4) {
        cv::cvtColor(image, ImagenMarcadores, COLOR_BGRA2BGR);
    } else {
        ImagenMarcadores = image.clone();
    }

    if (overlay.channels() == 4) {
        cv::cvtColor(overlay, overlayRGB, COLOR_BGRA2BGR);
    } else {
        overlayRGB = overlay.clone();
    }

    // Rotate and edit the overlay image
    rotateImage(overlayRGB, i_rotationImage);
    EdicionImagen(overlayRGB, overlayRGB, overlayRotated);

    Mat OverlapedFrame = ImagenMarcadores.clone();
    Mat OverlapedFrame2 = ImagenMarcadores.clone();

    Size s = ImagenMarcadores.size();
    double w = s.width, h = s.height;

    // ArUco marker detection setup
    int markerX = 5, markerY = 7;
    float markerLength = 70, markerSeparation = 7;
    int dictionaryId = DICT_6X6_250;
    Mat camMatrix, distCoeffs;
    Vec3d rvec, tvec;
    Mat grayImagenMarcadores;

    std::vector<int> markerIds;
    std::vector<std::vector<cv::Point2f>> markerCorners;
    
    cv::aruco::Dictionary dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
    cv::Ptr<cv::aruco::Dictionary> dictionaryPtr = cv::makePtr<cv::aruco::Dictionary>(dictionary);

    cv::aruco::ArucoDetector detector(dictionary, cv::aruco::DetectorParameters());

    cvtColor(ImagenMarcadores, grayImagenMarcadores, COLOR_BGR2GRAY);
    
    aruco::detectMarkers(grayImagenMarcadores, dictionaryPtr, markerCorners, markerIds);

    if (markerIds.size() >= 4 && readCameraParameters(camMatrix, distCoeffs, image.size().width, image.size().height)) {
        int markersOfBoardDetected = aruco::estimatePoseBoard(markerCorners, markerIds, cv::makePtr<cv::aruco::Board>(GridBoard(Size(markerX, markerY), markerLength, markerSeparation, dictionary)), camMatrix, distCoeffs, rvec, tvec);

        if (markersOfBoardDetected > 0) {
            std::vector<Point3f> MarcoBoard;
            std::vector<cv::Point2f> BoxCoordinates;
            float scaleFactor = static_cast<float>(increaseBoardSize) / 50;
            float scaleFactorY = static_cast<float>(increaseBoardSizeY) / 50;
            float boardWidth = (max(markerX, markerY) * markerLength) + ((max(markerX, markerY) - 1) * markerSeparation);
            float boardHeight = (min(markerX, markerY) * markerLength) + ((min(markerX, markerY) - 1) * markerSeparation);

            MarcoBoard.push_back(Point3f(-scaleFactorY * boardHeight, -scaleFactor * boardWidth, 0));
            MarcoBoard.push_back(Point3f(-scaleFactorY * boardHeight, boardWidth * (1 + scaleFactor), 0));
            MarcoBoard.push_back(Point3f(boardHeight * (1 + scaleFactorY), boardWidth * (1 + scaleFactor), 0));
            MarcoBoard.push_back(Point3f(boardHeight * (1 + scaleFactorY), -scaleFactor * boardWidth, 0));

            cv::projectPoints(MarcoBoard, rvec, tvec, camMatrix, distCoeffs, BoxCoordinates);
            
            // Update last frame positions
            boxCoordinates_last = BoxCoordinates;

            // Overlay the image
            Mat CurrentFrame = ImagenMarcadores.clone();
            Overlap_Frames(CurrentFrame, overlayRotated, BoxCoordinates, OverlapedFrame);
            
            // Generate occlusion mask with custom color
            Mat occlusionMask = detectColorObjects(ImagenMarcadores, red, green, blue, redThreshold, greenThreshold, blueThreshold);
            
            //return occlusionMask;
            
            // Apply occlusion mask
            OverlapedFrame.copyTo(CurrentFrame, ~occlusionMask);
            OverlapedFrame = CurrentFrame.clone();
        }
    }

    // Convert and blur the final frame
    OverlapedFrame.convertTo(OverlapedFrame, -1, 1, -20);
    cv::GaussianBlur(OverlapedFrame, OverlapedFrame, Size(3, 3), BORDER_CONSTANT);

    // Flip the image vertically to correct the upside-down issue
    cv::flip(OverlapedFrame, OverlapedFrame, 0);

    return OverlapedFrame;

}

Mat CVDetection::detectRedObjects(const Mat& image) {
    static Mat smoothedMask;
    Mat redChannel, greenChannel, blueChannel, finalMask;

    // Split the image into its RGB channels
    vector<Mat> channels;
    split(image, channels);

    // Extract the red, green, and blue channels
    redChannel = channels[0];
    greenChannel = channels[1];
    blueChannel = channels[2];

    // Create a binary mask where red pixels dominate (high red and low green and blue)
    inRange(redChannel, 100, 255, finalMask);  // Red values between 100 and 255
    Mat maskLowGreen, maskLowBlue;
    inRange(greenChannel, 0, 80, maskLowGreen);  // Green values should be low (0-100)
    inRange(blueChannel, 0, 80, maskLowBlue);  // Blue values should also be low (0-100)

    // Combine the conditions for red objects (Red high, Green and Blue low)
    bitwise_and(finalMask, maskLowGreen, finalMask);
    bitwise_and(finalMask, maskLowBlue, finalMask);

    // Morphological operations to clean up noise
    Mat kernel = getStructuringElement(MORPH_ELLIPSE, Size(7, 7));
    morphologyEx(finalMask, finalMask, MORPH_CLOSE, kernel);
    morphologyEx(finalMask, finalMask, MORPH_OPEN, kernel);
    
    // Smooth Borders with Gaussian Blur
    GaussianBlur(finalMask, finalMask, Size(5, 5), 2.0);

    return finalMask;
}

Mat CVDetection::detectColorObjects(const Mat& image, int red, int green, int blue, int redThreshold = 0, int greenThreshold = 0, int blueThreshold = 0) {
    Mat colorMask;
    vector<Mat> channels;
    split(image, channels);

    // OpenCV uses BGR order // LIES!!!
    Mat blueChannel = channels[2];
    Mat greenChannel = channels[1];
    Mat redChannel = channels[0];

    // Define lower and upper bounds for each channel
    int lowRed = max(0, red - redThreshold);
    int highRed = min(255, red + redThreshold);
    int lowGreen = max(0, green - greenThreshold);
    int highGreen = min(255, green + greenThreshold);
    int lowBlue = max(0, blue - blueThreshold);
    int highBlue = min(255, blue + blueThreshold);

    // Create masks for each color channel within the given range
    Mat redMask, greenMask, blueMask;
    inRange(redChannel, lowRed, highRed, redMask);
    inRange(greenChannel, lowGreen, highGreen, greenMask);
    inRange(blueChannel, lowBlue, highBlue, blueMask);

    // Combine masks to detect the specified color
    bitwise_and(redMask, greenMask, colorMask);
    bitwise_and(colorMask, blueMask, colorMask);

    // Morphological operations to reduce noise
    Mat kernel = getStructuringElement(MORPH_ELLIPSE, Size(7, 7));
    morphologyEx(colorMask, colorMask, MORPH_CLOSE, kernel);
    morphologyEx(colorMask, colorMask, MORPH_OPEN, kernel);

    // Smooth borders with Gaussian Blur
    GaussianBlur(colorMask, colorMask, Size(5, 5), 2.0);

    return colorMask;
}

