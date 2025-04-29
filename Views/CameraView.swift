//
//  CameraView.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 07/03/2024.
//

import SwiftUI
import AVFoundation
import SUCo

struct CaptureVideoView: View {
    @ObservedObject var model: MainViewController 
    
    
    
    
    @ObservedObject var layout :MainViewLayout
    
        @State var filterID = 0
        var body: some View {
            
            ZStack{
                
                VStack {
                    //                "arrow.triangle.2.circlepath"
                    Spacer()
                    HStack{
                        Button(action: {
                            model.stopRunning()
                            SUCoordinator.moveToSUIView(from: .fromLeft, type: .moveIn, AnyView( ContentView() ) )
                        }, label: {
                            Image(systemName: "arrowshape.left.fill")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                        })
                        .padding(.horizontal, 15)
                        
                        Spacer()
                        
                        Image(systemName: "circle.fill")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.red)
                        //                        .tint(.red)
                            .frame(width: 25, height: 25)
                            .padding(.horizontal, 15)
                            .opacity(model.isRecording ? 1.0 : 0.0)
                        Spacer()
                        Button(action: {
                            model.switchCam()
                            
                        }, label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                        })
                        
                        
                        
                        
                    }
                    
                    ZStack{
                        
                        // ==== RECORDING BUTTON ====
                        Button {
                            print(" ==== POLO ====")
                            model.isRecording.toggle()
                            model.recording = model.isRecording
                            
                        } label: {
                            
                            
                            
                            MetalViewContainer(model: model)
                            
                                .overlay(GeometryReader { proxy in
                                    Color(.clear)
                                    
                                        .onAppear{
                                            model.setup(mode: .capture)
                                            switch model.frameFormat {
                                            case .photo:
                                                layout.aspectRatio = CGSize( width: 3, height: 4)
                                            case .hd:
                                                layout.aspectRatio = CGSize( width: 9, height: 16)
                                            case .square:
                                                layout.aspectRatio = CGSize( width: 1, height: 1)
                                            }
                                            layout.proxyFrame = proxy.frame(in: .global)
                                            layout.previewFrame = AVMakeRect(aspectRatio:layout.aspectRatio, insideRect: proxy.frame(in: .global)).size
                                            model.setFrame(layout.previewFrame)
                                            model.defaultUniforms.onCameraView = false
                                        }
                                    
                                })
                            
                        }
                        
                    }
                    ToolBarView(model:model)
                        .padding()
                 
//                    Spacer()
                    
                }
                //            .background(.black)
                
                .padding()
            }//.frame(width:UIScreen.main.bounds.width, height:UIScreen.main.bounds.height)
                .background(.black)
        }
    }

