//
//  ContentView.swift
//  TrackPlay
//
//  Created by Demian Nezhdanov on 07/03/2024.
//

import SwiftUI
import SUCo
import PhotosUI
import AVFoundation

// Create a shared model instance that persists between view transitions
final class SharedModelProvider {
    static let shared = MainViewController()
}

struct ContentView: View {
    
    // Use the shared model instance instead of creating a new one
    @ObservedObject var model: MainViewController = SharedModelProvider.shared
    
    @State private var phItem: PhotosPickerItem?
    @State private var videoItem: URL?
    @State private var text:String = "text"
    @State private var number:String = ""
    @State private var selectedColor:Color = .white
    @State private var selectedFont:String = FontLoader.allFonts.first ?? ""
    
    @State private var showPhotoPicker:Bool = false
    @ObservedObject var layout = MainViewLayout()
    @State private var uiimage = UIImage(named: "empty")!
    @State private var hasLoadedImage: Bool = false
    @State private var hasLoadedVideo: Bool = false
    
    // Add this to keep track of whether we're returning from preview
    @State private var isReturningFromPreview: Bool = false
    
    var body: some View {
        NavigationStack{
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(hex: "121212")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Título de la app
                    Text("TrackPlay")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    
                    // Contenedor principal con fondo
                    VStack(spacing: 24) {
                        // Campo de texto
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Text Overlay")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("Enter text to display", text: $text)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .font(.system(size: 16))
                        }
                        .padding(.horizontal)
                        
                        // Botones de selección de media
                        VStack(spacing: 16) {
                            // Botón de imagen
                            PhotosPicker(selection: $phItem, matching: .images, preferredItemEncoding: .automatic) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                    
                                    Text(hasLoadedImage ? "Image Loaded" : "Add Image Overlay")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Image(systemName: hasLoadedImage ? "checkmark.circle.fill" : "chevron.right")
                                        .foregroundColor(hasLoadedImage ? .green : .white.opacity(0.6))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.3))
                                )
                            }
                            .padding(.horizontal)
                            
                            // Botón de video
                            Button {
                                showPhotoPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                    
                                    Text(hasLoadedVideo ? "Video Loaded" : "Select Video")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Image(systemName: hasLoadedVideo ? "checkmark.circle.fill" : "chevron.right")
                                        .foregroundColor(hasLoadedVideo ? .green : .white.opacity(0.6))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.3))
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        // Botones de acción
                        HStack(spacing: 16) {
                            // Botón Preview
                            Button(action: {
                                // Action for PREVIEW
                                print("PREVIEW tapped")
                                if let validVideoURL = videoItem {
                                    // Store the video URL in UserDefaults so we can restore it when returning
                                    UserDefaults.standard.set(validVideoURL.absoluteString, forKey: "lastVideoURL")
                                    
                                    // Only do full setup if overlays aren't already set up
                                    if model.metal.overlayImage1 == nil || model.metal.overlayImage2 == nil {
                                        // Asegurarse de que la configuración de la capa se actualiza primero
                                        // La imagen, texto, color y fuente deben estar configurados antes de navegar
                                        let asset = AVAsset(url: validVideoURL)
                                        var videoSize = CGSizeZero
                                        
                                        if let videoTrack = asset.tracks(withMediaType: .video).first {
                                            videoSize = videoTrack.naturalSize
                                            print("Preview - Video width: \(videoSize.width), height: \(videoSize.height)")
                                        } else {
                                            // Si no podemos obtener el tamaño del video, usar un tamaño predeterminado
                                            videoSize = CGSize(width: 1920, height: 1080)
                                        }
                                        
                                        // Verificar que la imagen no sea nil ni vacía
                                        print("Preview - Using image: \(uiimage)")
                                        print("Preview - Image size: \(uiimage.size.width) x \(uiimage.size.height)")
                                        
                                        // Verificar que tengamos texto y fuente válidos
                                        print("Preview - Text: \(text)")
                                        print("Preview - Font: \(selectedFont)")
                                        
                                        // Configurar la capa con la imagen, texto, color y fuente actuales
                                        let uicolor = UIColor(selectedColor)
                                        
                                        // Asegurarse de que la imagen tenga un tamaño razonable para evitar problemas de renderizado
                                        let imageToUse = hasLoadedImage ? uiimage : UIImage(named: "empty")!
                                        let resizedImage = imageToUse.resize(newWidth: min(1000, videoSize.width/2), 
                                                                            newHeight: min(1000, videoSize.height/2))
                                        
                                        // Realizar la configuración de capa
                                        model.layer.setup(image: resizedImage, 
                                                         text: text, 
                                                         color: uicolor, 
                                                         font: selectedFont, 
                                                         fontSize: Int(number) ?? 25, 
                                                         textFrameSize: videoSize)
                                        
                                        // Establecer las imágenes de overlay en el modelo
                                        model.metal.overlayImage1 = model.layer.overlayImage
                                        model.metal.overlayImage2 = model.layer.textImage
                                        
                                        print("PREVIEW - Setting overlay images before navigation")
                                        print("Overlay1: \(model.metal.overlayImage1 != nil ? "set" : "nil")")
                                        print("Overlay2: \(model.metal.overlayImage2 != nil ? "set" : "nil")")
                                        
                                        if model.metal.overlayImage1 == nil {
                                            print("⚠️ Warning: Overlay1 is nil")
                                        }
                                        if model.metal.overlayImage2 == nil {
                                            print("⚠️ Warning: Overlay2 is nil")
                                        }
                                    } else {
                                        print("PREVIEW - Reusing existing overlay settings")
                                        print("Overlay1: \(model.metal.overlayImage1 != nil ? "exists" : "missing")")
                                        print("Overlay2: \(model.metal.overlayImage2 != nil ? "exists" : "missing")")
                                        
                                        // Always use the latest image if it has been updated
                                        let asset = AVAsset(url: validVideoURL)
                                        var videoSize = CGSizeZero
                                        
                                        if let videoTrack = asset.tracks(withMediaType: .video).first {
                                            videoSize = videoTrack.naturalSize
                                        } else {
                                            videoSize = CGSize(width: 1920, height: 1080)
                                        }
                                        
                                        // Check if the preserve flag is set from previous preview session
                                        let shouldPreserveOverlay = UserDefaults.standard.bool(forKey: "preserveExistingOverlay")
                                        
                                        // Check if we need to restore the image overlay
                                        if model.metal.overlayImage1 == nil || shouldPreserveOverlay {
                                            // Try to load from saved path first
                                            if let imagePath = UserDefaults.standard.string(forKey: "lastOverlayImagePath"),
                                               let savedImage = UIImage(contentsOfFile: imagePath) {
                                                print("Restoring overlay from saved image at path: \(imagePath)")
                                                let resizedImage = savedImage.resize(
                                                    newWidth: min(1000, videoSize.width/2),
                                                    newHeight: min(1000, videoSize.height/2)
                                                )
                                                model.layer.overlayImage = resizedImage
                                                model.metal.overlayImage1 = resizedImage
                                                
                                                // Clear the preserve flag
                                                UserDefaults.standard.set(false, forKey: "preserveExistingOverlay")
                                            } else if hasLoadedImage {
                                                // Fallback to current uiimage if no saved path
                                                print("Image overlay missing, recreating from current image")
                                                let resizedImage = uiimage.resize(
                                                    newWidth: min(1000, videoSize.width/2),
                                                    newHeight: min(1000, videoSize.height/2)
                                                )
                                                model.layer.overlayImage = resizedImage
                                                model.metal.overlayImage1 = resizedImage
                                            }
                                        } else if hasLoadedImage {
                                            // Only update if user explicitly selected a new image
                                            let resizedImage = uiimage.resize(
                                                newWidth: min(1000, videoSize.width/2),
                                                newHeight: min(1000, videoSize.height/2)
                                            )
                                            model.layer.overlayImage = resizedImage
                                            model.metal.overlayImage1 = resizedImage
                                            print("Updated image overlay with latest selected image")
                                        }
                                        
                                        // Always update text and appearance settings
                                        let uicolor = UIColor(selectedColor)
                                        
                                        // Update text in model layer
                                        model.layer.text = text
                                        model.layer.uilabel.text = text
                                        
                                        // Update font in model layer
                                        model.layer.font = selectedFont
                                        model.layer.uilabel.font = UIFont(name: selectedFont, size: CGFloat(Int(number) ?? 25))
                                        
                                        // Update text color in model layer
                                        model.layer.uilabel.textColor = uicolor
                                        
                                        // Regenerate text image with updated settings
                                        let textImage = model.layer.imageTextView.createImage()
                                        model.layer.textImage = textImage
                                        model.metal.overlayImage2 = textImage
                                        
                                        print("Updated text settings: Font: \(selectedFont), Color: \(selectedColor)")
                                    }
                                    
                                    // Ahora navegamos con el modelo correctamente configurado
                                    SUCoordinator.moveToSUIView(from: .fromBottom, type: .fade, AnyView(VideoPlaybackView(model: model, layout: layout, url: validVideoURL)))
                                } else {
                                    print("Error: videoURL is nil")
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16))
                                    Text("PREVIEW")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(videoItem != nil ? Color.blue : Color.blue.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(videoItem == nil)

                            // Botón Record
                            Button(action: {
                                // Action for RECORD
                                print("RECORD tapped")
                                if let validVideoURL = videoItem {
                                    // Store the video URL in UserDefaults so we can restore it when returning
                                    UserDefaults.standard.set(validVideoURL.absoluteString, forKey: "lastVideoURL")
                                    
                                    // Set preserve flags - similar to what we do when exiting Preview
                                    UserDefaults.standard.set(true, forKey: "preserveExistingOverlay")
                                    UserDefaults.standard.set(true, forKey: "isReturningFromPreview") // Reuse same flag
                                    UserDefaults.standard.set(true, forKey: "hasLoadedImage")
                                    UserDefaults.standard.set(true, forKey: "hasLoadedVideo")
                                    
                                    // Save current font and text color
                                    UserDefaults.standard.set(selectedFont, forKey: "lastSelectedFont")
                                    
                                    // Save text color as hex
                                    let uiColor = UIColor(selectedColor)
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
                                    
                                    // Save overlay image to file system if it exists
                                    if let imageOverlay = model.metal.overlayImage1, 
                                       let imageData = imageOverlay.pngData() {
                                        let fileManager = FileManager.default
                                        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                                            let fileURL = documentsDirectory.appendingPathComponent("lastOverlayImage.png")
                                            try? imageData.write(to: fileURL)
                                            print("Saved overlay image for recording to: \(fileURL)")
                                            UserDefaults.standard.set(fileURL.path, forKey: "lastOverlayImagePath")
                                        }
                                    }
                                    
                                    // Navigate to recording view with the model that has overlays
                                    SUCoordinator.moveToSUIView(from: .fromBottom, type: .fade, AnyView(VideoRecordingView(model: model, layout: layout, url: validVideoURL)))
                                } else {
                                    print("Error: videoURL is nil")
                                }
                            }) {
                                HStack {
                                    Image(systemName: "record.circle")
                                        .font(.system(size: 16))
                                    Text("RECORD")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(videoItem != nil ? Color.red : Color.red.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(videoItem == nil)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .sheet(isPresented: $showPhotoPicker, content: {
                VideoPicker(video: $videoItem, isAppear:$showPhotoPicker)
            })
            .onAppear {
                // Check if we're returning from preview
                if UserDefaults.standard.bool(forKey: "isReturningFromPreview") {
                    // Reset the flag
                    UserDefaults.standard.set(false, forKey: "isReturningFromPreview")
                    
                    // Restore the loaded states
                    hasLoadedImage = UserDefaults.standard.bool(forKey: "hasLoadedImage")
                    hasLoadedVideo = UserDefaults.standard.bool(forKey: "hasLoadedVideo")
                    
                    // Restore the font if it exists
                    if let savedFont = UserDefaults.standard.string(forKey: "lastSelectedFont") {
                        selectedFont = savedFont
                        print("Restored font: \(savedFont)")
                    }
                    
                    // Restore the text color if it exists
                    if let hexColor = UserDefaults.standard.string(forKey: "lastTextColor") {
                        selectedColor = Color(hex: hexColor.replacingOccurrences(of: "#", with: ""))
                        print("Restored text color: \(hexColor)")
                    }
                    
                    // Restore the video URL if it exists
                    if let urlString = UserDefaults.standard.string(forKey: "lastVideoURL"),
                       let url = URL(string: urlString) {
                        videoItem = url
                        print("Restored video URL: \(url)")
                    }
                    
                    // Try primary overlay image path first
                    var restoredOverlayImage: UIImage? = nil
                    if let imagePath = UserDefaults.standard.string(forKey: "lastOverlayImagePath"),
                       let restoredImage = UIImage(contentsOfFile: imagePath) {
                        uiimage = restoredImage
                        restoredOverlayImage = restoredImage
                        print("Restored overlay image from: \(imagePath)")
                    }
                    
                    // If that failed, try backup path
                    if restoredOverlayImage == nil,
                       let backupPath = UserDefaults.standard.string(forKey: "lastOverlayImageBackupPath"),
                       let backupImage = UIImage(contentsOfFile: backupPath) {
                        uiimage = backupImage
                        restoredOverlayImage = backupImage
                        print("Restored overlay image from backup: \(backupPath)")
                    }
                    
                    // Apply the restored image to model to ensure it's not lost
                    if hasLoadedVideo && hasLoadedImage && 
                       (model.metal.overlayImage1 == nil || UserDefaults.standard.bool(forKey: "preserveExistingOverlay")),
                       let videoURL = videoItem,
                       let imageToApply = restoredOverlayImage {
                        // We have a video and image but the overlay is missing, restore it
                        print("Restoring overlay image directly to model")
                        
                        // Get video dimensions for proper resizing
                        var videoSize = CGSize(width: 1920, height: 1080)
                        let asset = AVAsset(url: videoURL)
                        if let videoTrack = asset.tracks(withMediaType: .video).first {
                            videoSize = videoTrack.naturalSize
                        }
                        
                        // Resize and apply the image
                        let resizedImage = imageToApply.resize(
                            newWidth: min(1000, videoSize.width/2),
                            newHeight: min(1000, videoSize.height/2)
                        )
                        model.layer.overlayImage = resizedImage
                        model.metal.overlayImage1 = resizedImage
                        
                        // Clear the preserve flag after applying
                        UserDefaults.standard.set(false, forKey: "preserveExistingOverlay")
                    }
                    
                    print("Returning from preview. Image loaded: \(hasLoadedImage), Video loaded: \(hasLoadedVideo)")
                }
            }
            .onChange(of: videoItem) { _ in
                if let videoURL = videoItem {
                    // Create an AVAsset from the video URL
                    let asset = AVAsset(url: videoURL)
                    
                    var videoSize = CGSizeZero
                    
                    // Get the first video track from the asset
                    if let videoTrack = asset.tracks(withMediaType: .video).first {
                        // Retrieve the natural size of the video
                        videoSize = videoTrack.naturalSize
                        
                        // Print the video width and height
                        print("Video width: \(videoSize.width), height: \(videoSize.height)")
                    } else {
                        print("No video track found in the asset.")
                    }

                    // Existing code to setup the layer and move to the VideoPlaybackView
                    let uicolor = UIColor(selectedColor)
                    model.layer.setup(image: uiimage, text: text, color: uicolor, font: selectedFont, fontSize: Int(number) ?? 25, textFrameSize: videoSize)
                    model.metal.overlayImage1 = model.layer.overlayImage
                    model.metal.overlayImage2 = model.layer.textImage
                    print(" ==== VIDEO SELECTED! - \(text)")
                    
                    // Actualizar el estado para mostrar que se ha cargado un video
                    hasLoadedVideo = true
                }
            }
            .onChange(of: phItem) { _ in
                // Load selected image from PhotosPicker
                Task {
                    if let imageData = try? await phItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: imageData) {
                        DispatchQueue.main.async {
                            uiimage = image
                            hasLoadedImage = true
                            
                            // If model overlays already exist, update the image overlay immediately
                            if model.metal.overlayImage1 != nil || model.metal.overlayImage2 != nil {
                                // Get current video dimensions if available
                                var videoSize = CGSize(width: 1920, height: 1080)
                                if let validVideoURL = videoItem,
                                   let asset = AVURLAsset(url: validVideoURL as URL).tracks(withMediaType: .video).first {
                                    videoSize = asset.naturalSize
                                }
                                
                                // Resize image to appropriate dimensions
                                let resizedImage = image.resize(
                                    newWidth: min(1000, videoSize.width/2),
                                    newHeight: min(1000, videoSize.height/2)
                                )
                                
                                // Update the model's overlay image
                                model.layer.overlayImage = resizedImage
                                model.metal.overlayImage1 = resizedImage
                                
                                print("Image overlay updated immediately with new selection")
                                
                                // Save the new image to restore it if needed
                                if let imageData = resizedImage.pngData() {
                                    let fileManager = FileManager.default
                                    if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                                        let fileURL = documentsDirectory.appendingPathComponent("lastOverlayImage.png")
                                        try? imageData.write(to: fileURL)
                                        print("Saved new overlay image to: \(fileURL)")
                                        
                                        // Store the path in UserDefaults
                                        UserDefaults.standard.set(fileURL.path, forKey: "lastOverlayImagePath")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .toolbar{
                ToolbarItem(placement: .keyboard, content: {
                    HStack{
                        Spacer()
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                    }
                })
            }
        }
    }
}

// Helper extension para crear colores a partir de valores hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIImage {
    func resize(newWidth:CGFloat = 1920,newHeight:CGFloat = 1920) -> UIImage {
        
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? self
    }
}




