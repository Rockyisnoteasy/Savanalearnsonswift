//
//  ChineseToEnglishSpellView.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

//
//  ChineseToEnglishSpellView.swift
//  Savanalearns
//
//  Chinese to English Spell Test - 拼写填词
//  Show Chinese meaning, users type the complete English word
//

import SwiftUI

struct ChineseToEnglishSpellView: View {
    @ObservedObject var testCoordinator: TestCoordinator
    let questions: [TestQuestion]
    let onComplete: () -> Void
    let onBack: () -> Void
    
    // MARK: - State Properties
    @State private var currentIndex = 0
    @State private var userInput = ""
    @State private var results: [WordTestResult] = []
    @State private var showFeedback = false
    @State private var isCorrect = false
    @State private var feedbackMessage = ""
    @State private var isSubmitting = false
    
    // Animation states
    @State private var shakeAnimation = false
    @State private var successAnimation = false
    
    // Focus state for keyboard
    @FocusState private var isTextFieldFocused: Bool
    
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
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var testHeader: some View {
        VStack(spacing: 4) {
            Text("拼写填词")
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
            // Chinese meaning display
            VStack(spacing: 12) {
                Text("中文释义：")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(currentQuestion.chinese)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    .modifier(ShakeEffect(shakes: shakeAnimation ? 2 : 0))
                    .animation(.default, value: shakeAnimation)
            }
            .padding(.horizontal)
            .padding(.top, 32)
            
            // Input field
            VStack(spacing: 16) {
                Text("请输入英文单词")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Type your answer here", text: $userInput)
                    .textFieldStyle(CustomTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .disabled(showFeedback)
                    .onSubmit {
                        submitAnswer()
                    }
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
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
                .disabled(userInput.isEmpty || isSubmitting)
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
                .scaleEffect(successAnimation ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: successAnimation)
            
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
    
    // MARK: - Logic Methods
    
    private func submitAnswer() {
        guard !userInput.isEmpty && !isSubmitting else { return }
        
        isSubmitting = true
        isTextFieldFocused = false
        
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        isCorrect = trimmedInput.lowercased() == currentQuestion.word.lowercased()
        
        // Set feedback message
        if isCorrect {
            feedbackMessage = "Correct! Well done!"
            successAnimation = true
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
            testType: TestType.chineseToEnglishSpell.rawValue
        )
        results.append(result)
        
        // Move to next question after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration) {
            moveToNextQuestion()
        }
    }
    
    private func moveToNextQuestion() {
        if currentIndex + 1 < questions.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
                resetForNewQuestion()
            }
            
            // Focus text field for next question
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        } else {
            completeTest()
        }
    }
    
    private func resetForNewQuestion() {
        userInput = ""
        showFeedback = false
        feedbackMessage = ""
        isSubmitting = false
        successAnimation = false
        shakeAnimation = false
    }
    
    private func completeTest() {
        // Report results to coordinator
        testCoordinator.completeCurrentTest(results: results)
        onComplete()
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .font(.title3)
    }
}
