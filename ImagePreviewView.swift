import SwiftUI

struct ImagePreviewView: View {
    let image: UIImage
    let imageData: Data
    
    @Binding var showPuzzleView: Bool
    @Binding var showPreviewView: Bool
    
    @State private var countdown = 5
    @State private var timer: Timer? = nil
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Zapamiętaj zdjęcie!")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding()
                
                Text("\(countdown)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.yellow)
                    .shadow(radius: 5)
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startCountdown() {
        countdown = 5
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdown > 1 {
                countdown -= 1
            } else {
                t.invalidate()
                // przejście do PuzzleView
                showPreviewView = false
                showPuzzleView = true
            }
        }
    }
}
