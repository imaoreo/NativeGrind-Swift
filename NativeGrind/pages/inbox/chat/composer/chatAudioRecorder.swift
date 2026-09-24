//
//  chatAudioRecorder.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import AVFoundation
import NativeGrindCore

#if !os(tvOS)
/// Records voice messages as AAC (ADTS) which is what Grindr sends as audio/aac
@MainActor
@Observable
final class chatAudioRecorder {
    static let contentType = "audio/aac"
    static let maxDuration: TimeInterval = 60

    private(set) var isRecording = false
    private(set) var startedAt: Date? = nil

    private var recorder: AVAudioRecorder? = nil
    private var fileURL: URL? = nil

    func start() async {
        guard !isRecording else { return }

        guard await requestPermission() else {
            toastManager.shared.show(style: .warn, header: "Microphone", message: "Allow microphone access in Settings to send voice messages")
            return
        }

        do {
            #if os(iOS) || os(visionOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            #endif

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).aac")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.record(forDuration: Self.maxDuration) else {
                toastManager.shared.show(style: .error, header: "Microphone", message: "Couldn't start recording")
                return
            }

            self.recorder = recorder
            self.fileURL = url
            self.startedAt = Date()
            self.isRecording = true
        } catch {
            toastManager.shared.show(style: .error, header: "Microphone", message: "Couldn't start recording")
            errorManager.shared.warn("chatAudioRecorder", "Failed to start recording: \(error.localizedDescription)")
        }
    }

    func finish() -> (data: Data, lengthMs: Int64)? {
        guard let recorder, let fileURL else { return nil }
        recorder.stop()

        let data = try? Data(contentsOf: fileURL)
        let lengthMs = Self.lengthMs(of: fileURL)
        cleanUp()

        guard let data, !data.isEmpty, lengthMs > 0 else { return nil }
        return (data, lengthMs)
    }
    
    private static func lengthMs(of url: URL) -> Int64 {
        guard let file = try? AVAudioFile(forReading: url), file.fileFormat.sampleRate > 0 else { return 0 }
        return Int64(Double(file.length) / file.fileFormat.sampleRate * 1000)
    }

    func cancel() {
        recorder?.stop()
        cleanUp()
    }

    private func cleanUp() {
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        recorder = nil
        fileURL = nil
        startedAt = nil
        isRecording = false

        #if os(iOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func requestPermission() async -> Bool {
        #if os(macOS)
        return await AVCaptureDevice.requestAccess(for: .audio)
        #else
        return await AVAudioApplication.requestRecordPermission()
        #endif
    }
}
#endif
