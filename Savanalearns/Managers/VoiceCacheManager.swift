//
//  VoiceCacheManager.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/17.
//

import Foundation
import CryptoKit

class VoiceCacheManager {
    static let shared = VoiceCacheManager()
    
    private let cacheDirectory: URL
    private let sentenceCacheDirectory: URL
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheDirectory = documentsPath.appendingPathComponent("voice_cache")
        self.sentenceCacheDirectory = documentsPath.appendingPathComponent("sentence_voice")
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: sentenceCacheDirectory, withIntermediateDirectories: true)
    }
    
    // Get or download word audio
    func getOrDownloadWordAudio(_ word: String, completion: @escaping (URL?) -> Void) {
        let fileName = "\(md5(word)).mp3"
        let localFileURL = cacheDirectory.appendingPathComponent(fileName)
        
        // Check if file exists locally
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            print("Cached audio for: \(word)")
            completion(localFileURL)
            return
        }
        
        // Download from server
        let urlString = "https://wordsentencevoice.savanalearns.cc/voice_cache/\(fileName)"
        print("Downloading audio from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Failed to download audio: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            // Save to cache
            do {
                try data.write(to: localFileURL)
                print("✅ Downloaded and cached audio for: \(word)")
                completion(localFileURL)
            } catch {
                print("❌ Failed to save audio: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    // Get or download sentence audio
    func getOrDownloadSentenceAudio(_ sentence: String, completion: @escaping (URL?) -> Void) {
        let fileName = "\(md5(sentence)).mp3"
        let localFileURL = sentenceCacheDirectory.appendingPathComponent(fileName)
        
        // Check if file exists locally
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            print("Cached sentence audio")
            completion(localFileURL)
            return
        }
        
        // Download from server
        let urlString = "https://wordsentencevoice.savanalearns.cc/sentence_voice/\(fileName)"
        print("Downloading sentence audio from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Failed to download sentence audio: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            // Save to cache
            do {
                try data.write(to: localFileURL)
                print("✅ Downloaded and cached sentence audio")
                completion(localFileURL)
            } catch {
                print("❌ Failed to save sentence audio: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    // MD5 hash function
    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
