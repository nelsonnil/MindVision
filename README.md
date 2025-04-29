# MindVision Core

Core components of the TrackPlay computer vision system for augmented reality applications.

## Features

- ArUco marker detection and tracking
- Real-time video processing
- Perspective transformations
- Image overlays with alpha channel support
- Color object detection
- Box drawing with blur effects
- Metal rendering framework integration

## Components

### OpenCV Integration

The core of the project is the `CVDetection` class that provides:

- Marker detection with `processAruco` family of methods
- Frame overlapping with `Overlap_Frames` and `Overlap_Frames_With_Alpha`
- Color detection with `detectColorObjects`
- Utility functions for drawing, transformation and image manipulation

### Swift UI Interface

The application uses SwiftUI for the user interface, providing:

- Camera integration
- Live image processing display
- Controls for adjusting parameters
- Visual tools for working with augmented reality content

## Requirements

- Xcode 13.0+
- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- OpenCV 4.x (not included in this repository due to size constraints)
- Metal-compatible device

## Setting Up

1. Clone this repository
2. You'll need to add the OpenCV framework (opencv2.framework) to the project
3. Configure the project to use the framework
4. Build and run the application

## Note

This repository does not include the OpenCV framework binary files due to GitHub file size limits. You'll need to download OpenCV separately and add it to your project.

## License

Copyright © 2021-2024 Nelson Suarez Arteaga 