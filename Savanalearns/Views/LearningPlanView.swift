// Views/LearningPlanView.swift
import SwiftUI

struct LearningPlanView: View {
    @StateObject private var planViewModel = PlanViewModel()
    @ObservedObject var authViewModel: AuthViewModel

    // 1. 新增闭包属性，用于接收来自 HomeView 的回调
    var onStartLearnNew: (Plan, [String]) -> Void
    var onStartReview: (Plan, [String]) -> Void
    
    @State private var showCreatePlanSheet = false

    var body: some View {
        // 2. 移除外层的 NavigationView
        // 使用 VStack 代替，因为它现在是 HomeView 的一部分，而不是一个独立的导航页面
        VStack {
            // 使用 ScrollView 替代 List，以更好地控制卡片间距和背景
            ScrollView {
                VStack(spacing: 16) {
                    if planViewModel.isLoading && planViewModel.plans.isEmpty {
                        ProgressView("加载中...")
                            .padding(.top, 50)
                    } else if let errorMessage = planViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    } else if planViewModel.plans.isEmpty {
                        Text("还没有学习计划，点击右上方“+”创建一个吧！")
                            .padding()
                    } else {
                        // 遍历计划列表，为每个计划创建一个卡片视图
                        ForEach(planViewModel.plans) { plan in
                            if let planId = plan.id {
                                LearningPlanCardView(
                                    plan: plan,
                                    // 从 ViewModel 中获取对应的进度
                                    progress: planViewModel.progress[planId],
                                    // 新增: 传递对应的 dailySession 数据
                                    dailySession: planViewModel.dailySessions[planId],
                                    // 3. 将接收到的闭包传递给 LearningPlanCardView
                                    onStartLearnNew: onStartLearnNew,
                                    onStartReview: onStartReview
                                )
                            }
                        }
                    }
                }
                .padding() // 给整个 VStack 添加边距
            }
            .background(Color(.systemGray6)) // 设置一个浅灰色背景，突出卡片
            // 4. 将导航标题和工具栏移至 HomeView 管理，但此处暂时保留 UI 以便后续步骤迁移
            // .navigationTitle("我的学习计划") // 这行应在 HomeView 中设置
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreatePlanSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                if let token = authViewModel.token {
                    planViewModel.fetchPlans(token: token)
                }
            }
            .sheet(isPresented: $showCreatePlanSheet) {
                CreatePlanView(planViewModel: planViewModel, authViewModel: authViewModel)
            }
        }
    }
}

// CreatePlanView 保持不变
struct CreatePlanView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var planViewModel: PlanViewModel
    @ObservedObject var authViewModel: AuthViewModel
    
    // --- 新增状态 ---
    @State private var planName = ""
    @State private var dailyCount = "20"
    
    // 用于存储从 JSON 加载的词本清单
    @State private var wordbookManifest: [WordbookCategory] = []
    // 用户选择的分类
    @State private var selectedCategory: WordbookCategory?
    // 用户选择的词本
    @State private var selectedWordbook: Wordbook?
    
    private let wordbookService = WordbookService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("计划设置")) {
                    TextField("计划名称", text: $planName)
                    TextField("每日单词数", text: $dailyCount)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("选择词本")) {
                    // 分类选择器
                    Picker("分类", selection: $selectedCategory) {
                        Text("请选择分类").tag(nil as WordbookCategory?)
                        ForEach(wordbookManifest) { category in
                            Text(category.categoryName).tag(category as WordbookCategory?)
                        }
                    }
                    
                    // 词本选择器 (只有当分类被选择后才可用)
                    if let selectedCategory = selectedCategory {
                        Picker("词本", selection: $selectedWordbook) {
                            Text("请选择词本").tag(nil as Wordbook?)
                            ForEach(selectedCategory.wordbooks) { wordbook in
                                Text(wordbook.bookName).tag(wordbook as Wordbook?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("创建新计划")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        savePlan()
                    }
                    // 只有所有选项都填好后，保存按钮才可用
                    .disabled(planName.isEmpty || dailyCount.isEmpty || selectedCategory == nil || selectedWordbook == nil)
                }
            }
            .onAppear {
                // 当视图出现时，加载词本清单
                self.wordbookManifest = wordbookService.loadWordbookManifest()
            }
            // 当分类变化时，自动清空已选的词本
            .onChange(of: selectedCategory) {
                selectedWordbook = nil
            }
        }
    }
    
    private func savePlan() {
        guard let token = authViewModel.token,
              let count = Int(dailyCount),
              let category = selectedCategory,
              let wordbook = selectedWordbook else {
            return
        }
        
        let request = PlanCreateRequest(
            planName: planName,
            category: category.categoryName, // 使用选择的分类名
            selectedPlan: wordbook.bookName, // 使用选择的词本名
            dailyCount: count
        )
        
        planViewModel.createPlan(planRequest: request, token: token)
        dismiss()
    }
}
