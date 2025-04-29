//
//  PermissionsHandler.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 14/03/2024.
//

import AVFoundation
import Photos
import UIKit

public enum PermissionStatus{
    case accessed,denied
}

public class PermissionsHandler{
    
    static func requestCameraPermission(completion: @escaping (PermissionStatus) -> ()) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
            
            if granted {
                print("Camera permission granted")
                DispatchQueue.main.async {
                    completion(.accessed)
                }
            } else {
                print("Camera permission denied")
                DispatchQueue.main.async {
                    completion(.denied)
                }
            }
        })
    }
    
    static func requestMicPermission(completion: @escaping (PermissionStatus) -> ()) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: { (granted: Bool) in
            
            if granted {
                print("Camera permission granted")
                DispatchQueue.main.async {
                    completion(.accessed)
                }
            } else {
                print("Camera permission denied")
                DispatchQueue.main.async {
                    completion(.denied)
                }
            }
        })
    }
    
    
    static func requestPHLibPermission( _ comp: @escaping (PermissionStatus) -> ()){
        PHPhotoLibrary.requestAuthorization { (status) in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Permission granted")
                    comp(.accessed)
                    //                            MFManager.createPixArtAlbum()
                case .denied, .restricted:
                    comp(.denied)
                    print("Permission denied")
                case .notDetermined:
                    comp(.denied)
                    print("Permission not determined")
                case .limited:
                    comp(.denied)
                    print("Permission limited")
                @unknown default:
                    comp(.denied)
                    print("Unknown case")
                }
            }
        }
    }
    
    
    static func alertPHLib(){
        let alert = UIAlertController(title: "Photo Library Access Denied", message: "Please enable access to Photo Library in Settings", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        
        
    }
    static func alertCameraUsage(){
        let alert = UIAlertController(title: "Camera Access Denied", message: "Please enable access to Camera in Settings", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        if let rootViewController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
        
    }
    
    
    
}
