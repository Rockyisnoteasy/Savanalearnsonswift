//
//  AudioRecordingManager.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/18.
//

import Foundation
import AVFoundation
import SwiftUI

class AudioRecordingManager: NSObject, ObservableObject {
    static let shared = AudioRecordingManager()
    
    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    
    // Recording settings optimized for speech recognition
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC), // Using AAC instead of AMR
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        AVEncoderBitRateKey: 96000
    ]
    
    private override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Permission Management
    
    func checkPermission() {
        permissionStatus = recordingSession.recordPermission
        hasPermission = permissionStatus == .granted
    }
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            recordingSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    self?.permissionStatus = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() -> URL? {
        // Check permission first
        guard hasPermission else {
            print("❌ [AudioRecording] No microphone permission")
            return nil
        }
        
        // Stop any existing recording
        stopRecording()
        
        // Setup audio session
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("❌ [AudioRecording] Failed to setup audio session: \(error)")
            return nil
        }
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        currentRecordingURL = audioFilename
        
        // Start recording
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            
            // Setup max duration timer (6 seconds)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
                self?.stopRecording()
            }
            
            print("✅ [AudioRecording] Started recording to: \(audioFilename.lastPathComponent)")
            return audioFilename
            
        } catch {
            print("❌ [AudioRecording] Failed to start recording: \(error)")
            currentRecordingURL = nil
            return nil
        }
    }
    
    @discardableResult
    func stopRecording() -> URL? {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard isRecording, let recorder = audioRecorder else {
            return nil
        }
        
        let recordingDuration = Date().timeIntervalSince(recordingStartTime ?? Date())
        
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        
        // Check minimum duration (800ms)
        if recordingDuration < 0.8 {
            print("⚠️ [AudioRecording] Recording too short: \(recordingDuration)s")
            // Delete the file
            if let url = currentRecordingURL {
                try? FileManager.default.removeItem(at: url)
            }
            currentRecordingURL = nil
            return nil
        }
        
        print("✅ [AudioRecording] Stopped recording. Duration: \(recordingDuration)s")
        
        let url = currentRecordingURL
        currentRecordingURL = nil
        return url
    }
    
    // MARK: - File Management
    
    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ [AudioRecording] Deleted recording: \(url.lastPathComponent)")
        } catch {
            print("❌ [AudioRecording] Failed to delete recording: \(error)")
        }
    }
    
    func cleanupAllRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let recordings = files.filter { $0.lastPathComponent.hasPrefix("recording_") && $0.pathExtension == "m4a" }
            
            for recording in recordings {
                try FileManager.default.removeItem(at: recording)
            }
            
            print("✅ [AudioRecording] Cleaned up \(recordings.count) recordings")
        } catch {
            print("❌ [AudioRecording] Cleanup failed: \(error)")
        }
    }
    
    // MARK: - Audio File Info
    
    func getFileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    func getAudioDuration(at url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        return duration.seconds
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("❌ [AudioRecording] Recording finished unsuccessfully")
            isRecording = false
            currentRecordingURL = nil
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ [AudioRecording] Encoding error: \(error?.localizedDescription ?? "Unknown")")
        isRecording = false
        currentRecordingURL = nil
    }
}
