// ViewModels/AuthViewModel.swift
import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var token: String?
    
    @Published var userProfile: UserProfile?
    
    @Published var plans: [Plan] = []
    @Published var dailySessions: [Int: DailySession] = [:]
    private var wordManagementService = WordManagementService()

    private var networkService = NetworkService()

    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await networkService.login(email: email, password: password)
                self.token = response.accessToken
                
                // 登录成功后，我们需要去获取用户信息
                // (这部分逻辑我们后面再加，先保证编译通过)

                self.isLoggedIn = true
            } catch {
                self.errorMessage = "登录失败，请检查邮箱或密码。"
                print("Login error: \(error)")
            }
            self.isLoading = false
        }
    }

    func register(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await networkService.register(email: email, password: password)
                login(email: email, password: password)
            } catch {
                self.errorMessage = "注册失败，该邮箱可能已被使用。"
                self.isLoading = false
                print("Register error: \(error)")
            }
        }
    }
    
    func fetchDailySession(for planId: Int) {
        guard let token = self.token else {
            print("AuthViewModel: Missing token, cannot fetch daily session.")
            return
        }

        print("➡️ [AuthViewModel] Fetching daily session for planId: \(planId)...")
        
        // 使用 Task 来执行异步代码
        Task {
            do {
                // 1. 使用 networkService 实例 (而不是 NetworkService.shared)
                // 2. 使用 try await 来调用 async 函数
                let session = try await networkService.getDailySession(planId: planId, token: token)
                
                // 因为 AuthViewModel 已经标记为 @MainActor，所以这里可以直接更新属性，
                // Swift 会确保它在主线程上执行。
                self.dailySessions[planId] = session
                print("✅ [AuthViewModel] Success for planId \(planId). New: \(session.newWords.count), Review: \(session.reviewWords.count)")

                // --- 参照 Kotlin HomeScreen 的关键触发逻辑 ---
                let shouldGenerate = session.newWords.isEmpty && !session.isNewWordPaused
                if shouldGenerate {
                    print("⚠️ [AuthViewModel] Plan \(planId) has no new words. Triggering generation...")
                    if let plan = self.plans.first(where: { $0.id == planId }) {
                        // 在后台执行生成和上传
                        let success = await wordManagementService.generateAndUploadWords(for: plan, token: token)
                        if success {
                            print("✅ [AuthViewModel] Generation and upload complete. Re-fetching session for plan \(planId).")
                            // 成功后再次获取，以刷新UI
                            self.fetchDailySession(for: planId)
                        } else {
                            print("❌ [AuthViewModel] Failed to generate and upload words for plan \(planId).")
                        }
                    }
                }
                
            } catch {
                // 捕获异步函数抛出的错误
                print("❌ [AuthViewModel] Failed to fetch daily session for planId \(planId): \(error.localizedDescription)")
            }
        }
    }
    
    func startSession(plan: Plan, words: [String]) {
        currentTestPlanId = plan.id
        currentTestWords = words
        print("🚀 [AuthViewModel] Session started for planId: \(plan.id) with \(words.count) words.")
    }
    
    /// Process a test answer for a single word
    /// This updates the word status on the backend
    func processTestAnswer(word: String, isCorrect: Bool, testType: String) {
        guard let planId = currentTestPlanId else {
            print("❌ [AuthViewModel] Error: currentTestPlanId is null. Cannot process answer.")
            return
        }
        
        Task {
            guard let token = self.token else {
                print("❌ [AuthViewModel] Token is null. Cannot process answer.")
                return
            }
            
            print("⬆️ [AuthViewModel] Submitting answer for '\(word)'. Correct: \(isCorrect), Test: '\(testType)'")
            
            do {
                // Call your network service to update word status
                // This would be similar to the Kotlin updateWordStatus call
                try await networkService.updateWordStatus(
                    planId: planId,
                    word: word,
                    isCorrect: isCorrect,
                    testType: testType,
                    token: token
                )
                
                print("✅ [AuthViewModel] Successfully updated status for '\(word)'")
                
                // Optionally refresh the session or progress
                fetchDailySession(for: planId)
                
            } catch {
                print("❌ [AuthViewModel] Failed to update word status for '\(word)': \(error)")
            }
        }
    }
    
    /// Mark a word as familiar (used in FlipCard long press)
    func markWordAsFamiliar(_ word: String) {
        familiarWords.insert(word.lowercased())
        
        // Also update on backend if there's an active session
        if let planId = currentTestPlanId {
            processTestAnswer(word: word, isCorrect: true, testType: "familiar")
        }
    }
    
    /// Clear the current session
    func endSession() {
        currentTestPlanId = nil
        currentTestWords = []
        print("🏁 [AuthViewModel] Session ended.")
    }
}
