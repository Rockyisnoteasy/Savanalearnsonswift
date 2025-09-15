// 文件: Savanalearns/Services/WordManagementService.swift
// 创建日期: 2025/9/13

import Foundation
import GRDB // 引入数据库操作库

class WordManagementService {
    
    private let networkService = NetworkService()
    private let wordbookService = WordbookService()
    
    // 存储已打开的数据库连接，避免重复打开文件
    private var dbQueues: [String: DatabaseQueue] = [:]

    /// 核心方法：为指定的学习计划生成并上传新词。
    /// 这对应 Kotlin 项目中的 `FileHelper.generateAndUploadNewWordsIfNeeded` 逻辑。
    /// - Returns: 一个布尔值，表示操作是否成功。
    func generateAndUploadWords(for plan: Plan, token: String) async -> Bool {
        guard let planId = plan.id else {
            print("❌ WordManagementService: 计划ID为空，无法继续。")
            return false
        }
        
        do {
            // --- 核心逻辑修正：开始 ---
            // 1. 从服务器获取全局的、该用户所有互动过的单词列表
            print("➡️ WordManagementService: 正在为用户获取全局排除列表...")
            // 不再需要传入 planId，因为是获取该用户的所有已学单词
            let exclusionList = try await networkService.getAllInteractedWords(token: token)
            // --- 核心逻辑修正：结束 ---
            
            print("✅ WordManagementService: 成功获取 \(exclusionList.count) 个需排除的单词。")

            // 2. 在本地词库中筛选出新词
            print("➡️ WordManagementService: 正在从词本 '\(plan.selectedPlan)' 中筛选新词...")
            let newWords = try await fetchNewWordsFromLocalDB(
                bookName: plan.selectedPlan,
                exclusionList: exclusionList,
                count: plan.dailyCount
            )
            
            if newWords.isEmpty {
                print("ℹ️ WordManagementService: 词本 '\(plan.selectedPlan)' 已全部学完或未找到新词。")
                // 即使没有新词，也应该认为是“成功”完成了检查流程
                return true
            }
            print("✅ WordManagementService: 成功筛选出 \(newWords.count) 个新词。")

            // 3. 上传新生成的单词列表到服务器
            print("➡️ WordManagementService: 正在上传新词到服务器...")
            try await networkService.uploadNewWords(planId: planId, words: newWords, token: token)
            print("✅ WordManagementService: 新词上传成功！")
            
            return true
            
        } catch {
            // --- 终极版详细 Log ---
            print("---------- ❌ WordManagementService 捕获到严重错误 ----------")
            
            // 1. 将通用 Error 转型为 NSError
            let nsError = error as NSError
            
            // 2. 打印基础信息
            print("错误类型 (Error Type): \(type(of: error))")
            print("完整错误物件 (Full Error Object): \(error)")
            print("本地化描述 (Localized Description): \(error.localizedDescription)")
            print("错误域 (Domain): \(nsError.domain)")
            print("错误码 (Code): \(nsError.code)")
            
            // 3. 深入挖掘 userInfo 字典，这是关键！
            print("使用者资讯 (UserInfo): \(nsError.userInfo)")
            print("---------------------------------------------------------")
            // --- Log 结束 ---
            
            return false
        }
    }
    
    /// 从指定的本地词本数据库中，随机获取指定数量且不在排除列表中的单词。
    private func fetchNewWordsFromLocalDB(bookName: String, exclusionList: [String], count: Int) async throws -> [String] {
        
        // 步骤 A: 根据词本名称找到对应的数据库文件名
        guard let dbFileNameWithExtension = findDbFileName(for: bookName) else {
            throw NSError(domain: "WordManagementService", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到词本 '\(bookName)' 对应的数据库文件配置。"])
        }
        
        let dbFileNameWithoutExtension = dbFileNameWithExtension.replacingOccurrences(of: ".db", with: "")
        
        // 步骤 B: 获取到该数据库文件的 Bundle 路径
        guard let dbPath = Bundle.main.path(forResource: dbFileNameWithoutExtension, ofType: "db") else {
            // 更新错误信息，让它显示我们实际在寻找的文件名
            throw NSError(domain: "WordManagementService", code: 404, userInfo: [NSLocalizedDescriptionKey: "在 App Bundle 中找不到数据库文件 '\(dbFileNameWithExtension)'。"])
        }
        
        
        // 步骤 C: 连接数据库并执行查询
        let dbQueue = try getDbQueue(path: dbPath)
        
        let words: [String] = try await dbQueue.read { db in
            // 当排除列表为空时，SQL 查询会因 "IN ()" 语法而失败。
            // 因此我们做一个特殊处理：如果列表为空，就直接查询，不过滤。
            if exclusionList.isEmpty {
                let sql = """
                    SELECT word FROM plan_words
                    ORDER BY RANDOM()
                    LIMIT \(count)
                """
                return try String.fetchAll(db, sql: sql)
            } else {
                // 使用参数化查询，防止 SQL 注入，也更高效
                var sql = """
                    SELECT word FROM plan_words
                    WHERE word NOT IN (
                """
                // 创建占位符 (?, ?, ?)
                sql += Array(repeating: "?", count: exclusionList.count).joined(separator: ",")
                sql += """
                    )
                    ORDER BY RANDOM()
                    LIMIT \(count)
                """
                
                let arguments = StatementArguments(exclusionList)
                return try String.fetchAll(db, sql: sql, arguments: arguments)
            }
        }
        return words
    }

    /// 根据词本名称从 `Wordbooks.json` 清单中查找数据库文件名。
    private func findDbFileName(for bookName: String) -> String? {
        let manifest = wordbookService.loadWordbookManifest()
        for category in manifest {
            if let wordbook = category.wordbooks.first(where: { $0.bookName == bookName }) {
                // 返回文件名，不带 .db 后缀
                return wordbook.dbFileName
            }
        }
        return nil
    }
    
    /// 获取一个 GRDB 数据库连接实例。
    /// 为了性能，会缓存已经打开的连接。
    private func getDbQueue(path: String) throws -> DatabaseQueue {
        if let existingQueue = dbQueues[path] {
            return existingQueue
        }
        let newQueue = try DatabaseQueue(path: path)
        dbQueues[path] = newQueue
        return newQueue
    }
}
