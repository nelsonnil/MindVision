//
//  PickVideoView.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 10/03/2024.
//

import SwiftUI
import AVFoundation
import SUCo

struct VideoPlaybackView: View {
    
    @ObservedObject var model: MainViewController
    
    @ObservedObject var layout: MainViewLayout
    @State var url: URL
    @State var filterID = 0
    
    @State var pickedColor: Color = .white
    @State private var textContent: String = "text"
    @State private var textFontSize: Int = 25
    @State private var selectedFont: String = FontLoader.allFonts.first ?? ""
    @State private var textColor: Color = .white
    @State private var frameColor: Color = .red
    
    @State private var isLongPressActive = false
    @State private var showToolbar = true
    @State private var showPlayButton = false
    @State private var isFullscreen = false // Track fullscreen state
    
    // Inicializador personalizado para obtener los datos existentes
    init(model: MainViewController, layout: MainViewLayout, url: URL) {
        self._model = ObservedObject(wrappedValue: model)
        self._layout = ObservedObject(wrappedValue: layout)
        self._url = State(initialValue: url)
        
        // Obtener configuraciones actuales del modelo
        if let currentColor = model.layer.uilabel.textColor {
            self._textColor = State(initialValue: Color(uiColor: currentColor))
        }
        self._selectedFont = State(initialValue: model.layer.font)
        self._textContent = State(initialValue: model.layer.text)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(hex: "121212")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top navigation bar
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
                                        
                                        // Important: Set hasLoadedImage to false so ContentView doesn't 
                                        // think a new image has been selected
                                        UserDefaults.standard.set(false, forKey: "newImageSelected")
                                    }
                                }
                            }
                            
                            print("Back button: Preserving overlays for return to ContentView")
                            print("Overlay1: \(model.metal.overlayImage1 != nil ? "preserved" : "nil")")
                            print("Overlay2: \(model.metal.overlayImage2 != nil ? "preserved" : "nil")")
                        }
                        
                        // Set a flag in UserDefaults to indicate we're returning from preview
                        UserDefaults.standard.set(true, forKey: "isReturningFromPreview")
                        UserDefaults.standard.set(true, forKey: "hasLoadedImage")
                        UserDefaults.standard.set(true, forKey: "hasLoadedVideo")
                        
                        // Special flag to indicate we should preserve the existing overlay image
                        UserDefaults.standard.set(true, forKey: "preserveExistingOverlay")
                        
                        // Save font and text color
                        UserDefaults.standard.set(selectedFont, forKey: "lastSelectedFont")
                        
                        // Convert text color to hex string and save
                        let uiColor = UIColor(textColor)
                        var red: CGFloat = 0
                        var green: CGFloat = 0
                        var blue: CGFloat = 0
                        var alpha: CGFloat = 0
                        
                        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                        let hexString = String(
                            format: "#%02X%02X%02X",
                            Int(red * 255),
                            Int(green * 255),
                            Int(blue * 255)
                        )
                        UserDefaults.standard.set(hexString, forKey: "lastTextColor")
                        print("Saved text color: \(hexString)")
                        
                        SUCoordinator.moveToSUIView(from: .fromLeft, type: .moveIn, AnyView(ContentView()))
                    }, label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.3))
                        )
                    })
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Fullscreen expand/collapse button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isFullscreen.toggle()
                            
                            // Auto-hide toolbar when entering fullscreen, restore when exiting
                            if isFullscreen {
                                showToolbar = false
                            } else {
                                // When exiting fullscreen, restore toolbar visibility
                                showToolbar = true
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 60)
                .padding(.top, 8)
                .opacity(isFullscreen ? 0.5 : 1) // Dim the top bar in fullscreen mode
                .animation(.easeInOut(duration: 0.3), value: isFullscreen)
                .padding(.bottom, isFullscreen ? 0 : 10)
                
                // Main video player view - enlarged with better borders
                ZStack {
                    MetalViewContainer(model: model)
                        .clipShape(RoundedRectangle(cornerRadius: isFullscreen ? 0 : 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: isFullscreen ? 0 : 12)
                                .stroke(Color.blue.opacity(isFullscreen ? 0 : 0.6), lineWidth: isFullscreen ? 0 : 2)
                        )
                        .shadow(color: Color.black.opacity(isFullscreen ? 0 : 0.5), radius: isFullscreen ? 0 : 10, x: 0, y: isFullscreen ? 0 : 5)
                        .overlay(GeometryReader { proxy in
                            Color(.clear)
                                .onAppear {
                                    // First, save current overlay state
                                    let savedOverlay1 = model.metal.overlayImage1
                                    let savedOverlay2 = model.metal.overlayImage2
                                    
                                    model.sourceVideoUrl = url
                                    print("VideoPlaybackView - Setting up renderer with URL: \(url)")
                                    
                                    // Mostrar diagnóstico de los overlays antes de la configuración
                                    print("VideoPlaybackView - Before setup:")
                                    print("Overlay1: \(model.metal.overlayImage1 != nil ? "exists" : "missing")")
                                    print("Overlay2: \(model.metal.overlayImage2 != nil ? "exists" : "missing")")
                                    
                                    // Configurar el modo
                                    model.setup(mode: .preview)
                                    
                                    // Importante: restaurar los overlays si se perdieron durante setup
                                    DispatchQueue.main.async {
                                        if model.metal.overlayImage1 == nil && savedOverlay1 != nil {
                                            print("VideoPlaybackView - Restoring Overlay1")
                                            model.metal.overlayImage1 = savedOverlay1
                                        }
                                        
                                        if model.metal.overlayImage2 == nil && savedOverlay2 != nil {
                                            print("VideoPlaybackView - Restoring Overlay2")
                                            model.metal.overlayImage2 = savedOverlay2
                                        }
                                    }
                                    
                                    // Configurar el resto de parámetros
                                    layout.aspectRatio = model.sourceVideoFrame
                                    layout.proxyFrame = proxy.frame(in: .global)
                                    layout.previewFrame = AVMakeRect(aspectRatio: layout.aspectRatio, insideRect: proxy.frame(in: .global)).size
                                    model.setFrame(layout.proxyFrame.size)
                                    model.defaultUniforms.onCameraView = true
                                    
                                    // Verificar el estado final de los overlays
                                    print("VideoPlaybackView - After setup:")
                                    print("Overlay1: \(model.metal.overlayImage1 != nil ? "exists" : "missing")")
                                    print("Overlay2: \(model.metal.overlayImage2 != nil ? "exists" : "missing")")
                                }
                        })
                        .gesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    print(" ==== Long Press Detected! ====")
                                    isLongPressActive = true
                                    
                                    if model.avReader != nil && model.avReader!.isPlaying {
                                        model.avReader?.player?.pause()
                                    } else {
                                        model.avReader?.player?.play()
                                    }
                                    
                                    // Reset after a short delay to allow DragGesture to register later
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        isLongPressActive = false
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { gesture in
                                    if isLongPressActive {
                                        return // Ignore if long press was just triggered
                                    }

                                    let touchLocation = gesture.location
                                    let pixelColor = model.getPixelColor(at: touchLocation, in: layout.proxyFrame)
                                    
                                    pickedColor = Color(uiColor: pixelColor)
                                    
                                    print(" ==== Tapped at: \(touchLocation), Color: \(pixelColor)")
                                    
                                    // Toggle play/pause state on tap
                                    if model.avReader != nil {
                                        if model.avReader!.isPlaying {
                                            model.avReader?.player?.pause()
                                        } else {
                                            model.avReader?.player?.play()
                                        }
                                    }
                                    
                                    // Toggle toolbar visibility on tap
                                    withAnimation {
                                        // Only toggle toolbar if not in fullscreen mode
                                        if !isFullscreen {
                                            showToolbar.toggle()
                                        } else {
                                            // In fullscreen mode, just show/hide play button
                                            // and keep toolbar hidden
                                            showToolbar = false
                                        }
                                        
                                        // Show play button briefly when tapped
                                        showPlayButton = true
                                        
                                        // Auto-hide play button after 2 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                showPlayButton = false
                                            }
                                        }
                                    }
                                }
                        )
                        // Play/pause overlay button with improved visibility
                        .overlay(
                            Button(action: {
                                if model.avReader != nil {
                                    if model.avReader!.isPlaying {
                                        model.avReader?.player?.pause()
                                    } else {
                                        model.avReader?.player?.play()
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                        .frame(width: 60, height: 60)
                                    
                                    Circle()
                                        .fill(Color.blue.opacity(0.6))
                                        .frame(width: 54, height: 54)
                                    
                                    Image(systemName: model.avReader?.isPlaying ?? false ? "pause.fill" : "play.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .opacity(showPlayButton ? 1 : 0)
                        )
                }
                .padding(.horizontal, isFullscreen ? 0 : 16)
                .padding(.vertical, isFullscreen ? 0 : 12)
                .frame(maxHeight: isFullscreen ? .infinity : nil)
                .frame(minHeight: isFullscreen ? UIScreen.main.bounds.height - 70 : nil)
                
                // Tools section with better background and transitions
                ZStack {
                    if showToolbar && !isFullscreen {
                        VStack(spacing: 0) {
                            // Visual indicator for scrollability
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 40, height: 5)
                                .padding(.vertical, 5)
                            
                            ToolBarView(model: model, textColor: $textColor, selectedFont: $selectedFont, frameColor: $frameColor)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(hex: "1A1A1A"))
                                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: -2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showToolbar)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFullscreen)
            }
            .edgesIgnoringSafeArea(isFullscreen ? .all : [])
        }
        .onAppear {
            // Store current overlay images when view appears
            let currentOverlay1 = model.metal.overlayImage1
            let currentOverlay2 = model.metal.overlayImage2
            
            // No necesitamos volver a configurar aquí, ya que los overlays
            // deberían haberse mantenido desde la configuración en ContentView
            print("VideoPlaybackView appeared, overlay images should be preserved")
            print("Overlay1: \(model.metal.overlayImage1 != nil ? "exists" : "missing")")
            print("Overlay2: \(model.metal.overlayImage2 != nil ? "exists" : "missing")")
            
            // Ensure overlays are restored after model setup if they get cleared
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if model.metal.overlayImage1 == nil && currentOverlay1 != nil {
                    print("Restoring image overlay that was lost during setup")
                    model.metal.overlayImage1 = currentOverlay1
                }
                
                if model.metal.overlayImage2 == nil && currentOverlay2 != nil {
                    print("Restoring text overlay that was lost during setup")
                    model.metal.overlayImage2 = currentOverlay2
                }
            }
            
            // Briefly show play button when view appears
            withAnimation {
                showPlayButton = true
            }
            
            // Hide play button after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showPlayButton = false
                }
            }
        }
        .onChange(of: isFullscreen) { newValue in
            // Update frame when fullscreen status changes
            print("Fullscreen mode changed to: \(newValue)")
            
            // Auto-hide toolbar when entering fullscreen, restore when exiting
            if newValue {
                showToolbar = false
            } else {
                // When exiting fullscreen, restore toolbar visibility
                showToolbar = true
            }
            
            // Allow time for layout to update before adjusting frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Update the player frame for fullscreen mode
                if let frame = model.mtlView.superview?.bounds {
                    // Use the entire screen height in fullscreen mode minus the nav bar
                    let adjustedSize = newValue ? 
                        CGSize(width: UIScreen.main.bounds.width, 
                               height: UIScreen.main.bounds.height - (showToolbar ? 240 : 70)) : 
                        frame.size
                    
                    model.setFrame(adjustedSize)
                    print("Updated player frame for fullscreen: \(adjustedSize)")
                }
            }
        }
    }
}

