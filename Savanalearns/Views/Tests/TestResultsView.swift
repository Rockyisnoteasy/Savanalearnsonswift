//
//  TestResultsView.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

import SwiftUI

struct TestResultsView: View {
    @ObservedObject var testCoordinator: TestCoordinator
    let onComplete: () -> Void
    let onRetry: () -> Void
    
    var session: WordTestSession? {
        testCoordinator.currentSession
    }
    
    var groupedResults: [String: [WordTestResult]] {
        guard let results = session?.results else { return [:] }
        return Dictionary(grouping: results) { $0.word }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            VStack(spacing: 16) {
                Text("测试完成!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Accuracy circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: session?.accuracy ?? 0)
                        .stroke(accuracyColor, lineWidth: 10)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: session?.accuracy)
                    
                    VStack {
                        Text("\(Int((session?.accuracy ?? 0) * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("正确率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 40) {
                    VStack {
                        Text("\(session?.results.filter { $0.isCorrect }.count ?? 0)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("正确")
                            .font(.caption)
                    }
                    
                    VStack {
                        Text("\(session?.results.filter { !$0.isCorrect }.count ?? 0)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        Text("错误")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Results list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(groupedResults.keys.sorted()), id: \.self) { word in
                        WordResultCard(
                            word: word,
                            results: groupedResults[word] ?? []
                        )
                    }
                }
                .padding()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                if session?.results.contains(where: { !$0.isCorrect }) == true {
                    Button(action: onRetry) {
                        Label("重试错题", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                
                Button(action: onComplete) {
                    Label("完成", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationTitle("测试结果")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
    
    var accuracyColor: Color {
        guard let accuracy = session?.accuracy else { return .gray }
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.6 { return .orange }
        return .red
    }
}

struct WordResultCard: View {
    let word: String
    let results: [WordTestResult]
    
    @State private var isExpanded = false
    
    var overallCorrect: Bool {
        results.allSatisfy { $0.isCorrect }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: overallCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(overallCorrect ? .green : .red)
                
                Text(word)
                    .font(.headline)
                
                Spacer()
                
                if results.count > 1 {
                    Text("\(results.filter { $0.isCorrect }.count)/\(results.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(results) { result in
                        HStack {
                            Text(testTypeName(result.testType))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if result.isCorrect {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                VStack(alignment: .trailing) {
                                    Text("答案: \(result.userAnswer)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text("正确: \(result.chinese)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func testTypeName(_ typeString: String) -> String {
        guard let testType = TestType(rawValue: typeString) else { return typeString }
        return testType.displayName
    }
}
