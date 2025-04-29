import SwiftUI
import AVFoundation
import SUCo

struct VideoRecordingView: View {
    
    @ObservedObject var model: MainViewController
    @ObservedObject var layout: MainViewLayout
    @State var url: URL
    @State var filterID = 0
    @State var isLoading = false // State to manage the loading overlay
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        // Ensure we preserve all changes before going back to ContentView
                        let savedOverlay1 = model.metal.overlayImage1
                        let savedOverlay2 = model.metal.overlayImage2
                        
                        model.stopRunning()
                        
                        // Make sure we restore the overlays after stopRunning (which might clear them)
                        DispatchQueue.main.async {
                            model.metal.overlayImage1 = savedOverlay1
                            model.metal.overlayImage2 = savedOverlay2
                            
                            // Save the overlay image to Documents directory for restoration
                            if let imageOverlay = savedOverlay1 {
                                if let imageData = imageOverlay.pngData() {
                                    let fileManager = FileManager.default
                                    if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                                        let fileURL = documentsDirectory.appendingPathComponent("lastOverlayImage.png")
                                        try? imageData.write(to: fileURL)
                                        print("Saved overlay image to: \(fileURL)")
                                        
                                        // Store the path in UserDefaults
                                        UserDefaults.standard.set(fileURL.path, forKey: "lastOverlayImagePath")
                                    }
                                }
                            }
                            
                            print("Back button: Preserving overlays for return to ContentView")
                            print("Overlay1: \(model.metal.overlayImage1 != nil ? "preserved" : "nil")")
                            print("Overlay2: \(model.metal.overlayImage2 != nil ? "preserved" : "nil")")
                        }
                        
                        // Set a flag in UserDefaults to indicate we're returning to ContentView
                        UserDefaults.standard.set(true, forKey: "isReturningFromPreview")
                        UserDefaults.standard.set(true, forKey: "hasLoadedImage")
                        UserDefaults.standard.set(true, forKey: "hasLoadedVideo")
                        
                        // Special flag to indicate we should preserve the existing overlay image
                        UserDefaults.standard.set(true, forKey: "preserveExistingOverlay")
                        
                        SUCoordinator.moveToSUIView(from: .fromLeft, type: .moveIn, AnyView(ContentView()))
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
                        .frame(width: 25, height: 25)
                        .padding(.horizontal, 15)
                        .opacity(model.isRecording ? 1.0 : 0.0)
                }
                
                ZStack {
                    Button {
                        print(" ==== MARCO ====")
                        model.isRecording.toggle()
                        model.recording = model.isRecording
                    } label: {
                        MetalViewContainer(model: model)
                            .overlay(GeometryReader { proxy in
                                Color(.clear)
                                    .onAppear {
                                        // Save current overlays before setup
                                        let currentOverlay1 = model.metal.overlayImage1
                                        let currentOverlay2 = model.metal.overlayImage2
                                        
                                        model.sourceVideoUrl = url
                                        model.setup(mode: .recording)
                                        layout.aspectRatio = model.sourceVideoFrame
                                        layout.proxyFrame = proxy.frame(in: .global)
                                        layout.previewFrame = AVMakeRect(aspectRatio: layout.aspectRatio, insideRect: proxy.frame(in: .global)).size
                                        model.setFrame(layout.proxyFrame.size)
                                        model.defaultUniforms.onCameraView = true
                                        
                                        // Restore overlays that might be lost during setup
                                        DispatchQueue.main.async {
                                            if model.metal.overlayImage1 == nil && currentOverlay1 != nil {
                                                print("Restoring image overlay in VideoRecordingView")
                                                model.metal.overlayImage1 = currentOverlay1
                                            }
                                            
                                            if model.metal.overlayImage2 == nil && currentOverlay2 != nil {
                                                print("Restoring text overlay in VideoRecordingView")
                                                model.metal.overlayImage2 = currentOverlay2
                                            }
                                        }
                                        
                                        // ==== TRYING TO RECORD ON APPEAR (FOR RECORDING ONLY) ====
                                        model.isRecording.toggle()
                                        model.recording = model.isRecording
                                        
                                        isLoading = true
                                        if let videoLength = model.avReader?.asset.videoDuration(), videoLength > 0 {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + videoLength) {
                                                isLoading = false
                                                model.isRecording.toggle()
                                                model.recording = model.isRecording
                                                
                                                // Before going back, save overlay state
                                                let finalOverlay1 = model.metal.overlayImage1
                                                let finalOverlay2 = model.metal.overlayImage2
                                                
                                                model.stopRunning()
                                                
                                                // Ensure overlays are preserved when auto-returning to ContentView
                                                DispatchQueue.main.async {
                                                    model.metal.overlayImage1 = finalOverlay1
                                                    model.metal.overlayImage2 = finalOverlay2
                                                    
                                                    // Save to file system
                                                    if let imageOverlay = finalOverlay1, let imageData = imageOverlay.pngData() {
                                                        let fileManager = FileManager.default
                                                        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                                                            let fileURL = documentsDirectory.appendingPathComponent("lastOverlayImage.png")
                                                            try? imageData.write(to: fileURL)
                                                            UserDefaults.standard.set(fileURL.path, forKey: "lastOverlayImagePath")
                                                        }
                                                    }
                                                    
                                                    // Set flags for returning to ContentView
                                                    UserDefaults.standard.set(true, forKey: "isReturningFromPreview")
                                                    UserDefaults.standard.set(true, forKey: "hasLoadedImage")
                                                    UserDefaults.standard.set(true, forKey: "hasLoadedVideo")
                                                    UserDefaults.standard.set(true, forKey: "preserveExistingOverlay")
                                                }
                                                
                                                SUCoordinator.moveToSUIView(from: .fromLeft, type: .moveIn, AnyView(ContentView()))
                                            }
                                        } else {
                                            isLoading = false // Handle the case where videoDuration is nil or 0
                                            model.isRecording.toggle()
                                            model.recording = model.isRecording
                                        }
                                    }
                            })
                    }
                    .disabled(true)
                }
                .padding(.horizontal)
                
                ToolBarView(model: model)
                    .padding()
            }
            .padding()
            .background(.black)
            .overlay {
                if(isLoading){
                    Color.black.opacity(1.0)
                        .ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)

                        Text("RECORDING")
                            .foregroundColor(.white)
                            .font(.title)
                            .bold()
                    }
                }
            }

        }
    }
}

