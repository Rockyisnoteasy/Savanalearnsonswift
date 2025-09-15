// Models/WordEntry.swift
import Foundation
import GRDB

struct WordEntry: Identifiable, Decodable, FetchableRecord {
    var id: String { word } // 使用 word 作为唯一标识符
    var word: String
    var definition: String
    var relatedWords: String?
    var sentence: String?
    
    // 告诉 GRDB 如何将数据库列映射到我们的属性
    private enum CodingKeys: String, CodingKey {
        case word
        case definition
        case relatedWords = "related_words"
        case sentence
    }
}
