// Services/NetworkService.swift
import Foundation

class NetworkService {
    private let baseURL = URL(string: "https://api.savanalearns.cc/")!
    private let decoder = JSONDecoder() // 建议创建一个共用的解码器

    // 登录方法 (已有)
    func login(email: String, password: String) async throws -> TokenResponse {
        let url = baseURL.appendingPathComponent("login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyString = "username=\(email)&password=\(password)"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // 尝试解析后端返回的错误信息
            if let data = try? JSONDecoder().decode([String: String].self, from: data), let detail = data["detail"] {
                throw NSError(domain: "NetworkService", code: (response as? HTTPURLResponse)?.statusCode ?? 400, userInfo: [NSLocalizedDescriptionKey: detail])
            }
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(TokenResponse.self, from: data)
    }
    
    func generateUploadUrl(request: AuthViewModel.GenerateUploadUrlRequest, token: String) async throws -> AuthViewModel.GenerateUploadUrlResponse {
        let url = baseURL.appendingPathComponent("learning/generate-upload-url")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode(AuthViewModel.GenerateUploadUrlResponse.self, from: data)
    }

    func recognizeSpeechTransient(request: AuthViewModel.SubmitOssForRecognitionRequest, token: String) async throws -> AuthViewModel.TransientRecognitionResponse {
        let url = baseURL.appendingPathComponent("learning/recognize-speech-transient")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode(AuthViewModel.TransientRecognitionResponse.self, from: data)
    }

    // 注册方法 (已有)
    func register(email: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(RegisterRequest(email: email, password: password))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
             throw URLError(.badServerResponse)
        }
    }
    
    // --- 新增代码：学习计划相关接口 ---

    /// 获取用户的所有学习计划
    func getPlans(token: String) async throws -> [Plan] {
        let url = baseURL.appendingPathComponent("plans")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode([Plan].self, from: data)
    }

    /// 创建一个新的学习计划
    func createPlan(planRequest: PlanCreateRequest, token: String) async throws -> Plan {
        let url = baseURL.appendingPathComponent("plans")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(planRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(Plan.self, from: data)
    }
    
    /// 删除一个学习计划
    func deletePlan(planId: Int, token: String) async throws {
        let url = baseURL.appendingPathComponent("plans/\(planId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// 获取指定学习计划的进度
    func getPlanProgress(planId: Int, token: String) async throws -> PlanProgress {
        let url = baseURL.appendingPathComponent("learning/plan/\(planId)/progress")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode(PlanProgress.self, from: data)
    }
    
    func getDailySession(planId: Int, token: String) async throws -> DailySession {
        // 注意URL中的查询参数 ?plan_id=...
        let url = baseURL.appendingPathComponent("learning/daily-session")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "plan_id", value: "\(planId)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode(DailySession.self, from: data)
    }
    
    func getAllInteractedWords(token: String) async throws -> [String] {
        print("➡️ [NetworkService] getAllInteractedWords: 准备获取全局排除列表...")
        let url = baseURL.appendingPathComponent("learning/all-interacted-words")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = String(data: data, encoding: .utf8) ?? "无法解码服务器回应"
            print("❌ [NetworkService] getAllInteractedWords 失败: HTTP \(statusCode), Body: \(errorBody)")
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode([String].self, from: data)
    }
    
    /// 上传新生成的每日单词列表到服务器
    func uploadNewWords(planId: Int, words: [String], token: String) async throws {
        // 这个结构体用于匹配服务器 DailyWords 的结构
        struct DailyWordsUpload: Codable {
            let word_date: String
            let words: [String]
        }
        
        // 获取当前日期并格式化为 "YYYY-MM-DD"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        let payload = DailyWordsUpload(word_date: dateString, words: words)
        
        let url = baseURL.appendingPathComponent("plans/\(planId)/daily_words")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        // --- 核心修正：同时处理成功和失败情况的 data 和 response ---
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // 捕获底层的网络错误 (例如无网络连接)
            print("❌ [NetworkService] uploadNewWords: 网络请求本身失败: \(error)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // --- 核心修正：同时接受 200 和 201 作为成功的状态码 ---
        let isSuccessful = httpResponse.statusCode == 200 || httpResponse.statusCode == 201
        
        guard isSuccessful else {
            // 现在 data 在这个作用域内是可见的
            let errorBody = String(data: data, encoding: .utf8) ?? "无法解码服务器的回应内容。"
            print("---------- ❌ NetworkService 详细错误报告 (uploadNewWords) ----------")
            print("接口 (Endpoint): \(url)")
            print("HTTP 状态码 (Status Code): \(httpResponse.statusCode)")
            print("服务器原始回应 (Server Response Body): \(errorBody)")
            print("-----------------------------------------------------------------")
            throw URLError(.badServerResponse)
        }
        
        print("✅ [NetworkService] uploadNewWords: 新词上传成功 (HTTP \(httpResponse.statusCode))")
    }
    
    func updateWordStatus(planId: Int, word: String, isCorrect: Bool, testType: String, token: String) async throws {
        struct WordStatusUpdateRequest: Codable {
            let plan_id: Int
            let word: String
            let is_correct: Bool
            let test_type: String
        }
        
        let payload = WordStatusUpdateRequest(
            plan_id: planId,
            word: word,
            is_correct: isCorrect,
            test_type: testType
        )
        
        let url = baseURL.appendingPathComponent("word_status")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "无法解码服务器回应"
            print("❌ [NetworkService] updateWordStatus failed: \(errorBody)")
            throw URLError(.badServerResponse)
        }
        
        print("✅ [NetworkService] Word status updated successfully")
    }
    
}
