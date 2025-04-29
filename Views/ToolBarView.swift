//
//  ToolBarView.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 22/04/2024.
//

import SwiftUI

struct ToolBarView: View {
    @State private var selectedSection: Int = 1
    @ObservedObject var model: MainViewController
    @Binding var textColor: Color
    @Binding var selectedFont: String
    
    // Storage for preserving overlays
    @State private var lastKnownImageOverlay: UIImage? = nil
    @State private var lastKnownTextOverlay: UIImage? = nil
    
    @Binding var frameColor: Color
    
    @AppStorage("frameWidth") private var frameWidth: Double = 10.0
    @AppStorage("blurSize") private var blurSize: Double = 21.0
    
    // Constructor sin bindings para compatibilidad con código existente
    init(model: MainViewController) {
        self.model = model
        self._textColor = .constant(.white)
        self._selectedFont = .constant(FontLoader.allFonts.first ?? "")
        self._frameColor = .constant(.red)
    }
    
    // Constructor con bindings
    init(model: MainViewController, textColor: Binding<Color>, selectedFont: Binding<String>, frameColor: Binding<Color>) {
        self.model = model
        self._textColor = textColor
        self._selectedFont = selectedFont
        self._frameColor = frameColor
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(["Image", "Text", "Img Mask"].indices, id: \.self) { index in
                    let title = ["Image", "Text", "Img Mask"][index]
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // Save current overlays before switching tabs
                            if model.metal.overlayImage1 != nil {
                                lastKnownImageOverlay = model.metal.overlayImage1
                            }
                            
                            if model.metal.overlayImage2 != nil {
                                lastKnownTextOverlay = model.metal.overlayImage2
                            }
                            
                            print("Tab switching: Saved current overlays")
                            
                            // Switch tab
                            self.selectedSection = index 
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 14, weight: selectedSection == index ? .semibold : .regular))
                                .foregroundColor(selectedSection == index ? .white : Color(UIColor.systemGray5))
                            
                            // Indicator
                            Rectangle()
                                .fill(selectedSection == index ? Color.blue : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Content for each section with ScrollView
            TabView(selection: $selectedSection) {
                ScrollView {
                    ColorSectionView(model: model)
                        .padding(.bottom, 20)
                        .onAppear {
                            // Ensure overlays are preserved when switching to Image tab
                            print("Image section appeared")
                            ensureOverlaysPreserved()
                        }
                }.tag(0)
                
                ScrollView {
                    ModifiedPositionSectionView(model: model, textColor: $textColor, selectedFont: $selectedFont)
                        .padding(.bottom, 20)
                        .onAppear {
                            // Ensure overlays are preserved when switching to Text tab
                            print("Text section appeared")
                            ensureOverlaysPreserved()
                        }
                }.tag(1)
                
                ScrollView {
                    AdjustmentsSectionView(model: model, frameColor: $frameColor)
                        .padding(.bottom, 20)
                        .onAppear {
                            // Ensure overlays are preserved when switching to Img Mask tab
                            print("Img Mask section appeared")
                            ensureOverlaysPreserved() 
                        }
                }.tag(2)
            }
            .onChange(of: selectedSection) { _ in
                // Immediately restore overlays after tab change
                DispatchQueue.main.async {
                    if let imageOverlay = lastKnownImageOverlay {
                        print("Global tab change: Forcing image overlay restoration")
                        model.metal.overlayImage1 = imageOverlay
                    }
                    if let textOverlay = lastKnownTextOverlay {
                        print("Global tab change: Forcing text overlay restoration")
                        model.metal.overlayImage2 = textOverlay
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 240)
        }
        .onAppear {
            // Initialize our overlay cache when the toolbar appears
            if model.metal.overlayImage1 != nil {
                lastKnownImageOverlay = model.metal.overlayImage1
                print("ToolBarView appeared: Cached image overlay")
            }
            
            if model.metal.overlayImage2 != nil {
                lastKnownTextOverlay = model.metal.overlayImage2
                print("ToolBarView appeared: Cached text overlay")
            }
        }
    }
    
    // Method to ensure overlays are preserved
    private func ensureOverlaysPreserved() {
        // Store current overlays if they exist
        if model.metal.overlayImage1 != nil {
            lastKnownImageOverlay = model.metal.overlayImage1
            print("Cached image overlay in ToolBarView")
        }
        
        if model.metal.overlayImage2 != nil {
            lastKnownTextOverlay = model.metal.overlayImage2
            print("Cached text overlay in ToolBarView")
        }
        
        // Restore any missing overlays after a small delay to allow UI updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if model.metal.overlayImage1 == nil && lastKnownImageOverlay != nil {
                print("Restoring missing image overlay in ToolBarView")
                model.metal.overlayImage1 = lastKnownImageOverlay
            }
            
            if model.metal.overlayImage2 == nil && lastKnownTextOverlay != nil {
                print("Restoring missing text overlay in ToolBarView")
                model.metal.overlayImage2 = lastKnownTextOverlay
            }
        }
    }
}

