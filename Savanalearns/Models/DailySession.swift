// Models/DailySession.swift
import Foundation

// 对应后端的 DailySessionResponse
struct DailySession: Codable {
    let newWords: [String]
    let reviewWords: [String]
    let isNewWordPaused: Bool
    let isBacklogSession: Bool

    enum CodingKeys: String, CodingKey {
        case newWords = "new_words"
        case reviewWords = "review_words"
        case isNewWordPaused = "is_new_word_paused"
        case isBacklogSession = "is_backlog_session"
    }
}
