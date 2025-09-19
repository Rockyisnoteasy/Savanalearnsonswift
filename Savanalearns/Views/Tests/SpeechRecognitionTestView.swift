//
//  SpeechRecognitionTestView.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/18.
//

import SwiftUI
import AVFoundation

struct SpeechRecognitionTestView: View {
    @ObservedObject var testCoordinator: TestCoordinator
    @ObservedObject var dictionaryViewModel: DictionaryViewModel
    @ObservedObject var authViewModel: AuthViewModel
    let questions: [TestQuestion]
    let onComplete: () -> Void
    let onBack: () -> Void
    
    // MARK: - State Properties
    @State private var currentIndex = 0
    @State private var results: [WordTestResult] = []
    @State private var isRecording = false
    @State private var recognizedText: String?
    @State private var isCurrentAnswerCorrect: Bool?
    @State private var loadingStatus: String?
    @State private var showNextButton = false
    @State private var recordingStartTime: Date?
    @State private var isProcessing = false
    @StateObject private var audioRecorder = AudioRecordingManager.shared
    
    private var currentQuestion: TestQuestion {
        questions[currentIndex]
    }
    
    private var progressPercentage: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(questions.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            testHeader
            
            // Progress bar
            progressBar
            
            // Main Content
            VStack(spacing: 20) {
                Spacer()
                
                // Chinese meaning
                Text(currentQuestion.chinese)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Recognized text or placeholder
                recognizedTextView
                    .padding(.vertical, 20)
                
                // Status message (e.g., "Recording...", "Uploading...")
                statusView
                
                Spacer()
                
                // Action button (Mic or Next)
                if showNextButton {
                    nextButton
                } else {
                    micButton
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
        .onAppear(perform: checkMicrophonePermission)
    }

    // MARK: - View Components

    private var testHeader: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
    }

    private var progressBar: some View {
        VStack {
            Text("\(currentIndex + 1) / \(questions.count)")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progressPercentage)
                        .animation(.easeInOut, value: progressPercentage)
                }
                .frame(height: 4)
                .cornerRadius(2)
            }
            .frame(height: 4)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var recognizedTextView: some View {
        if let recognized = recognizedText {
            Text(recognized)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(isCurrentAnswerCorrect == true ? .green : .red)
                .transition(.opacity.animation(.easeInOut))
        } else {
            HStack(spacing: 6) {
                ForEach(0..<currentQuestion.word.count, id: \.self) { _ in
                    Text("_")
                        .font(.system(size: 32, weight: .bold))
                }
            }
            .foregroundColor(.gray.opacity(0.5))
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let status = loadingStatus {
            VStack {
                if status.contains("上传") || status.contains("识别中") {
                    ProgressView()
                }
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .frame(height: 60)
        } else {
            Rectangle().fill(Color.clear).frame(height: 60)
        }
    }
    
    private var micButton: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.8) : Color.blue)
                    .frame(width: 90, height: 90)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                
                Image(systemName: "mic.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 36))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        // This closure is called once when the finger touches down.
                        // We check if it's already recording to prevent it from firing multiple times.
                        if !isRecording {
                            startRecording()
                        }
                    }
                    .onEnded { _ in
                        // This closure is called once when the finger is lifted.
                        stopRecordingAndSubmit()
                    }
            )
            .disabled(isProcessing)
            .animation(.spring(), value: isRecording)

            Text("按住说话")
                .font(.body)
                .foregroundColor(.gray)
        }
    }

    private var nextButton: some View {
        Button(action: moveToNextQuestion) {
            Text(currentIndex + 1 < questions.count ? "下一题" : "完成测试")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
        }
        .padding(.horizontal, 40)
        .transition(.scale.animation(.spring()))
    }
    
    // MARK: - Logic Methods
    
    private func checkMicrophonePermission() {
        Task {
            if !audioRecorder.hasPermission {
                await audioRecorder.requestPermission()
            }
        }
    }
    
    private func startRecording() {
        print("🎤 Gesture: Attempting to start recording...")
        print("🎤 Current permissions: \(audioRecorder.hasPermission)")  // Add this line
        print("🎤 Is already recording: \(isRecording)")
        guard audioRecorder.hasPermission else {
            print("❌ Failure: Microphone permission denied.")
            loadingStatus = "请在设置中开启麦克风权限"
            return
        }
        
        if isRecording {
            print("⚠️ Warning: Already recording.")
            return
        }
        
        // Clear previous state before starting
        recognizedText = nil
        isCurrentAnswerCorrect = nil
        loadingStatus = "正在聆听..."
        
        if audioRecorder.startRecording() != nil {
            isRecording = true
            print("✅ Success: Recording started.")
        } else {
            print("❌ Failure: audioRecorder.startRecording() failed.")
            loadingStatus = "录音启动失败"
        }
    }
    
    private func stopRecordingAndSubmit() {
        print("🎤 Gesture: Attempting to stop recording...")
        print("🎤 stopRecordingAndSubmit() called")
        print("🎤 Current recording state: \(isRecording)")
        guard isRecording else {
            print("⚠️ Warning: Not recording, cannot stop.")
            return
        }
        
        isRecording = false
        
        guard let audioFileURL = audioRecorder.stopRecording() else {
            print("❌ Failure: Recording was too short or failed to save.")
            loadingStatus = "录音时间太短"
            resetAfterDelay()
            return
        }
        
        print("✅ Success: Recording stopped. File at \(audioFileURL.lastPathComponent)")
        submitAudioForRecognition(audioFileURL: audioFileURL)
    }
    
    private func submitAudioForRecognition(audioFileURL: URL) {
        isProcessing = true
        loadingStatus = "上传并识别中..."
        
        Task {
            // Step 1: Generate upload URL
            guard let (uploadUrl, objectKey) = await authViewModel.generateUploadUrl(filename: audioFileURL.lastPathComponent) else {
                loadingStatus = "错误：无法获取上传授权"
                audioRecorder.deleteRecording(at: audioFileURL)
                resetAfterDelay()
                return
            }
            
            // Step 2: Upload audio to OSS
            let uploadSuccess = await authViewModel.uploadAudioToOSS(fileURL: audioFileURL, uploadURL: uploadUrl)
            guard uploadSuccess else {
                loadingStatus = "错误：上传录音失败"
                audioRecorder.deleteRecording(at: audioFileURL)
                resetAfterDelay()
                return
            }
            
            // Step 3: Submit for recognition
            let resultText = await authViewModel.recognizeSpeechTransient(
                objectKey: objectKey,
                word: currentQuestion.word,
                planId: testCoordinator.currentSession?.planId ?? 0
            )
            
            audioRecorder.deleteRecording(at: audioFileURL)
            processRecognitionResult(resultText)
        }
    }
    
    private func processRecognitionResult(_ resultText: String?) {
        isProcessing = false
        loadingStatus = nil
        
        guard let recognized = resultText, !recognized.isEmpty else {
            self.recognizedText = "识别失败"
            self.isCurrentAnswerCorrect = false
            recordResult(userAnswer: "识别失败", isCorrect: false)
            showNextButton = true
            return
        }
        
        self.recognizedText = recognized
        
        // Use DictionaryViewModel for accurate comparison
        let normalizedRecognized = dictionaryViewModel.normalizeAnswer(recognized)
        let normalizedTarget = dictionaryViewModel.normalizeAnswer(currentQuestion.word)
        
        var isCorrect = (normalizedRecognized == normalizedTarget)
        if !isCorrect {
            isCorrect = dictionaryViewModel.checkIfHomophones(recognized, currentQuestion.word)
        }
        
        self.isCurrentAnswerCorrect = isCorrect
        recordResult(userAnswer: recognized, isCorrect: isCorrect)
        showNextButton = true
    }
    
    private func recordResult(userAnswer: String, isCorrect: Bool) {
        let result = WordTestResult(
            word: currentQuestion.word,
            chinese: currentQuestion.chinese,
            userAnswer: userAnswer,
            isCorrect: isCorrect,
            testType: TestType.speechRecognitionTest.rawValue
        )
        results.append(result)
    }
    
    private func moveToNextQuestion() {
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            resetForNewQuestion()
        } else {
            completeTest()
        }
    }
    
    private func resetForNewQuestion() {
        withAnimation {
            recognizedText = nil
            isCurrentAnswerCorrect = nil
            loadingStatus = nil
            showNextButton = false
        }
    }
    
    private func resetAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                loadingStatus = nil
            }
        }
    }
    
    private func completeTest() {
        testCoordinator.completeCurrentTest(results: results)
        onComplete()
    }
}
