//
//  ImagePicker.swift
//  FaceBodyTools
//
//  Created by Demian Nezhdanov on 23/04/2023.
//

import UIKit


import PhotosUI
import SwiftUI

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var video: URL?
    @Binding var isAppear: Bool
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let pickerController = UIImagePickerController()
        pickerController.delegate = context.coordinator
        pickerController.allowsEditing = true
        pickerController.mediaTypes = ["public.movie"]
        pickerController.sourceType = .photoLibrary
        return pickerController
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate ,UINavigationControllerDelegate{
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//               self.pickerController(picker, didSelect: nil)
            self.parent.isAppear = false
//            PVCoordinator.hidePopView()
           }

           public func imagePickerController(_ picker: UIImagePickerController,
                                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
               guard let url = info[.mediaURL] as? URL else {
                   
                   return
               }
               self.parent.video = (url)
               self.parent.isAppear = false
//               PVCoordinator.hidePopView()
               print("SELECTED URL: \(url)")
               
//               self.pickerController(picker, didSelect: image)
           }

    }
}
