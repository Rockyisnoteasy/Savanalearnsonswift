// Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dictionaryViewModel = DictionaryViewModel()

    // 1. 新增状态变量，用于控制导航和传递数据
    @State private var showFlipCard = false
    @State private var wordsForCurrentSession: [String] = []
    @State private var currentPlanForTest: Plan? = nil
    // 跟踪是新学还是复习
    @State private var isNewWordSession: Bool = true


    var body: some View {
        // 2. 使用 ScrollView 包含所有内容
        ScrollView {
            VStack(spacing: 20) {
                // 3. 将搜索栏放在顶部
                DictionarySearchBarView()
                    .padding(.horizontal)
                
                // 4. 修改 LearningPlanView 的调用，传入回调函数
                LearningPlanView(
                    authViewModel: authViewModel,
                    onStartLearnNew: { plan, words in
                        print("MainActivity: Starting NEW WORD session for planId=\(plan.id)")
                        self.currentPlanForTest = plan
                        self.wordsForCurrentSession = words
                        self.isNewWordSession = true // 标记为新学 session
                        // 调用 ViewModel 记录当前会话信息
                        self.authViewModel.startSession(plan: plan, words: words)
                        self.showFlipCard = true
                    },
                    onStartReview: { plan, words in
                        print("MainActivity: Starting REVIEW session for planId=\(plan.id)")
                        self.currentPlanForTest = plan
                        self.wordsForCurrentSession = words
                        self.isNewWordSession = false // 标记为复习 session
                        // 调用 ViewModel 记录当前会话信息
                        self.authViewModel.startSession(plan: plan, words: words)
                        self.showFlipCard = true
                    }
                )
                .padding(.horizontal)
                
                //Spacer()
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .navigationTitle("SavanaLearns")
        .navigationBarTitleDisplayMode(.inline)
        // 5. 将 dictionaryViewModel 注入环境，供子视图使用
        .environmentObject(dictionaryViewModel)
        // 6. 添加 .fullScreenCover 用于呈现翻牌卡片页面
        .fullScreenCover(isPresented: $showFlipCard) {
            // 当 showFlipCard 为 true 时，显示这个页面
            NavigationView {
                FlipCardView(
                    wordList: wordsForCurrentSession,
                    onSessionComplete: {
                        // 当翻牌学习结束后，关闭页面
                        // 后续的测试流程将在这里触发
                        print("翻牌记忆环节结束")
                        self.showFlipCard = false
                    },

                    onBack: {
                        self.showFlipCard = false
                    }
                )
            }
            .environmentObject(dictionaryViewModel) // 确保 FlipCardView 也能访问到
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        // 为了让预览正常工作，需要用 NavigationView 包裹
        NavigationView {
            HomeView(authViewModel: AuthViewModel())
        }
    }
}
