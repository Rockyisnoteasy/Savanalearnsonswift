//
//  ListeningTestView.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

//
//  ListeningTestView.swift
//  Savanalearns
//
//  Listening Test - 听力填词
//  Plays audio of words and users type what they hear
//

import SwiftUI
import AVFoundation
import Combine
import CryptoKit

struct ListeningTestView: View {
    @ObservedObject var testCoordinator: TestCoordinator
    @ObservedObject var dictionaryViewModel: DictionaryViewModel
    let questions: [TestQuestion]
    let onComplete: () -> Void
    let onBack: () -> Void
    
    // MARK: - State Properties
    @State private var currentIndex = 0
    @State private var userInput = ""
    @State private var results: [WordTestResult] = []
    @State private var isPlayingAudio = false
    @State private var audioLoadingError = false
    @State private var showFeedback = false
    @State private var isCorrect = false
    @State private var feedbackMessage = ""
    
    // Audio player
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentAudioPlayer: AVAudioPlayer?
    @State private var audioDelegate: AudioPlayerDelegate?
    
    // Audio delegate class
    class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
        var continuation: CheckedContinuation<Void, Never>?
        
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            continuation?.resume()
            continuation = nil
        }
        
        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            print("❌ Audio decode error: \(error?.localizedDescription ?? "Unknown")")
            continuation?.resume()
            continuation = nil
        }
    }
    @State private var playCount = 0
    private let maxPlayCount = 3
    
    // Focus state for keyboard
    @FocusState private var isTextFieldFocused: Bool
    
    // Animation states
    @State private var speakerPulse = false
    @State private var shakeAnimation = false
    
    // Constants
    private let feedbackDuration = 1.5
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            testHeader
            
            // Progress bar
            progressBar
            
            if currentIndex < questions.count {
                // Main content
                questionContent
            } else {
                EmptyView()
                    .onAppear {
                        completeTest()
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            setupAudioSession()
            playCurrentWordAudio()
        }
        .onDisappear {
            audioPlayer?.stop()
        }
    }
    
    // MARK: - View Components
    
    private var testHeader: some View {
        VStack(spacing: 4) {
            Text("听力填词")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                Text("第 \(currentIndex + 1) 题")
                Text("/")
                Text("\(questions.count) 题")
            }
            .font(.subheadline)
            .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(
                        width: geometry.size.width * progressPercentage,
                        height: 4
                    )
                    .animation(.easeInOut(duration: 0.3), value: progressPercentage)
            }
        }
        .frame(height: 4)
    }
    
    private var questionContent: some View {
        VStack(spacing: 32) {
            // Audio play area
            VStack(spacing: 24) {
                Text("请听音频并输入听到的单词")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Play button
                Button(action: {
                    playCurrentWordAudio()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                            .scaleEffect(speakerPulse ? 1.2 : 1.0)
                            .animation(isPlayingAudio ?
                                Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true) :
                                Animation.default,
                                value: speakerPulse
                            )
                        
                        Text(isPlayingAudio ? "播放中..." : "🔊 重播语音")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        if playCount > 0 {
                            Text("播放次数: \(playCount)/\(maxPlayCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(width: 200, height: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                            )
                    )
                }
                .disabled(isPlayingAudio || playCount >= maxPlayCount || showFeedback)
                
                if audioLoadingError {
                    Text("⚠️ 音频加载失败，请重试")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 20)
            
            // Input field
            VStack(spacing: 16) {
                TextField("Type what you hear", text: $userInput)
                    .textFieldStyle(CustomTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .disabled(showFeedback)
                    .onSubmit {
                        submitAnswer()
                    }
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .modifier(ShakeEffect(shakes: shakeAnimation ? 2 : 0))
                    .animation(.default, value: shakeAnimation)
            }
            .padding(.horizontal)
            
            // Feedback display
            if showFeedback {
                feedbackView
            }
            
            Spacer()
            
            // Submit button
            if !showFeedback {
                Button(action: submitAnswer) {
                    Text("提交")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(userInput.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(userInput.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }
    
    private var feedbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(isCorrect ? .green : .red)
            
            VStack(spacing: 8) {
                Text(feedbackMessage)
                    .font(.headline)
                    .foregroundColor(isCorrect ? .green : .red)
                
                if !isCorrect {
                    VStack(spacing: 4) {
                        Text("Your answer: \(userInput)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Correct answer: \(currentQuestion.word)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCorrect ? Color.green : Color.red, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private var backButton: some View {
        Button(action: {
            audioPlayer?.stop()
            onBack()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("返回")
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var currentQuestion: TestQuestion {
        questions[currentIndex]
    }
    
    private var progressPercentage: Double {
        questions.isEmpty ? 0 : Double(currentIndex) / Double(questions.count)
    }
    
    // MARK: - Audio Methods
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func playCurrentWordAudio() {
        guard playCount < maxPlayCount else { return }
        
        isPlayingAudio = true
        speakerPulse = true
        audioLoadingError = false
        
        Task {
            let success = await playWordAudio(currentQuestion.word)
            
            await MainActor.run {
                self.isPlayingAudio = false
                self.speakerPulse = false
                
                if success {
                    self.playCount += 1
                    
                    // Auto-focus text field after first play
                    if self.playCount == 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isTextFieldFocused = true
                        }
                    }
                } else {
                    self.audioLoadingError = true
                }
            }
        }
    }

    private func playWordAudio(_ word: String) async -> Bool {
        print("DEBUG: Playing word audio for: \(word)")
        
        let wordLower = word.lowercased()
        let fileHash = wordLower.md5() + ".mp3"
        let audioURLString = "https://wordsentencevoice.savanalearns.cc/voice_cache/\(fileHash)"
        
        guard let audioURL = URL(string: audioURLString) else {
            print("❌ Invalid audio URL for word: \(word)")
            return false
        }
        
        return await playAudioFromURL(audioURL, cacheDir: "audio_cache")
    }

    private func playAudioFromURL(_ audioURL: URL, cacheDir: String) async -> Bool {
        do {
            // Setup paths
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioCache = documentsPath.appendingPathComponent(cacheDir, isDirectory: true)
            
            // Create cache directory if needed
            try? FileManager.default.createDirectory(at: audioCache, withIntermediateDirectories: true)
            
            let fileName = audioURL.lastPathComponent
            let localAudioFile = audioCache.appendingPathComponent(fileName)
            
            let audioData: Data
            
            if FileManager.default.fileExists(atPath: localAudioFile.path) {
                print("Using cached audio")
                audioData = try Data(contentsOf: localAudioFile)
            } else {
                print("Downloading audio from: \(audioURL.absoluteString)")
                let (data, _) = try await URLSession.shared.data(from: audioURL)
                audioData = data
                
                // Cache the audio
                try audioData.write(to: localAudioFile)
                print("Cached audio")
            }
            
            // Play audio with proper completion handling
            let delegate = AudioPlayerDelegate()
            await withCheckedContinuation { continuation in
                delegate.continuation = continuation
                
                DispatchQueue.main.async {
                    // Stop any currently playing audio first
                    self.currentAudioPlayer?.stop()
                    
                    do {
                        let audioPlayer = try AVAudioPlayer(data: audioData)
                        self.currentAudioPlayer = audioPlayer
                        self.audioDelegate = delegate
                        
                        audioPlayer.delegate = self.audioDelegate
                        audioPlayer.volume = 1.0
                        
                        if audioPlayer.play() {
                            print("✅ Playing audio successfully")
                        } else {
                            print("❌ Failed to start audio playback")
                            continuation.resume()
                        }
                    } catch {
                        print("❌ Failed to create AVAudioPlayer: \(error)")
                        continuation.resume()
                    }
                }
            }
            
            return true
            
        } catch {
            print("❌ Failed to play audio: \(error)")
            return false
        }
    }
    // MARK: - Logic Methods
    
    private func submitAnswer() {
        guard !userInput.isEmpty else { return }
        
        isTextFieldFocused = false
        
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        isCorrect = trimmedInput.lowercased() == currentQuestion.word.lowercased()
        
        // Set feedback message
        if isCorrect {
            feedbackMessage = "Correct! Well done!"
        } else {
            feedbackMessage = "Incorrect"
            shakeAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeAnimation = false
            }
        }
        
        showFeedback = true
        
        // Record result
        let result = WordTestResult(
            word: currentQuestion.word,
            chinese: currentQuestion.chinese,
            userAnswer: trimmedInput,
            isCorrect: isCorrect,
            testType: TestType.listeningTest.rawValue
        )
        results.append(result)
        
        // Move to next question after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration) {
            moveToNextQuestion()
        }
    }
    
    private func moveToNextQuestion() {
        audioPlayer?.stop()
        
        if currentIndex + 1 < questions.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
                resetForNewQuestion()
            }
            
            // Play audio for next question
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                playCurrentWordAudio()
            }
        } else {
            completeTest()
        }
    }
    
    private func resetForNewQuestion() {
        userInput = ""
        showFeedback = false
        feedbackMessage = ""
        playCount = 0
        audioLoadingError = false
        shakeAnimation = false
        speakerPulse = false
    }
    
    private func completeTest() {
        audioPlayer?.stop()
        
        // Report results to coordinator
        testCoordinator.completeCurrentTest(results: results)
        onComplete()
    }
}

