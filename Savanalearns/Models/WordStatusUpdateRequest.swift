//
//  WordStatusUpdateRequest.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/19.
//

// Savanalearns/Models/WordStatusUpdateRequest.swift

import Foundation

struct WordStatusUpdateRequest: Codable {
    let planId: Int
    let word: String
    let isCorrect: Bool
    let testType: String

    // This ensures the JSON keys match the back-end's snake_case format.
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case word
        case isCorrect = "is_correct"
        case testType = "test_type"
    }
}
