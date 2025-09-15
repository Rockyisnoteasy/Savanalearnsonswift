import Foundation

// 用於從後端獲取或發送到後端的學習計劃結構
// 對應 Android 專案中的 PlanResponse 和 PlanCreateRequest
struct Plan: Codable, Identifiable, Hashable {
    var id: Int? // 對應 serverId，在創建時可能為 nil
    let planName: String
    let category: String
    let selectedPlan: String
    let dailyCount: Int
    var dailyWords: [DailyWords]? // 在獲取完整計劃時才有

    // 為了與後端 JSON 的 snake_case 命名匹配
    enum CodingKeys: String, CodingKey {
        case id
        case planName = "plan_name"
        case category
        case selectedPlan = "selected_plan"
        case dailyCount = "daily_count"
        case dailyWords = "daily_words"
    }
}

// 用於表示每日單詞列表的結構
// 對應 Android 專案中的 DailyWords
struct DailyWords: Codable, Hashable {
    let wordDate: String // 日期格式為 "YYYY-MM-DD"
    let words: [String]

    enum CodingKeys: String, CodingKey {
        case wordDate = "word_date"
        case words
    }
}

// 用於創建新學習計劃時發送到後端的結構
// 對應 Android 專案中的 PlanCreateRequest
struct PlanCreateRequest: Codable {
    let planName: String
    let category: String
    let selectedPlan: String
    let dailyCount: Int

    enum CodingKeys: String, CodingKey {
        case planName = "plan_name"
        case category
        case selectedPlan = "selected_plan"
        case dailyCount = "daily_count"
    }
}

// 用於獲取學習進度的結構
// 對應 Android 專案中的 PlanProgressResponse
struct PlanProgress: Codable {
    let learnedCount: Int
    let totalCount: Int?

    enum CodingKeys: String, CodingKey {
        case learnedCount = "learned_count"
        case totalCount = "total_count"
    }
}
