import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct PuzzlePiece: Identifiable {
    let id: UUID
    let image: UIImage
    let correctRow: Int
    let correctCol: Int

    init(image: UIImage, correctRow: Int, correctCol: Int) {
        self.id = UUID()
        self.image = image
        self.correctRow = correctRow
        self.correctCol = correctCol
    }
}

struct PuzzleView: View {
    let imageData: Data

    @State private var pieces: [PuzzlePiece] = []
    @State private var placedPieces: [[PuzzlePiece?]] = []
    @State private var isCompleted = false
    @State private var isFailed = false
    @Binding var showPuzzleView: Bool

    private let rows = 3
    private let cols = 4

    // Dźwięki
    @State private var clickPlayer: AVAudioPlayer?
    @State private var successPlayer: AVAudioPlayer?
    @State private var failPlayer: AVAudioPlayer?

    // Podświetlenie błędnego ruchu
    @State private var invalidDropPosition: (Int, Int)? = nil

    var body: some View {
        ZStack {
            mainContent

            if isCompleted {
                completionOverlay
            } else if isFailed {
                failedOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            preparePieces()
            loadSounds()
        }
    }

    // MARK: - Widoki pomocnicze
    private var mainContent: some View {
        GeometryReader { geometry in
            let totalSpacing: CGFloat = CGFloat(cols - 1) * 8
            // left column fixed width 120 + divider 10 + padding 32
            let availableWidth = geometry.size.width - 120 - 10 - totalSpacing - 32
            let cellWidth = max(40, availableWidth / CGFloat(cols))

            HStack(spacing: 10) {
                leftColumn
                    .frame(width: 120)
                    .background(Color(UIColor.systemGroupedBackground))

                Divider()

                boardView(cellWidth: cellWidth)
            }
            .padding()
        }
    }

    private var leftColumn: some View {
        ScrollView {
            VStack {
                if pieces.isEmpty {
                    Text("Ładowanie puzzli...")
                        .foregroundColor(.gray)
                } else {
                    ForEach(pieces) { piece in
                        Image(uiImage: piece.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                            .shadow(radius: 3)
                            .padding(4)
                            .onDrag {
                                // Dostarczamy UUID jako zwykły tekst, prostsze dla typowania
                                return NSItemProvider(object: piece.id.uuidString as NSString)
                            }
                            .onTapGesture {
                                #if targetEnvironment(simulator)
                                placePieceAutomatically(piece)
                                #endif
                            }
                    }
                }
            }
        }
    }

    private func boardView(cellWidth: CGFloat) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<cols, id: \.self) { col in
                        boardCell(row: row, col: col, cellWidth: cellWidth)
                    }
                }
            }
        }
    }

    private func boardCell(row: Int, col: Int, cellWidth: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill((invalidDropPosition?.0 == row && invalidDropPosition?.1 == col) ? Color.red.opacity(0.4) : Color(UIColor.secondarySystemBackground))
                .frame(width: cellWidth, height: cellWidth)
                .cornerRadius(8)
                .shadow(radius: 2)

            if row < placedPieces.count,
               col < placedPieces[row].count,
               let piece = placedPieces[row][col] {
                Image(uiImage: piece.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: cellWidth, height: cellWidth)
                    .cornerRadius(8)
                    .onDrag {
                        return NSItemProvider(object: piece.id.uuidString as NSString)
                    }
            }
        }
        .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
            handleDrop(providers: providers, row: row, col: col)
        }
    }

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🎉 Brawo Pola! Ułożyłaś zdjęcie!")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)

                Button("Zamknij") {
                    isCompleted = false
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)

                Button("Wybierz nowe zdjęcie") {
                    isCompleted = false
                    showPuzzleView = false
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }

    private var failedOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("⚠️ Puzzle źle ułożone!")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)

                Button("Spróbuj jeszcze raz") {
                    resetPuzzle()
                    isFailed = false
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Logika i dźwięki
    private func preparePieces() {
        guard let uiImage = UIImage(data: imageData)?.cgImage else { return }
        let width = uiImage.width / cols
        let height = uiImage.height / rows

        var newPieces: [PuzzlePiece] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(x: col * width, y: row * height, width: width, height: height)
                if let piece = uiImage.cropping(to: rect) {
                    let img = UIImage(cgImage: piece)
                    newPieces.append(PuzzlePiece(image: img, correctRow: row, correctCol: col))
                }
            }
        }
        placedPieces = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        pieces = newPieces.shuffled()
    }

    private func loadSounds() {
        clickPlayer = createPlayer(for: "click", ext: "wav")
        successPlayer = createPlayer(for: "success", ext: "mp3")
        failPlayer = createPlayer(for: "fail", ext: "mp3")
    }

    private func createPlayer(for resource: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }

    private func handleDrop(providers: [NSItemProvider], row: Int, col: Int) -> Bool {
        // 🔒 uniemożliwiamy położenie na zajęte miejsce
        if placedPieces[row][col] != nil {
            failPlayer?.play()
            invalidDropPosition = (row, col)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                invalidDropPosition = nil
            }
            return false
        }

        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { nsstr, _ in
                    guard let s = nsstr as? String,
                          let uuid = UUID(uuidString: s) else { return }

                    DispatchQueue.main.async {
                        // Drop z lewej kolumny
                        if let droppedPiece = pieces.first(where: { $0.id == uuid }) {
                            placePiece(droppedPiece, at: row, col: col)
                            pieces.removeAll { $0.id == uuid }
                            return
                        }

                        // Przenoszenie z planszy
                        outerLoop: for r in 0..<rows {
                            for c in 0..<cols {
                                if placedPieces[r][c]?.id == uuid {
                                    let movedPiece = placedPieces[r][c]
                                    placedPieces[r][c] = nil

                                    // Sprawdź, czy docelowe pole wolne
                                    if placedPieces[row][col] == nil {
                                        placePiece(movedPiece!, at: row, col: col)
                                    } else {
                                        placedPieces[r][c] = movedPiece // cofamy ruch
                                        failPlayer?.play()
                                        invalidDropPosition = (row, col)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            invalidDropPosition = nil
                                        }
                                    }
                                    break outerLoop
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func placePiece(_ piece: PuzzlePiece?, at row: Int, col: Int) {
        guard let piece = piece else { return }
        placedPieces[row][col] = piece
        clickPlayer?.play()
        checkCompletion()
    }

    private func checkCompletion() {
        var allCorrect = true
        var anyEmpty = false

        for row in 0..<rows {
            for col in 0..<cols {
                if let piece = placedPieces[row][col] {
                    if piece.correctRow != row || piece.correctCol != col {
                        allCorrect = false
                    }
                } else {
                    allCorrect = false
                    anyEmpty = true
                }
            }
        }

        if allCorrect {
            isCompleted = true
            successPlayer?.play()
        } else if !anyEmpty && !allCorrect {
            isFailed = true
            failPlayer?.play()
        }
    }

    private func placePieceAutomatically(_ piece: PuzzlePiece) {
        for row in 0..<rows {
            for col in 0..<cols {
                if placedPieces[row][col] == nil {
                    placedPieces[row][col] = piece
                    pieces.removeAll { $0.id == piece.id }
                    checkCompletion()
                    return
                }
            }
        }
    }

    private func resetPuzzle() {
        pieces = placedPieces.flatMap { $0 }.compactMap { $0 }
        pieces.shuffle()/Users/lukaszbialik/Downloads/skladki_template/backend/init_db.py
        placedPieces = Array(repeating: Array(repeating: nil, count: cols), count: rows)
    }
}

