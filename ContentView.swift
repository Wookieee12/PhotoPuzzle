import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var showPreviewView = false
    @State private var showPuzzleView = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Photo Puzzle")
                    .font(.largeTitle)
                    .bold()
                
                if let selectedImageData,
                   let uiImage = UIImage(data: selectedImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    Text("Brak wybranego zdjęcia")
                        .foregroundColor(.gray)
                }
                
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text("📸 Wybierz zdjęcie z galerii")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            showPreviewView = true
                        }
                    }
                }
            }
            .padding()
            // Nawigacja do ekranu podglądu z odliczaniem
            .navigationDestination(isPresented: $showPreviewView) {
                if let imageData = selectedImageData,
                   let uiImage = UIImage(data: imageData) {
                    ImagePreviewView(image: uiImage,
                                     imageData: imageData,
                                     showPuzzleView: $showPuzzleView,
                                     showPreviewView: $showPreviewView
                                     )
                }
            }
            // Nawigacja do PuzzleView
            .navigationDestination(isPresented: $showPuzzleView) {
                if let imageData = selectedImageData {
                    PuzzleView(imageData: imageData, showPuzzleView: $showPuzzleView)
                }
            }
        }
    }
}
