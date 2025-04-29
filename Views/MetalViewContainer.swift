//
//  MetalViewContainer.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 10/03/2024.
//

import Foundation
import SwiftUI
import MetalKit


struct MetalViewContainer: UIViewRepresentable {
    var model: MainViewController
    
    func makeUIView(context: Context) -> UIView {

        return model.mtlView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {

        print("updateUIView")
        
    }
    
}

