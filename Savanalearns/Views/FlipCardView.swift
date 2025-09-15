// Views/FlipCardView.swift
import SwiftUI

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
    
    var body: some View {
        VStack {
            if displayWords.isEmpty {
                Text("No words to display")
                    .onAppear {
                        print("DEBUG: displayWords is empty, calling onSessionComplete")
                        onSessionComplete()
                    }
            } else if currentIndex < displayWords.count {
                let word = displayWords[currentIndex]
                
                // DEBUG: Print current state
                let _ = print("DEBUG: Showing word '\(word)' (\(currentIndex + 1)/\(displayWords.count))")
                
                // Progress indicator
                HStack {
                    Text("\(currentIndex + 1)/\(displayWords.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("熟悉度：○")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Flip card with proper sizing
                ZStack {
                    if !isFlipped {
                        FrontCardView(
                            word: word,
                            sentence: currentSentenceInfo?.0,
                            sentenceIndex: currentSentenceInfo?.1
                        )
                    } else {
                        BackCardView(
                            fullDefinition: dictionaryViewModel.getDefinition(for: word) ?? "无释义",
                            shortDefinition: dictionaryViewModel.getSimplifiedDefinition(for: word)
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 400) // Fixed height to ensure visibility
                .modifier(FlipEffect(flipped: $isFlipped, angle: isFlipped ? 180 : 0, axis: (x: 0, y: 1)))
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
                        playAudio(for: word)
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
        .background(Color.black) // Match Android dark theme
        .overlay(
            showCircleAnimation ? CircleAnimationOverlay() : nil
        )
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                        Text("返回")
                            .foregroundColor(.white)
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
            
            // Play audio
            playAudio(for: word)
        }
    }
    
    private func playAudio(for word: String) {
        // TODO: Implement actual audio playback
        dictionaryViewModel.playWordAndThenSentence(
            word,
            currentSentenceInfo?.0,
            context: self
        )
    }
}

// Card front view
struct FrontCardView: View {
    let word: String
    let sentence: String?
    let sentenceIndex: Int?
    
    var body: some View {
        VStack(spacing: 20) {
            // Word display
            Text(word)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Sentence display (if available)
            if let sentence = sentence {
                Spacer()
                Text(sentence)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            } else {
                // Debug: Show when no sentence
                Text("(No sentence available)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.17, green: 0.17, blue: 0.17)) // Match Android color #2B2B2B
        .cornerRadius(24)
        .padding()
    }
}

// Card back view
struct BackCardView: View {
    let fullDefinition: String
    let shortDefinition: String?
    
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
                }
                
                Text("完整释义")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(fullDefinition)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
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
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}

// Flip animation effect
struct FlipEffect: GeometryEffect {
    @Binding var flipped: Bool
    var angle: Double
    let axis: (x: CGFloat, y: CGFloat)
    
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        DispatchQueue.main.async {
            self.flipped = self.angle >= 90 && self.angle < 270
        }
        
        let tweakedAngle = flipped ? -180 + angle : angle
        let a = CGFloat(Angle(degrees: tweakedAngle).radians)
        
        var transform3d = CATransform3DIdentity
        transform3d.m34 = -1/max(size.width, size.height)
        transform3d = CATransform3DRotate(transform3d, a, axis.x, axis.y, 0)
        transform3d = CATransform3DTranslate(transform3d, -size.width/2.0, -size.height/2.0, 0)
        
        let affineTransform = ProjectionTransform(CGAffineTransform(translationX: size.width/2.0, y: size.height/2.0))
        
        return ProjectionTransform(transform3d).concatenating(affineTransform)
    }
}

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
