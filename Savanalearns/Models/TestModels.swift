import Foundation

// MARK: - Test Result Model (Similar to Kotlin's Quad)
struct WordTestResult: Identifiable, Codable {
    let id = UUID()
    let word: String
    let chinese: String
    let userAnswer: String
    let isCorrect: Bool
    let testType: String
    let timestamp: Date = Date()
    
    // For some tests, we might need additional data
    var additionalInfo: [String: String]? = nil
}

// MARK: - Test Question Model
struct TestQuestion {
    let word: String
    let chinese: String
    let fullDefinition: String?
    let additionalData: [String: Any]? // For audio URLs, etc.
}

// MARK: - Test Type Enum
enum TestType: String, CaseIterable, Identifiable {
    case wordToMeaningSelect = "word_to_meaning_select"      // 以词选意
    case wordMeaningMatch = "word_meaning_match"             // 词意匹配
    case meaningToWordSelect = "meaning_to_word_select"      // 以意选词
    case chineseToEnglishSelect = "chinese_to_english_select" // 选择填词
    case chineseToEnglishSpell = "chinese_to_english_spell"   // 拼写填词
    case listeningTest = "listening_test"                     // 听力填词
    case speechRecognitionTest = "speech_recognition_test"    // 读词填空
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .wordToMeaningSelect: return "以词选意"
        case .wordMeaningMatch: return "词意匹配"
        case .meaningToWordSelect: return "以意选词"
        case .chineseToEnglishSelect: return "选择填词"
        case .chineseToEnglishSpell: return "拼写填词"
        case .listeningTest: return "听力填词"
        case .speechRecognitionTest: return "读词填空"
        }
    }
}

// MARK: - Test Session Model
struct WordTestSession {
    let id = UUID()
    let planId: Int?
    let words: [String]
    let testSequence: [TestType]
    let isNewWordSession: Bool
    var currentTestIndex: Int = 0
    var results: [WordTestResult] = []
    var startTime: Date = Date()
    
    var isComplete: Bool {
        currentTestIndex >= testSequence.count
    }
    
    var currentTestType: TestType? {
        guard currentTestIndex < testSequence.count else { return nil }
        return testSequence[currentTestIndex]
    }
    
    mutating func moveToNextTest() {
        currentTestIndex += 1
    }
    
    mutating func addResult(_ result: WordTestResult) {
        results.append(result)
    }
    
    // Calculate overall performance
    var accuracy: Double {
        guard !results.isEmpty else { return 0 }
        let correct = results.filter { $0.isCorrect }.count
        return Double(correct) / Double(results.count)
    }
    
    // Get results for a specific word
    func resultsForWord(_ word: String) -> [WordTestResult] {
        results.filter { $0.word.lowercased() == word.lowercased() }
    }
}

// MARK: - Test Configuration
struct TestConfiguration {
    let numberOfQuestions: Int
    let timeLimit: TimeInterval? // Optional time limit
    let shuffleQuestions: Bool
    let showImmediateFeedback: Bool
    
    static let defaultConfig = TestConfiguration(
        numberOfQuestions: 10,
        timeLimit: nil,
        shuffleQuestions: true,
        showImmediateFeedback: false
    )
}

// MARK: - Protocol for Test Views
protocol TestViewProtocol {
    var testType: TestType { get }
    var questions: [TestQuestion] { get set }
    var onComplete: ([WordTestResult]) -> Void { get set }
    var onBack: () -> Void { get set }
}
