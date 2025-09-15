// Savanalearns/Services/DatabaseService.swift

import Foundation
// 1. 导入 GRDB
import GRDB

class DatabaseService {
    // 2. 将 'dbPath' 和 'dbQueue' 设为实例变量
    private var dbQueue: DatabaseQueue
    
    // 单例模式
    static let shared = DatabaseService()
    
    // 3. 将初始化逻辑放入构造函数中
    private init() {
        do {
            guard let dbPath = Bundle.main.path(forResource: "dictionary", ofType: "db") else {
                fatalError("dictionary.db not found in app bundle's Resources.")
            }
            
            dbQueue = try DatabaseQueue(path: dbPath)
            
            print("✅ DatabaseService: Successfully connected to dictionary.db at path: \(dbPath)")
            
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }
    
    // 4. 添加核心功能函数：加载所有词条到内存
    /// 从数据库加载所有单词条目到内存中
    /// - Returns: 一个以单词小写形式为键，WordEntry为值的字典
    func loadAllWordEntries() -> [String: WordEntry] {
        var wordMap: [String: WordEntry] = [:]
        do {
            try dbQueue.read { db in
                // 使用 SQL 查询来匹配 WordEntry 结构体
                let entries = try WordEntry.fetchAll(db, sql: "SELECT word, definition, related_words, sentence FROM dictionary")
                for entry in entries {
                    wordMap[entry.word.lowercased()] = entry
                }
            }
            print("✅ DatabaseService: Loaded \(wordMap.count) entries into memory.")
        } catch {
            print("❌ DatabaseService: Failed to load word entries: \(error)")
        }
        return wordMap
    }
}