struct ColorSectionView: View {
    @ObservedObject var model: MainViewController
    
    @AppStorage("saturation") private var saturation: Double = 0.5
    @AppStorage("focus") private var focus: Double = 0.5
    @AppStorage("brightness") private var brightness: Double = 0.0
    
    // Store current overlay images
    @State private var savedOverlay1: UIImage? = nil
    @State private var savedOverlay2: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Image Calibration")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            // Custom saturation slider with labels
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Saturation")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(saturation == 0 ? "No saturation" : 
                         saturation < 0.25 ? "Low saturation" : 
                         saturation < 0.75 ? "Medium saturation" : "High saturation")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.blue)
                }
                
                Slider(
                    value: Binding(
                        get: { Float(saturation) },
                        set: { saturation = Double($0) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .accentColor(Color.blue)
                .onChange(of: saturation) { _ in 
                    preserveOverlays {
                        model.uniforms.saturation = Float(saturation)
                    }
                }
                
                // Min/Max labels
                HStack {
                    Text("No saturation")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Maximum saturation")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Custom blur slider with labels
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Overlay blur")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(focus == 0 ? "No blur" : 
                         focus < 0.25 ? "Light blur" : 
                         focus < 0.75 ? "Medium blur" : "Heavy blur")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.blue)
                }
                
                Slider(
                    value: Binding(
                        get: { Float(focus) },
                        set: { focus = Double($0) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .accentColor(Color.blue)
                .onChange(of: focus) { _ in 
                    preserveOverlays {
                        model.uniforms.focus = Float(focus)
                        print("Blur value set to: \(focus)")
                    }
                }
                
                // Min/Max labels
                HStack {
                    Text("No blur")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Maximum blur")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Custom brightness slider with labels
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Brightness")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(brightness < -0.75 ? "Very dark" :
                         brightness < -0.25 ? "Dark" :
                         brightness < 0.25 ? "Normal brightness" :
                         brightness < 0.75 ? "Bright" : "Very bright")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.blue)
                }
                
                Slider(
                    value: Binding(
                        get: { Float(brightness) },
                        set: { brightness = Double($0) }
                    ),
                    in: -1...1,
                    step: 0.01
                )
                .accentColor(Color.blue)
                .onChange(of: brightness) { _ in 
                    preserveOverlays {
                        model.uniforms.brightness = Float(brightness)
                    }
                }
                
                // Min/Max labels
                HStack {
                    Text("Darker")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Brighter")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .onAppear {
            // Save current overlays when view appears
            savedOverlay1 = model.metal.overlayImage1
            savedOverlay2 = model.metal.overlayImage2
        }
    }
    
    // Helper to preserve overlays during adjustment operations
    private func preserveOverlays(operation: () -> Void) {
        // Save current overlay state
        savedOverlay1 = model.metal.overlayImage1
        savedOverlay2 = model.metal.overlayImage2
        
        // Perform the operation
        operation()
        
        // Force overlay restoration
        DispatchQueue.main.async {
            if savedOverlay1 != nil {
                model.metal.overlayImage1 = savedOverlay1
            }
            if savedOverlay2 != nil {
                model.metal.overlayImage2 = savedOverlay2
            }
        }
    }
}

