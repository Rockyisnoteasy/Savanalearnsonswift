import AVFoundation
import Foundation
import CryptoKit

class AudioManager: NSObject {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    private var currentCompletion: (() -> Void)?
    
    private override init() {
        super.init()
        setupAudioSession()
        
        // Register for audio interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Try different category options for maximum compatibility
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]
            )
            
            // Activate the session
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Check current route
            let currentRoute = session.currentRoute
            print("✅ Audio session configured")
            print("   Output: \(currentRoute.outputs.first?.portName ?? "Unknown")")
            print("   Sample Rate: \(session.sampleRate)")
            print("   Output Volume: \(session.outputVolume)")
            
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            print("⚠️ Audio interruption began")
        } else if type == .ended {
            print("⚠️ Audio interruption ended")
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
    
    // Play audio from URL with completion handler
    func playAudio(from url: URL, completion: (() -> Void)? = nil) {
        print("\n🎵 Attempting to play audio from: \(url.lastPathComponent)")
        
        // Verify file exists and get its size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            print("   File size: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ Audio file is empty!")
                completion?()
                return
            }
        } catch {
            print("❌ Cannot read file attributes: \(error)")
            completion?()
            return
        }
        
        // Make sure audio session is active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to activate audio session: \(error)")
        }
        
        do {
            // Try to create the audio player directly from URL first
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            
            // Store completion handler
            currentCompletion = completion
            
            // Get audio properties
            print("   Duration: \(audioPlayer?.duration ?? 0) seconds")
            print("   Channels: \(audioPlayer?.numberOfChannels ?? 0)")
            print("   Format: \(audioPlayer?.format.description ?? "Unknown")")
            
            // Try to play
            let didPlay = audioPlayer?.play() ?? false
            
            if didPlay {
                print("✅ Audio playback started successfully")
                print("   Is playing: \(audioPlayer?.isPlaying ?? false)")
                print("   Current time: \(audioPlayer?.currentTime ?? 0)")
            } else {
                print("❌ Failed to start audio playback")
                completion?()
            }
            
        } catch {
            print("❌ AVAudioPlayer error: \(error)")
            print("   Error details: \(error.localizedDescription)")
            
            // Try alternative method with data
            do {
                let audioData = try Data(contentsOf: url)
                print("   Loaded \(audioData.count) bytes of audio data")
                
                audioPlayer = try AVAudioPlayer(data: audioData)
                audioPlayer?.delegate = self
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                currentCompletion = completion
                
                if audioPlayer?.play() == true {
                    print("✅ Audio playback started with data method")
                } else {
                    print("❌ Failed to play with data method")
                    completion?()
                }
            } catch {
                print("❌ Failed with data method too: \(error)")
                completion?()
            }
        }
    }
    
    // Test audio system with a simple beep
    func testAudioSystem() {
        print("\n🔊 Testing audio system...")
        
        // Create a simple sine wave tone
        let sampleRate = 44100.0
        let frequency = 440.0 // A4 note
        let duration = 0.5
        let amplitude: Float = 0.5
        
        var audioData = Data()
        
        // Generate sine wave
        for i in 0..<Int(sampleRate * duration) {
            let sample = amplitude * sinf(Float(2.0 * Double.pi * frequency * Double(i) / sampleRate))
            var sampleBytes = sample
            audioData.append(Data(bytes: &sampleBytes, count: MemoryLayout<Float>.size))
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.play()
            print("✅ Test tone should be playing")
        } catch {
            print("❌ Cannot play test tone: \(error)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ Audio finished playing (success: \(flag))")
        currentCompletion?()
        currentCompletion = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        currentCompletion?()
        currentCompletion = nil
    }
}
