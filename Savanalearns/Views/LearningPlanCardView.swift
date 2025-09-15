// Views/LearningPlanCardView.swift
import SwiftUI

struct LearningPlanCardView: View {
    let plan: Plan
    let progress: PlanProgress?
    // 接收每日任务数据
    let dailySession: DailySession?
    // 1. 新增闭包属性，用于处理按钮点击事件
    var onStartLearnNew: (Plan, [String]) -> Void
    var onStartReview: (Plan, [String]) -> Void
    
    // 从 dailySession 中获取新词数量
    private var newCount: Int {
        dailySession?.newWords.count ?? 0
    }
    
    // 从 dailySession 中获取复习词数量
    private var reviewCount: Int {
        dailySession?.reviewWords.count ?? 0
    }
    
    private var remainingDays: Int {
        guard let progress = progress,
              let total = progress.totalCount,
              total > 0,
              plan.dailyCount > 0
        else {
            return 0
        }
        let remainingWords = total - progress.learnedCount
        
        // 1. 先计算出需要被约束的原始值
        let rawValue = remainingWords + plan.dailyCount - 1
        
        // 2. 在这个明确的 Int 变量上调用我们的扩展方法
        let coercedValue = rawValue.coerceAtLeast(0)
        
        // 3. 最后再进行除法运算
        return coercedValue / plan.dailyCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plan.planName)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button("修改") {
                    // TODO: 实现修改逻辑
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                // 如果 totalCount 存在且大于0，才显示进度条
                if let total = progress?.totalCount, total > 0 {
                    ProgressView(value: Double(progress?.learnedCount ?? 0), total: Double(total))
                        .tint(.orange)
                }

                HStack {
                    Text("\(progress?.learnedCount ?? 0) / \(progress?.totalCount ?? 0)")
                    Spacer()
                    Text("剩余 \(remainingDays) 天")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            // 如果该计划被暂停学习新词，显示提示
            if dailySession?.isNewWordPaused == true {
                 Text("复习任务繁重，已暂停学习新词")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
            
            Text("今日任务：")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // 使用从 dailySession 获取的真实数据
            Text("需新学: \(newCount) 词   需复习: \(reviewCount) 词")
                .font(.callout)
            
            HStack(spacing: 12) {
                // 2. 修改“复习”按钮的 action
                Button(action: {
                    print("DEBUG: Review button clicked for plan \(plan.planName)")
                    print("DEBUG: reviewWords count: \(dailySession?.reviewWords.count ?? -1)")
                    
                    if let words = dailySession?.reviewWords, !words.isEmpty {
                        print("DEBUG: Using review words: \(words)")
                        onStartReview(plan, words)
                    } else {
                        print("DEBUG: No review words available")
                    }
                }) {
                    Text("复习 \(reviewCount) 词")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(reviewCount == 0)

                // 3. 修改“学习”按钮的 action
                Button(action: {
                    // Debug: Print what we have
                    print("DEBUG: Button clicked for plan \(plan.planName)")
                    print("DEBUG: dailySession exists: \(dailySession != nil)")
                    print("DEBUG: newWords count: \(dailySession?.newWords.count ?? -1)")
                    print("DEBUG: newWords: \(dailySession?.newWords ?? [])")
                    
                    // Try to get words from dailySession first, fallback to plan if needed
                    var wordsToUse: [String] = []
                    
                    if let sessionWords = dailySession?.newWords, !sessionWords.isEmpty {
                        wordsToUse = sessionWords
                        print("DEBUG: Using words from dailySession: \(sessionWords)")
                    } else if let planWords = plan.dailyWords?.first?.words, !planWords.isEmpty {
                        wordsToUse = planWords
                        print("DEBUG: Using words from plan.dailyWords: \(planWords)")
                    } else {
                        print("DEBUG: No words found anywhere!")
                        // Create some test words as fallback
                        wordsToUse = ["test", "word", "example"]
                        print("DEBUG: Using fallback test words: \(wordsToUse)")
                    }
                    
                    onStartLearnNew(plan, wordsToUse)
                }) {
                    Text("学习 \(newCount) 词")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                // 如果计划被暂停或没有新词，则禁用学习按钮
                .disabled(newCount == 0 || dailySession?.isNewWordPaused == true)
            }
            
            Button("查看复习进度 →") {
                 // TODO: 跳转到复习进度页
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)

        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 辅助扩展保持不变
extension Int {
    func coerceAtLeast(_ minimum: Int) -> Int {
        return Swift.max(self, minimum)
    }
}