struct ModifiedPositionSectionView: View {
    @ObservedObject var model: MainViewController
    
    @AppStorage("siz") private var siz: Double = 100
    @AppStorage("rot") private var rot: Double = 0
    @AppStorage("text_displacementX") private var tdX: Double = 0
    @AppStorage("text_displacementY") private var tdY: Double = 0
    @AppStorage("text_blur") private var textBlur: Double = 0
    @AppStorage("text_opacity") private var textOpacity: Double = 1.0 // Default to fully opaque
    
    // Propiedades para fuente y color a través de bindings
    @Binding var textColor: Color
    @Binding var selectedFont: String
    @State private var showFontPicker: Bool = false
    
    // Constructor con bindings
    init(model: MainViewController, textColor: Binding<Color>, selectedFont: Binding<String>) {
        self.model = model
        self._textColor = textColor
        self._selectedFont = selectedFont
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Text Settings")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            // Selector de color
            HStack {
                Text("Text Color")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                ColorPicker("", selection: $textColor)
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .onChange(of: textColor) { newColor in
                        // Save the current image overlay
                        let savedImageOverlay = model.metal.overlayImage1
                        
                        // Aplicar el nuevo color al texto
                        let uiColor = UIColor(textColor)
                        model.layer.uilabel.textColor = uiColor
                        
                        // Generate a new text image with the updated color
                        let textImage = model.layer.imageTextView.createImage()
                        model.layer.textImage = textImage
                        model.metal.overlayImage2 = textImage
                        
                        // Restore the image overlay
                        if savedImageOverlay != nil {
                            model.metal.overlayImage1 = savedImageOverlay
                        }
                    }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Selector de fuente (nuevo diseño con picker completo)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Font")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            showFontPicker.toggle()
                        }
                    }) {
                        HStack {
                            Text(selectedFont.components(separatedBy: "-").last ?? selectedFont)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.blue.opacity(0.3))
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Picker de fuentes completo (se muestra como sheet cuando showFontPicker es true)
            .sheet(isPresented: $showFontPicker) {
                EnhancedFontPickerView(selectedFont: $selectedFont, textColor: textColor, model: model)
            }
            
            // Sliders existentes
            sliderView(title: "X Offset", value: $tdX, range: -2.0...2.0, step: 0.1) {
                model.setTextDisplacementX(Float(tdX))
            }
            
            sliderView(title: "Y Offset", value: $tdY, range: -2.0...2.0, step: 0.1) {
                model.setTextDisplacementY(Float(tdY))
            }
            
            sliderView(title: "Size", value: Binding(get: { Float(siz) }, set: { siz = Double($0) }), range: 50...500) {
                updateSize()
            }
            
            sliderView(title: "Rotation", value: Binding(get: { Float(rot) }, set: { rot = Double($0) }), range: 0...7) {
                updateRotation()
            }
            
            // Custom text blur slider with labels
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Text Blur")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(textBlur == 0 ? "No blur" : 
                         textBlur < 0.25 ? "Light blur" : 
                         textBlur < 0.75 ? "Medium blur" : "Heavy blur")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.blue)
                }
                
                Slider(
                    value: $textBlur,
                    in: 0...1,
                    step: 0.01
                )
                .accentColor(Color.blue)
                .onChange(of: textBlur) { _ in 
                    updateTextBlur()
                }
                
                // Min/Max labels
                HStack {
                    Text("No blur")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Maximum blur")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Custom text opacity slider with labels
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Text Opacity")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(textOpacity == 0 ? "Transparent" : 
                         textOpacity < 0.3 ? "Very transparent" : 
                         textOpacity < 0.7 ? "Semi-transparent" : 
                         textOpacity < 1.0 ? "Nearly opaque" : "Fully opaque")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.blue)
                }
                
                Slider(
                    value: $textOpacity,
                    in: 0...1,
                    step: 0.01
                )
                .accentColor(Color.blue)
                .onChange(of: textOpacity) { _ in 
                    updateTextOpacity()
                }
                
                // Min/Max labels
                HStack {
                    Text("Transparent")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Fully opaque")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private func updateSize() {
        // Store the existing image overlay before update
        let savedImageOverlay = model.metal.overlayImage1
        
        // Update directly with our custom approach instead of using model.layer.update
        model.layer.uilabel.font = UIFont(name: model.layer.font, size: CGFloat(siz))
        let textImage = model.layer.imageTextView.createImage()
        model.layer.textImage = textImage
        
        // Set both overlays back to the renderer
        if savedImageOverlay != nil {
            model.metal.overlayImage1 = savedImageOverlay
        }
        model.metal.overlayImage2 = textImage
        
        print("Size changed: Overlay1 \(model.metal.overlayImage1 != nil ? "exists" : "missing")")
    }
    
    private func updateRotation() {
        // Store the existing image overlay before update
        let savedImageOverlay = model.metal.overlayImage1
        
        // Update directly with our custom approach
        model.layer.uilabel.transform = CGAffineTransform(rotationAngle: CGFloat(rot))
        let textImage = model.layer.imageTextView.createImage()
        model.layer.textImage = textImage
        
        // Set both overlays back to the renderer
        if savedImageOverlay != nil {
            model.metal.overlayImage1 = savedImageOverlay
        }
        model.metal.overlayImage2 = textImage
        
        print("Rotation changed: Overlay1 \(model.metal.overlayImage1 != nil ? "exists" : "missing")")
    }
    
    private func updateTextBlur() {
        // Store the existing image overlay before update
        let savedImageOverlay = model.metal.overlayImage1
        let savedTextOverlay = model.metal.overlayImage2
        
        // Apply the text blur
        model.setTextBlur(Float(textBlur))
        
        // Double-check overlay preservation
        if textBlur == 0 && savedTextOverlay != nil {
            // If blur is set to 0, restore the original text overlay
            model.metal.overlayImage2 = savedTextOverlay
        }
        
        // Always ensure the image overlay is preserved
        if savedImageOverlay != nil {
            model.metal.overlayImage1 = savedImageOverlay
        }
        
        print("Text blur updated: \(textBlur)")
    }
    
    private func updateTextOpacity() {
        // Store the existing image overlay before update
        let savedImageOverlay = model.metal.overlayImage1
        let savedTextOverlay = model.metal.overlayImage2
        
        // Apply the text opacity
        model.setTextOpacity(Float(textOpacity))
        
        // Double-check overlay preservation
        if textOpacity == 0 && savedTextOverlay != nil {
            // If opacity is set to 0, restore the original text overlay
            model.metal.overlayImage2 = savedTextOverlay
        }
        
        // Always ensure the image overlay is preserved
        if savedImageOverlay != nil {
            model.metal.overlayImage1 = savedImageOverlay
        }
        
        print("Text opacity updated: \(textOpacity)")
    }
}

