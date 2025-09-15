// ViewModels/PlanViewModel.swift
import Foundation
import Combine

@MainActor
class PlanViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var progress: [Int: PlanProgress] = [:]
    // 新增: 用于存储每个计划的每日任务
    @Published var dailySessions: [Int: DailySession] = [:]
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var networkService = NetworkService()
    
    func fetchPlans(token: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. 先获取所有计划
                let fetchedPlans = try await networkService.getPlans(token: token)
                self.plans = fetchedPlans
                
                // 2. 然后并行获取所有计划的进度和每日任务
                await fetchDetailsForAllPlans(token: token)
                
            } catch {
                self.errorMessage = "无法加载学习计划: \(error.localizedDescription)"
                print("❌ Fetch plans error: \(error)")
            }
            isLoading = false
        }
    }
    
    // 升级: 将获取进度和每日任务合并到一个并行任务组中
    private func fetchDetailsForAllPlans(token: String) async {
        let wordManagementService = WordManagementService()
        await withTaskGroup(of: Void.self) { group in
            for plan in plans {
                if let planId = plan.id {
                    // 并行获取进度
                    group.addTask {
                        do {
                            let progressData = try await self.networkService.getPlanProgress(planId: planId, token: token)
                            // 在主线程更新UI状态
                            await MainActor.run {
                                self.progress[planId] = progressData
                            }
                        } catch {
                            print("❌ 获取计划 \(planId) 进度失败: \(error)")
                        }
                    }
                    
                    // 并行获取每日任务
                    group.addTask {
                        do {
                            let sessionData = try await self.networkService.getDailySession(planId: planId, token: token)
                            await MainActor.run {
                                self.dailySessions[planId] = sessionData
                            }
                            
                            let shouldGenerate = sessionData.newWords.isEmpty && !sessionData.isNewWordPaused
                            if shouldGenerate {
                                print("⚠️ PlanViewModel: 计划 \(planId) 没有新词，开始触发生成流程...")
                                // 3. ✅ 调用服务来生成和上传单词
                                let success = await wordManagementService.generateAndUploadWords(for: plan, token: token)
                                if success {
                                    print("✅ PlanViewModel: 为计划 \(planId) 生成新词成功，重新获取每日任务以刷新UI。")
                                    // 成功后再次获取，刷新UI
                                    await self.fetchDailySessionForPlan(planId: planId, token: token)
                                } else {
                                    print("❌ PlanViewModel: 为计划 \(planId) 生成新词失败。")
                                }
                            }
                        } catch {
                            print("❌ 获取计划 \(planId) 每日任务失败: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func fetchDailySessionForPlan(planId: Int, token: String) async {
        do {
            let sessionData = try await self.networkService.getDailySession(planId: planId, token: token)
            await MainActor.run {
                self.dailySessions[planId] = sessionData
            }
        } catch {
            print("❌ 刷新计划 \(planId) 每日任务失败: \(error)")
        }
    }

    func createPlan(planRequest: PlanCreateRequest, token: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. 等待网路请求完成，并接收后端传回的、包含 ID 的新计画物件
                let newPlan = try await networkService.createPlan(planRequest: planRequest, token: token)
                
                // --- 核心修正：开始 ---
                // 2. 计画建立成功后，立即为其主动产生并上传第一天的单词
                print("✅ PlanViewModel: 计画创建成功 (ID: \(newPlan.id ?? -1))，立即为其生成新词...")
                let wordManagementService = WordManagementService()
                let success = await wordManagementService.generateAndUploadWords(for: newPlan, token: token)
                
                if success {
                    print("✅ PlanViewModel: 新计画的单词生成并上传成功。")
                } else {
                    print("❌ PlanViewModel: 为新计画生成单词时失败。")
                }
                // --- 核心修正：结束 ---

                // 3. 在所有操作完成后，再刷新整个计画列表以更新 UI
                fetchPlans(token: token)

            } catch {
                self.errorMessage = "创建计画失败: \(error.localizedDescription)"
                print("❌ Create plan error: \(error)")
            }
            isLoading = false
        }
    }

    func deletePlan(planId: Int, token: String) {
        plans.removeAll { $0.id == planId }
        
        Task {
            do {
                try await networkService.deletePlan(planId: planId, token: token)
            } catch {
                self.errorMessage = "删除失败，请重试。"
                fetchPlans(token: token)
                print("❌ Delete plan error: \(error)")
            }
        }
    }
}
