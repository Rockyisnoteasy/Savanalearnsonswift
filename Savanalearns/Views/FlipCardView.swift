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
                // Empty state - session complete
                EmptyView()
                    .onAppear {
                        onSessionComplete()
                    }
            } else if currentIndex < displayWords.count {
                let word = displayWords[currentIndex]
                
                // Progress indicator
                HStack {
                    Text("\(currentIndex + 1)/\(displayWords.count)")
                        .font(.subheadline)
                    Spacer()
                    Text("熟悉度：○")
                        .font(.subheadline)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Flip card
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
                .modifier(FlipEffect(flipped: $isFlipped, angle: isFlipped ? 180 : 0, axis: (x: 0, y: 1)))
                .onTapGesture {
                    withAnimation(.spring()) {
                        isFlipped.toggle()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    // Mark word as familiar
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
                        // Play audio for current word and sentence
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
            }
        }
        .overlay(
            // Circle animation overlay for familiar word
            showCircleAnimation ? CircleAnimationOverlay() : nil
        )
        .padding()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
        }
        .onAppear {
            setupSession()
            if !displayWords.isEmpty {
                fetchSentenceAndPlayAudio(for: displayWords[0])
            }
        }
        .onDisappear {
            // Stop any playing audio
            // TODO: Implement audio stop
        }
    }
    
    private func setupSession() {
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
            Text(word)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let sentence = sentence {
                Text(sentence)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
    }
}

// Card back view
struct BackCardView: View {
    let fullDefinition: String
    let shortDefinition: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let short = shortDefinition {
                    Text("简化释义")
                        .font(.headline)
                    Text(short)
                        .font(.body)
                    
                    Divider()
                }
                
                Text("完整释义")
                    .font(.headline)
                Text(fullDefinition)
                    .font(.body)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
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
                Text(label)
                    .font(.caption)
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
