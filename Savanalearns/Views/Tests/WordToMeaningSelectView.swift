import SwiftUI

struct WordToMeaningSelectView: View {
    @EnvironmentObject var dictionaryViewModel: DictionaryViewModel
    @ObservedObject var testCoordinator: TestCoordinator
    
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var showingFeedback = false
    @State private var results: [WordTestResult] = []
    @State private var options: [String] = []
    
    let questions: [TestQuestion]
    let onComplete: () -> Void
    let onBack: () -> Void
    
    var currentQuestion: TestQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentQuestionIndex), total: Double(questions.count))
                .padding()
            
            if let question = currentQuestion {
                VStack(spacing: 20) {
                    // Question counter
                    Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Word display
                    Text(question.word)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.vertical)
                    
                    // Options
                    VStack(spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            OptionButton(
                                text: option,
                                isSelected: selectedAnswer == option,
                                isCorrect: showingFeedback && option == question.chinese,
                                isWrong: showingFeedback && selectedAnswer == option && option != question.chinese,
                                action: {
                                    if !showingFeedback {
                                        selectAnswer(option)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Next button (shows after selection)
                    if showingFeedback {
                        Button(action: moveToNext) {
                            Text(currentQuestionIndex == questions.count - 1 ? "Finish" : "Next")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .onAppear {
                    generateOptions(for: question)
                }
            } else {
                // Test complete
                CompleteView()
            }
        }
        .navigationTitle("以词选意")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            leading: Button("Back") {
                onBack()
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateOptions(for question: TestQuestion) {
        // Get 3 random simplified definitions (already simplified by getRandomDefinitions)
        let distractors = dictionaryViewModel.getRandomDefinitions(
            excluding: question.word,
            count: 3
        )
        
        // question.chinese should already be simplified from TestCoordinator
        // Mix with correct answer
        options = (distractors + [question.chinese]).shuffled()
    }
    
    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showingFeedback = true
        
        // Create result
        let result = WordTestResult(
            word: currentQuestion?.word ?? "",
            chinese: currentQuestion?.chinese ?? "",
            userAnswer: answer,
            isCorrect: answer == currentQuestion?.chinese,
            testType: TestType.wordToMeaningSelect.rawValue
        )
        results.append(result)
    }
    
    private func moveToNext() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            showingFeedback = false
            if let nextQuestion = currentQuestion {
                generateOptions(for: nextQuestion)
            }
        } else {
            // Test complete - send results to coordinator
            testCoordinator.completeCurrentTest(results: results)
            onComplete()
        }
    }
    
    // MARK: - Subviews
    
    struct OptionButton: View {
        let text: String
        let isSelected: Bool
        let isCorrect: Bool
        let isWrong: Bool
        let action: () -> Void
        
        var backgroundColor: Color {
            if isCorrect {
                return .green.opacity(0.3)
            } else if isWrong {
                return .red.opacity(0.3)
            } else if isSelected {
                return .blue.opacity(0.3)
            } else {
                return Color(.systemGray6)
            }
        }
        
        var borderColor: Color {
            if isCorrect {
                return .green
            } else if isWrong {
                return .red
            } else if isSelected {
                return .blue
            } else {
                return .clear
            }
        }
        
        var body: some View {
            Button(action: action) {
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .padding()
                    .background(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: 2)
                    )
                    .cornerRadius(10)
            }
            .disabled(isCorrect || isWrong)
        }
    }
    
    struct CompleteView: View {
        var body: some View {
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                Text("Test Complete!")
                    .font(.title)
                    .padding()
            }
        }
    }
}