struct AdjustmentsSectionView: View {
    @ObservedObject var model: MainViewController
    
    @AppStorage("size") private var size: Double = 0
    @AppStorage("sizeY") private var sizeY: Double = 0
    @AppStorage("imageRotation") private var imageRotation: Double = 0
    @AppStorage("frameWidth") private var frameWidth: Double = 0
    
    @AppStorage("displacementX") private var displacementX: Double = 0
    @AppStorage("displacementY") private var displacementY: Double = 0
    
    @Binding var frameColor: Color
    
    @AppStorage("blurSize") private var blurSize: Double = 21.0
    
    // Store current overlay images
    @State private var savedOverlay1: UIImage? = nil
    @State private var savedOverlay2: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Image Mask")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            // Color Selector
            HStack {
                Text("Frame Color")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                ColorPicker("", selection: $frameColor)
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .onChange(of: frameColor) { newColor in
                        // Set new frame color
                        let uiColor = UIColor(frameColor)
                        preserveOverlays {
                            model.setFrameColor(uiColor)
                        }
                    }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            sliderView(title: "Frame Width", value: $frameWidth, range: 0...50) {
                preserveOverlays {
                    model.setFrameWidth(Float(frameWidth))
                }
            }
            
            sliderView(title: "Frame Blur", value: $blurSize, range: 1...51, step: 2.0) {
                preserveOverlays {
                    print("Cambiando blur a: \(blurSize)")
                    model.setBlurSize(Float(blurSize))
                }
            }
            
            // Custom implementation for more responsive Height slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Height")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(String(format: "%.3f", size))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.blue)
                }
                
