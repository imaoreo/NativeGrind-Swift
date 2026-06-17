import Foundation
import Combine

public enum LogLevel: String, Codable, CaseIterable {
    case log = "LOG"
    case warn = "WARN"
    case error = "ERROR"
}

public struct LogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp = Date()
    public let level: LogLevel
    public let prefix: String
    public let message: String
}

public enum MatchRule: String, Codable {
    case statusCodeOnly    
    case jsonContentOnly
    case matchBoth
    case mathchEither
}

public struct networkHandler: Codable {
    public let code: Int?
    public let jsonLocation: String?
    public let jsonLocationValue: String?
    public let message: String
    public let header: String
    public let level: LogLevel
    public let match: MatchRule
}

@MainActor
public final class ErrorManager: ObservableObject {
    public static let shared = ErrorManager()
    
    // Will be used by a dev page in the future to show all logs
    @Published public private(set) var logs: [LogEntry] = [] {
            didSet {
                if logs.count > 100 {
                    // Limits logs to 100
                    logs = Array(logs.suffix(100))
                }
            }
        }
    // This is the newest error that will be shown by ui
    @Published public var activeToast: LogEntry? = nil
    
    private init() {} // Prevents multiple instances
    
    private func createEntry(level: LogLevel, prefix: String, message: String) {
        let newEntry = LogEntry(level: level, prefix: prefix, message: message)
        self.logs.append(newEntry)
        
        // Prints out to XCode }
        let consoleString = "[\(level.rawValue)] \(prefix): \(message)"
        switch level {
            case .error: print("🔴 \(consoleString)")
            case .warn:  print("🟡 \(consoleString)")
            case .log:   print("🟢 \(consoleString)")
        }
        
        // This controls what is shown on the UI
        if level == .error {
            self.activeToast = newEntry
            ToastManager.shared.show(style: .error, header: prefix, message: message)
        }
    }
    
    // Just to make it easier when doing code
    public func log(_ prefix: String, _ message: String) {
        createEntry(level: .log, prefix: prefix, message: message)
    }
    
    public func warn(_ prefix: String, _ message: String) {
        createEntry(level: .warn, prefix: prefix, message: message)
    }
    
    public func error(_ prefix: String, _ message: String) {
        createEntry(level: .error, prefix: prefix, message: message)
    }
    
    // This will be a dev button
    public func clearLogs() {
        self.logs.removeAll()
    }
}
