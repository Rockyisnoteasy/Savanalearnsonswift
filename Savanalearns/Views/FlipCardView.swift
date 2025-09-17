// Views/FlipCardView.swift
import SwiftUI
import AVFoundation

struct FlipCardView: View {
    let wordList: [String]
    let isNewWordSession: Bool
    let plan: Plan?
    let onSessionComplete: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var dictionaryViewModel: DictionaryViewModel
    
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var currentSentenceInfo: (String, Int?)? = nil
    @State private var displayWords: [String] = []
    @State private var showCircleAnimation = false
    @State private var isSessionInitialized = false
    
    var body: some View {
        VStack {
            
            if displayWords.isEmpty {
                if isSessionInitialized {
                    // Session is over because all words have been reviewed.
                    Text("翻牌记忆完成！")
                        .foregroundColor(.white)
                        .onAppear {
                            print("DEBUG: All words processed, completing session.")
                            onSessionComplete()
                        }
                } else {
                    // Show a loading indicator before the session starts.
                    ProgressView()
                }
            } else if currentIndex < displayWords.count {
                let word = displayWords[currentIndex]
                
                // DEBUG: Print current state
                let _ = print("DEBUG: Showing word '\(word)' (\(currentIndex + 1)/\(displayWords.count))")
                
                // Progress indicator
                HStack {
                    Text("\(currentIndex + 1)/\(displayWords.count)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("熟悉度：○")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Flip card with proper sizing
                ZStack {
                    // Front of the card
                    FrontCardView(
                        word: word,
                        sentence: currentSentenceInfo?.0,
                        sentenceIndex: currentSentenceInfo?.1
                    )
                    .opacity(isFlipped ? 0 : 1) // Hides the front when flipped

                    // Back of the card, pre-rotated
                    BackCardView(
                        fullDefinition: dictionaryViewModel.getDefinition(for: word) ?? "无释义",
                        shortDefinition: dictionaryViewModel.getSimplifiedDefinition(for: word)
                    )
                    .rotation3DEffect(.degrees(180), axis: (x: 0.0, y: 1.0, z: 0.0))
                    .opacity(isFlipped ? 1 : 0) // Shows the back when flipped
                }
                .frame(maxWidth: .infinity)
                .frame(height: 600)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0.0, y: 1.0, z: 0.0))
                .onTapGesture {
                    withAnimation(.spring()) {
                        isFlipped.toggle()
                    }
                }
                
                .onLongPressGesture(minimumDuration: 0.5) {
                    // Mark word as familiar
                    print("DEBUG: Marking '\(word)' as familiar")
                    authViewModel.markWordAsFamiliar(word)
                    showCircleAnimation = true
                    
                    // Remove word from display list
                    displayWords.remove(at: currentIndex)
                    
                    // Adjust index if needed
                    if currentIndex >= displayWords.count && currentIndex > 0 {
                        currentIndex = displayWords.count - 1
                    }
                    
                    // Hide animation after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCircleAnimation = false
                    }
                }
                
                Spacer()
                
                // Bottom control buttons
                HStack(spacing: 40) {
                    IconTextButton(iconName: "speaker.wave.2.fill", label: "朗读") {
                        Task {
                            await playWordAndSentence(for: word, sentence: currentSentenceInfo?.0)
                        }
                    }
                    
                    IconTextButton(iconName: "arrow.triangle.2.circlepath", label: "翻面") {
                        withAnimation(.spring()) {
                            isFlipped.toggle()
                        }
                    }
                    
                    IconTextButton(iconName: "arrow.right", label: "继续") {
                        goToNextWord()
                    }
                }
                .padding(.bottom)
            } else {
                Text("Index out of bounds")
                    .onAppear {
                        print("DEBUG: currentIndex (\(currentIndex)) >= displayWords.count (\(displayWords.count))")
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white) // Match Android dark theme
        .overlay(
            showCircleAnimation ? CircleAnimationOverlay() : nil
        )
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.gray)
                        Text("返回")
                            .foregroundColor(.gray)
                    }
                }
                
            }
        }
        .onAppear {
            print("DEBUG: FlipCardView appeared with \(wordList.count) words")
            setupSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !displayWords.isEmpty {
                    fetchSentenceAndPlayAudio(for: displayWords[0])
                }
            }
        }

    }
    
    private func setupSession() {
        print("DEBUG: setupSession called with \(wordList.count) words")
        print("DEBUG: Word list: \(wordList)")
        displayWords = wordList
        isSessionInitialized = true
        
        // Start the session in AuthViewModel
        if let plan = plan {
            authViewModel.startSession(plan: plan, words: wordList)
        }
    }
    
    private func goToNextWord() {
        if currentIndex < displayWords.count - 1 {
            // Reset flip state
            if isFlipped {
                withAnimation {
                    isFlipped = false
                }
                // Delay before moving to next word
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    currentIndex += 1
                    fetchSentenceAndPlayAudio(for: displayWords[currentIndex])
                }
            } else {
                currentIndex += 1
                fetchSentenceAndPlayAudio(for: displayWords[currentIndex])
            }
        } else {
            // End of session
            authViewModel.endSession()
            onSessionComplete()
        }
    }
    
    private func fetchSentenceAndPlayAudio(for word: String) {
        // Fetch sentence in background
        Task {
            let sentencePair = dictionaryViewModel.getRandomEnglishSentence(for: word)
            await MainActor.run {
                self.currentSentenceInfo = sentencePair
            }
            
            // Play word audio, then sentence audio
            await playWordAndSentence(for: word, sentence: sentencePair?.0)
        }
    }

    private func playWordAndSentence(for word: String, sentence: String?) async {
        // First play the word audio
        await dictionaryViewModel.playWord(word) { success in
            if success {
                print("✅ Played word audio: \(word)")
                
                // After word audio completes, play sentence audio if available
                if let sentence = sentence {
                    Task {
                        await self.playSentenceAudio(sentence)
                    }
                }
            } else {
                print("❌ Failed to play word audio: \(word)")
            }
        }
    }

    private func playSentenceAudio(_ sentence: String) async {
        // Generate MD5 hash for the sentence (following the same pattern as word audio)
        let fileHash = sentence.md5() + ".mp3"
        
        // Construct the sentence audio URL from CDN
        let audioURLString = "https://wordsentencevoice.savanalearns.cc/sentence_voice/\(fileHash)"
        
        guard let audioURL = URL(string: audioURLString) else {
            print("Invalid audio URL for sentence")
            return
        }
        
        // Check if we have cached audio locally
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioCache = documentsPath.appendingPathComponent("sentence_audio_cache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: audioCache, withIntermediateDirectories: true)
        
        let localAudioFile = audioCache.appendingPathComponent(fileHash)
        
        do {
            var audioData: Data
            
            if FileManager.default.fileExists(atPath: localAudioFile.path) {
                // Use cached audio
                audioData = try Data(contentsOf: localAudioFile)
                print("Using cached sentence audio")
            } else {
                // Download audio from CDN
                print("Downloading sentence audio from: \(audioURLString)")
                let (data, _) = try await URLSession.shared.data(from: audioURL)
                audioData = data
                
                // Cache the audio file
                try audioData.write(to: localAudioFile)
                print("Cached sentence audio")
            }
            
            // Play the audio
            let audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            print("✅ Playing sentence audio")
            
        } catch {
            print("Failed to play sentence audio: \(error)")
        }
    }
}