                Slider(
                    value: $size,
                    in: 0...4.0,
                    step: 0.01
                )
                .accentColor(Color.blue)
                .onChange(of: size) { newValue in
                    print("Height changing to: \(newValue)")
                    preserveOverlays {
                        model.setSize(Float(newValue))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Custom implementation for more responsive Width slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Width")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(String(format: "%.3f", sizeY))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.blue)
                }
                
                Slider(
                    value: $sizeY,
                    in: 0...4.0,
                    step: 0.01
                )
                .accentColor(Color.blue)
                .onChange(of: sizeY) { newValue in
                    print("Width changing to: \(newValue)")
                    preserveOverlays {
                        model.setSizeY(Float(newValue))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            sliderView(title: "Rotation", value: $imageRotation, range: 0...3) {
                preserveOverlays {
                    model.setRotation(Float(imageRotation))
                }
            }
            
            // X and Y Offset sliders are hidden
            // They're still managed in the background, but not shown in the UI
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .onAppear {
            // Save current overlays when view appears
            savedOverlay1 = model.metal.overlayImage1
            savedOverlay2 = model.metal.overlayImage2
        }
    }
    
    // Helper to preserve overlays during adjustment operations
    private func preserveOverlays(operation: () -> Void) {
        // Save current overlay state
        savedOverlay1 = model.metal.overlayImage1
        savedOverlay2 = model.metal.overlayImage2
        
        // Perform the operation
        operation()
        
        // Restore overlays
        if savedOverlay1 != nil {
            model.metal.overlayImage1 = savedOverlay1
        }
        if savedOverlay2 != nil {
            model.metal.overlayImage2 = savedOverlay2
        }
    }
}

struct ColorMaskSectionView: View {
    @ObservedObject var model: MainViewController
    
    @AppStorage("red") private var red: Double = 0
    @AppStorage("green") private var green: Double = 0
    @AppStorage("blue") private var blue: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Mask Thresholds")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            sliderView(title: "Red", value: $red, range: 0...255) {
                model.setRed(Float(red))
            }
            
            sliderView(title: "Green", value: $green, range: 0...255) {
                model.setGreen(Float(green))
            }
            
            sliderView(title: "Blue", value: $blue, range: 0...255) {
                model.setBlue(Float(blue))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// Reusable slider component
struct sliderView<T: BinaryFloatingPoint>: View where T.Stride: BinaryFloatingPoint {
    let title: String
    @Binding var value: T
    let range: ClosedRange<T>
    let step: T.Stride?
    let onChange: () -> Void
    
    init(title: String, value: Binding<T>, range: ClosedRange<T>, step: T.Stride? = nil, onChange: @escaping () -> Void = {}) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.onChange = onChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.1f", Double(value)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.blue)
            }
            
            Slider(
                value: $value,
                in: range,
                step: step ?? 0.01
            )
            .accentColor(Color.blue)
            .onAppear { onChange() }
            .onChange(of: value) { _ in onChange() }
        }
    }
}

// Enhanced Font Picker
struct EnhancedFontPickerView: View {
    @Binding var selectedFont: String
    @State private var searchText = ""
    @State private var selectedCategory: FontCategory = .all
    let textColor: Color
    let model: MainViewController
    @Environment(\.presentationMode) var presentationMode
    
