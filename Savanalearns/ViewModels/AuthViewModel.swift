// ViewModels/AuthViewModel.swift
import Foundation
import Combine
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var token: String?
    
    @Published var userProfile: UserProfile?
    
    @Published var plans: [Plan] = []
    @Published var dailySessions: [Int: DailySession] = [:]
    @Published var familiarWords: Set<String> = []
    private var wordManagementService = WordManagementService()

    private var networkService = NetworkService()
    private var currentTestPlanId: Int?
    private var currentTestWords: [String] = []
    
    // Add these methods to AuthViewModel class in Savanalearns/ViewModels/AuthViewModel.swift

    func generateUploadUrl(filename: String) async -> (uploadUrl: String, objectKey: String)? {
        guard let token = self.token else {
            errorMessage = "Authentication token not found."
            return nil
        }
        
        let request = GenerateUploadUrlRequest(filename: filename)
        do {
            let response = try await networkService.generateUploadUrl(request: request, token: token)
            print("✅ [AuthViewModel] Got pre-signed URL for \(response.object_key)")
            return (response.upload_url, response.object_key)
        } catch {
            print("❌ [AuthViewModel] Failed to generate upload URL: \(error)")
            errorMessage = "Could not prepare audio upload."
            return nil
        }
    }
    
    /// Step 2: Upload the audio file directly to the OSS pre-signed URL.
    func uploadAudioToOSS(fileURL: URL, uploadURL: String) async -> Bool {
        do {
            let audioData = try Data(contentsOf: fileURL)
            
            guard let url = URL(string: uploadURL) else {
                print("❌ [AuthViewModel] Invalid pre-signed URL.")
                return false
            }
            
            // --- CORE FIX: Calculate the required Content-MD5 header ---
            let digest = Insecure.MD5.hash(data: audioData)
            let base64Digest = Data(digest).base64EncodedString()
            // -----------------------------------------------------------
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
            request.setValue(base64Digest, forHTTPHeaderField: "Content-MD5")
            
            let (_, response) = try await URLSession.shared.upload(for: request, from: audioData)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("❌ [AuthViewModel] OSS upload failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
                    print("‼️ 403 Error: The Content-MD5 or Content-Type header may not match the server's signature expectations.")
                }
                return false
            }
            
            print("✅ [AuthViewModel] Audio successfully uploaded to OSS.")
            return true
            
        } catch {
            print("❌ [AuthViewModel] Exception during audio upload: \(error)")
            return false
        }
    }
    
    /// Step 3: Tell our backend to process the uploaded file from OSS.
    func recognizeSpeechTransient(objectKey: String, word: String, planId: Int) async -> String? {
        guard let token = self.token else {
            errorMessage = "Authentication token not found."
            return nil
        }
        
        let request = SubmitOssForRecognitionRequest(object_key: objectKey, word: word, plan_id: planId)
        
        do {
            let response = try await networkService.recognizeSpeechTransient(request: request, token: token)
            print("✅ [AuthViewModel] Recognition result: '\(response.recognized_text)'")
            return response.recognized_text
        } catch {
            print("❌ [AuthViewModel] Speech recognition failed: \(error)")
            errorMessage = "Failed to recognize speech."
            return nil
        }
    }
    
    // MARK: - Speech Recognition Data Models
    
    struct GenerateUploadUrlRequest: Codable {
        let filename: String
    }
    
    struct GenerateUploadUrlResponse: Codable {
        let upload_url: String
        let object_key: String
    }

    struct SubmitOssForRecognitionRequest: Codable {
        let object_key: String
        let word: String
        let plan_id: Int
    }

    struct TransientRecognitionResponse: Codable {
        let recognized_text: String
    }

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
