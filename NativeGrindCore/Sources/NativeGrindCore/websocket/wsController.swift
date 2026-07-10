//
//  wsController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 09/07/2026.
//

import Foundation
import Combine

@MainActor
public final class wsController: ObservableObject {
    public static let shared = wsController()
    
    private var webSocketTasks: [wsDomain: URLSessionWebSocketTask] = [:]
    private var session: URLSession
    private var pingTimer: Task<Void, Never>?
    
    public let incomingDataPublisher = PassthroughSubject<(domain: wsDomain, data: Data), Never>()
    
    @Published public private(set) var connectedDomains: Set<wsDomain> = []
    
    public init(session: URLSession = URLSession(configuration: .default)) {
        self.session = session
    }
    
    internal var shouldResumeTasks = true
    
    public func connect(to domain: wsDomain) {
        guard let url = URL(string: domain.rawValue) else { return }
        connect(to: url, for: domain)
    }
    
    public func connect(to url: URL, for domain: wsDomain) {
        guard webSocketTasks[domain] == nil else { return }
        
        var request = URLRequest(url: url)
        
        if domain == .main {
            request.setValue("Grindr3/26.9.2.99239.060331878.99 (99239.060331878.99; iPhone99,11; iOS 26.1)", forHTTPHeaderField: "User-Agent")
            if let sessionId = keychainManager.shared.getToken(type: .sessionId) {
                request.setValue("Grindr3 \(sessionId)", forHTTPHeaderField: "Authorization")
            }
        } else if domain == .nativeServer {
            if let apiKey = keychainManager.shared.getToken(type: .apiKey) {
                request.setValue(apiKey, forHTTPHeaderField: "x-companion-api-key")
            }
        }
        
        let task = session.webSocketTask(with: request)
        webSocketTasks[domain] = task
        
        guard shouldResumeTasks else { return }
        
        task.resume()
        
        connectedDomains.insert(domain)
        
        listen(to: domain)
        startPingTimer()
    }
    
    public func disconnect(domain: wsDomain? = nil) {
        if let domain = domain {
            webSocketTasks[domain]?.cancel(with: .normalClosure, reason: nil)
            webSocketTasks.removeValue(forKey: domain)
            connectedDomains.remove(domain)
        } else {
            for task in webSocketTasks.values {
                task.cancel(with: .normalClosure, reason: nil)
            }
            webSocketTasks.removeAll()
            connectedDomains.removeAll()
        }
        
        if webSocketTasks.isEmpty {
            stopPingTimer()
        }
    }
    
    public func send<T: Codable>(request: wsRequest<T>) {
        guard let task = webSocketTasks[request.domain] else {
            errorManager.shared.log("wsController","WebSocket Error: Attempted to send to \(request.domain), but it is not connected.")
            return
        }
        
        Task {
            do {
                let data = try request.encode()
                let message = URLSessionWebSocketTask.Message.data(data)
                try await task.send(message)
            } catch {
                Task { @MainActor in
                    errorManager.shared.log("wsController","WebSocket Send Error for \(request.domain): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func listen(to domain: wsDomain) {
        guard let task = webSocketTasks[domain] else { return }
        
        task.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                Task { @MainActor in
                    self.handleMessage(message, from: domain)
                    self.listen(to: domain)
                }
                
            case .failure(let error):
                Task { @MainActor in
                    errorManager.shared.log("wsController","WebSocket Receive Error for \(domain): \(error.localizedDescription)")
                    self.disconnect(domain: domain)
                    self.scheduleReconnect(for: domain)
                }
            }
        }
    }
    
    private func scheduleReconnect(for domain: wsDomain) {
        if domain == .main {
            guard sessionManager.shared.isAuthenticated else { return }
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                guard self.connectedDomains.contains(domain) == false else { return }
                if domain == .main {
                    guard sessionManager.shared.isAuthenticated else { return }
                }
                
                errorManager.shared.log("wsController", "Attempting auto-reconnect for \(domain)...")
                self.connect(to: domain)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message, from domain: wsDomain) {
        Task { @MainActor in
            switch message {
            case .data(let data):
                self.incomingDataPublisher.send((domain: domain, data: data))
                
            case .string(let string):
                if let data = string.data(using: .utf8) {
                    self.incomingDataPublisher.send((domain: domain, data: data))
                }
                
            @unknown default:
                errorManager.shared.log("wsController","Unknown WebSocket message type received from \(domain).")
            }
        }
    }
    
    private func startPingTimer() {
        guard pingTimer == nil else { return }
        pingTimer = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard !Task.isCancelled else { break }
                
                sendPings()
            }
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.cancel()
        pingTimer = nil
    }
    
    private func sendPings() {
        for (domain, task) in webSocketTasks {
            task.sendPing { [weak self] error in
                if let error = error {
                    Task { @MainActor in
                        errorManager.shared.log("wsController", "Ping failed for \(domain): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