    // Sample text for preview
    @State private var previewText = "Aa Bb Cc 123"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Preview area
                    VStack(spacing: 8) {
                        Text("Font Preview")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text(previewText)
                            .font(Font.custom(selectedFont, size: 32))
                            .foregroundColor(textColor)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        
                        HStack {
                            Text("Preview text:")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            
                            TextField("Enter preview text", text: $previewText)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    
                    // Category picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FontCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search fonts", text: $searchText)
                            .foregroundColor(.white)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Font list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredFonts, id: \.self) { fontName in
                                FontRowView(
                                    fontName: fontName,
                                    isSelected: selectedFont == fontName,
                                    onSelect: {
                                        // Get the current overlays for preservation
                                        let currentImageOverlay = model.metal.overlayImage1
                                        
                                        // Get current font size from user settings
                                        let currentFontSize = UserDefaults.standard.double(forKey: "siz")
                                        
                                        // Apply the new font
                                        selectedFont = fontName
                                        model.layer.font = fontName
                                        
                                        // Update text overlay with new font, maintaining user-selected size
                                        model.layer.uilabel.font = UIFont(name: fontName, size: CGFloat(currentFontSize))
                                        let newTextImage = model.layer.imageTextView.createImage()
                                        model.layer.textImage = newTextImage
                                        
                                        // Set both overlays back to renderer
                                        if currentImageOverlay != nil {
                                            model.metal.overlayImage1 = currentImageOverlay
                                        }
                                        model.metal.overlayImage2 = newTextImage
                                        
                                        print("Font changed: Overlay image \(model.metal.overlayImage1 != nil ? "preserved" : "missing")")
                                    }
                                )
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(
                                    selectedFont == fontName 
                                    ? Color.blue.opacity(0.2) 
                                    : Color.clear
                                )
                            }
                        }
                    }
                    .background(Color.black)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Font Selection")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
    
    // Filter fonts based on search and category
    private var filteredFonts: [String] {
        let fonts = FontFamilyProvider.getAllFonts(category: selectedCategory)
        
        if searchText.isEmpty {
            return fonts
        } else {
            return fonts.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

// Font row view
struct FontRowView: View {
    let fontName: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(fontDisplayName)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Text(fontName)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Sample text in the font
                Text("AaBbCc")
                    .font(Font.custom(fontName, size: 16))
                    .foregroundColor(.white)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .padding(.leading, 8)
                }
            }
        }
    }
    
    // Display just the font name without the family prefix
    private var fontDisplayName: String {
        let components = fontName.components(separatedBy: "-")
        if components.count > 1 {
            return components[1]
        } else {
            return fontName.components(separatedBy: ".").first ?? fontName
        }
    }
}

// Font categories
enum FontCategory: String, CaseIterable {
    case all = "All"
    case system = "System"
    case serif = "Serif"
    case sansSerif = "Sans Serif"
    case monospaced = "Monospaced"
    case display = "Display"
    case custom = "Custom"
}

// Provider for all system fonts
class FontFamilyProvider {
    static func getAllFonts(category: FontCategory = .all) -> [String] {
        var fonts: [String]
        
        // Get all font names from the system
        let fontFamilies = UIFont.familyNames.sorted()
        
        // Start with the existing fonts from FontLoader
        fonts = FontLoader.allFonts
        
        // Add all system fonts
        for family in fontFamilies {
            let fontNames = UIFont.fontNames(forFamilyName: family)
            fonts.append(contentsOf: fontNames)
        }
        
        // Remove duplicates
        fonts = Array(Set(fonts)).sorted()
        
        // Filter by category if needed
        switch category {
        case .all:
            return fonts
        case .system:
            return fonts.filter { $0.hasPrefix(".") || $0.lowercased().contains("system") }
        case .serif:
            return fonts.filter { 
                $0.lowercased().contains("serif") && !$0.lowercased().contains("sans") 
                || $0.lowercased().contains("times") 
                || $0.lowercased().contains("georgia")
            }
        case .sansSerif:
            return fonts.filter { $0.lowercased().contains("sans") || $0.lowercased().contains("helvetica") || $0.lowercased().contains("arial") }
        case .monospaced:
            return fonts.filter { $0.lowercased().contains("mono") || $0.lowercased().contains("courier") || $0.lowercased().contains("menlo") }
        case .display:
            return fonts.filter { $0.lowercased().contains("display") || $0.lowercased().contains("rounded") || $0.lowercased().contains("decorative") }
        case .custom:
            // Custom fonts are typically not part of system fonts
            return fonts.filter { !UIFont.familyNames.contains($0.components(separatedBy: "-").first ?? "") }
        }
    }
}

//#Preview {
//    ToolBarView()
//}