// Card front view
struct FrontCardView: View {
    let word: String
    let sentence: String?
    let sentenceIndex: Int?
    
    var body: some View {
        // The parent VStack centers its content vertically by default.
        VStack(spacing: 35) { // Controls the space between the word and sentence
            
            // Word display
            Text(word)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Sentence display (if available)
            if let sentence = sentence, !sentence.isEmpty {
                Text(sentence)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fills the card
        .background(Color(red: 0.17, green: 0.17, blue: 0.17))
        .cornerRadius(24)
        .padding()
    }
}

// Card back view
struct BackCardView: View {
    let fullDefinition: String
    let shortDefinition: String?
    @State private var showFullDefinition = false // Controls visibility

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let short = shortDefinition, !short.isEmpty {
                    Text("简化释义")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(short)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.bottom, 5)
                }
                
                if showFullDefinition {
                    Text("完整释义")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(fullDefinition)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    // Button to reveal the full definition
                    Button(action: {
                        withAnimation { showFullDefinition = true }
                    }) {
                        HStack {
                            Spacer()
                            Text("点击查看完整释义")
                            Image(systemName: "chevron.down.circle")
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(Color.white.opacity(0.7))
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.17, green: 0.17, blue: 0.17)) // Match Android color
        .cornerRadius(24)
        .padding()
    }
}

// Helper button component
struct IconTextButton: View {
    let iconName: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.gray)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// Flip animation effect
//struct FlipEffect: GeometryEffect {
//    @Binding var flipped: Bool
//    var angle: Double
//    let axis: (x: CGFloat, y: CGFloat)
//
//    var animatableData: Double {
//        get { angle }
//        set { angle = newValue }
//    }
//
//    func effectValue(size: CGSize) -> ProjectionTransform {
//        DispatchQueue.main.async {
//            self.flipped = self.angle >= 90 && self.angle < 270
//        }
//
//        let tweakedAngle = flipped ? -180 + angle : angle
//        let a = CGFloat(Angle(degrees: tweakedAngle).radians)
//
//        var transform3d = CATransform3DIdentity
//        transform3d.m34 = -1/max(size.width, size.height)
//        transform3d = CATransform3DRotate(transform3d, a, axis.x, axis.y, 0)
//        transform3d = CATransform3DTranslate(transform3d, -size.width/2.0, -size.height/2.0, 0)
//
//        let affineTransform = ProjectionTransform(CGAffineTransform(translationX: size.width/2.0, y: size.height/2.0))
//
//        return ProjectionTransform(transform3d).concatenating(affineTransform)
//    }
//}

// Circle animation overlay for familiar word
struct CircleAnimationOverlay: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .stroke(Color.green, lineWidth: 3)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    scale = 2.0
                    opacity = 0.0
                }
            }
    }
}
