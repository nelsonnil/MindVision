//
//  MainViewLayout.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 10/03/2024.
//

import SwiftUI
public class MainViewLayout: ObservableObject {
    
    @Published var framePos:CGPoint = .zero
    @Published var previewFrame:CGSize = .zero
    @Published var proxyFrame:CGRect = .zero
    @Published var previewScale:CGFloat = 0.9
//    @Published public var itemsSelected = false
//    @Published public var selectingItems = false
//    @Published public var onItemView = false
    @Published var bottom:CGFloat = 60
    
    @Published var topBarHeight:CGFloat = 0
    @Published var bottomBarHeight:CGFloat = 0
    
    @Published var aspectRatio = CGSize( width: 9, height: 16)

    public var width:CGFloat = UIScreen.main.bounds.width
    public var height:CGFloat = UIScreen.main.bounds.height
}
