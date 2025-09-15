// Services/WordbookService.swift
import Foundation

// 定义词本的数据结构
struct Wordbook: Codable, Hashable, Identifiable {
    var id: String { dbFileName }
    let bookName: String
    let dbFileName: String
}

// 定义词本分类的数据结构
struct WordbookCategory: Codable, Hashable, Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let wordbooks: [Wordbook]
}

// 负责加载词本清单的服务
class WordbookService {
    
    // 从项目包中加载并解析 Wordbooks.json 文件
    func loadWordbookManifest() -> [WordbookCategory] {
        guard let url = Bundle.main.url(forResource: "Wordbooks", withExtension: "json") else {
            fatalError("严重错误: 项目中未找到 Wordbooks.json 文件。")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode([WordbookCategory].self, from: data)
            return manifest
        } catch {
            fatalError("严重错误: 解析 Wordbooks.json 文件失败: \(error)")
        }
    }
}
