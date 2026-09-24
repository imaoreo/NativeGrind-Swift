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
    public static var isAppAttestSupported = false
    
    private var webSocketTasks: [wsDomain: URLSessionWebSocketTask] = [:]
    private var session: URLSession
    private var pingTimer: Task<Void, Never>?
    private var desiredDomains: Set<wsDomain> = []
    
    public var pendingKeyId: String?
    
    private let incomingDataSubject = PassthroughSubject<(domain: wsDomain, data: Data), Never>()
    
    public var incomingDataPublisher: AnyPublisher<(domain: wsDomain, data: Data), Never> {
        incomingDataSubject.eraseToAnyPublisher()
    }
    
    @Published public private(set) var connectedDomains: Set<wsDomain> = []
    @Published public var isServerAuthorized: Bool = false
    
    public init(session: URLSession = URLSession(configuration: .default)) {
        self.session = session
    }
    
    internal var shouldResumeTasks = true
    
    public func connect(to domain: wsDomain) {
        guard let url = URL(string: domain.rawValue) else { return }
        connect(to: url, for: domain)
    }
    
    internal func connect(to url: URL, for domain: wsDomain) {
        desiredDomains.insert(domain)
        guard webSocketTasks[domain] == nil else { return }
        
        var request = URLRequest(url: url)
        
        if domain == .main {
            request.setValue("Grindr3/26.9.2.99239.060331878.99 (99239.060331878.99; iPhone99,11; iOS 26.1)", forHTTPHeaderField: "User-Agent")
            if let sessionId = keychainManager.shared.getToken(type: .sessionId) {
                request.setValue("Grindr3 \(sessionId)", forHTTPHeaderField: "Authorization")
            }
        } else if domain == .nativeServer {
            var currentDeviceId = keychainManager.shared.getToken(type: .deviceId)
            
            if currentDeviceId == nil {
                do {
                    let _ = try cryptoController.shared.generateAndStoreKeyPair()
                    
                    let newDeviceId = UUID().uuidString
                    keychainManager.shared.saveToken(newDeviceId, type: .deviceId)
                    
                    currentDeviceId = newDeviceId
                } catch {
                    errorManager.shared.error("wsController", "Failed to generate hardware keys - \(error)")
                }
            }
        }
        
        let task = session.webSocketTask(with: request)
        webSocketTasks[domain] = task
        
        guard shouldResumeTasks else { return }
        
        task.resume()
        
        connectedDomains.insert(domain)
        
        listen(to: domain)
    }
    
    public func disconnect(domain: wsDomain? = nil, userInitiated: Bool = true) {
        if let domain = domain {
            if userInitiated {
                desiredDomains.remove(domain)
            }
            webSocketTasks[domain]?.cancel(with: .normalClosure, reason: nil)
            webSocketTasks.removeValue(forKey: domain)
            connectedDomains.remove(domain)
            if domain == .nativeServer {
                isServerAuthorized = false
            }
        } else {
            if userInitiated {
                desiredDomains.removeAll()
            }
            for task in webSocketTasks.values {
                task.cancel(with: .normalClosure, reason: nil)
            }
            webSocketTasks.removeAll()
            connectedDomains.removeAll()
            isServerAuthorized = false
        }
    }
    
    public func send<T: Codable>(request: wsRequest<T>) {
        let domain = request.domain
        let isNewConnection = (webSocketTasks[domain] == nil)
        
        if isNewConnection {
            connect(to: domain)
        }
        
        Task {
            if isNewConnection {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            guard let task = await MainActor.run(body: { self.webSocketTasks[domain] }) else { return }
            
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
                    let closeCode = task.closeCode.rawValue
                    errorManager.shared.log("wsController", "WebSocket closed with code \(closeCode) for \(domain): \(error.localizedDescription)")
                    
                    if domain == .main && (closeCode == 4401 || closeCode == 57013) {
                        errorManager.shared.log("wsController", "Session token expired (code: \(closeCode)). Refreshing session...")
                        await sessionManager.shared.refreshToken(showError: false)
                    }
                    
                    self.disconnect(domain: domain, userInitiated: false)
                    self.scheduleReconnect(for: domain)
                }
            }
        }
    }
    
    private func scheduleReconnect(for domain: wsDomain) {
        guard desiredDomains.contains(domain) else { return }
        if domain == .main {
            guard sessionManager.shared.isAuthenticated else { return }
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                guard self.desiredDomains.contains(domain) else { return }
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
                self.incomingDataSubject.send((domain: domain, data: data))
                
            case .string(let string):
                if let data = string.data(using: .utf8) {
                    self.incomingDataSubject.send((domain: domain, data: data))
                }
                
            @unknown default:
                errorManager.shared.log("wsController","Unknown WebSocket message type received from \(domain).")
            }
        }
    }
    
    public func setConnected(domain: wsDomain, connected: Bool) {
        if connected {
            connectedDomains.insert(domain)
        } else {
            connectedDomains.remove(domain)
        }
    }
    
    public func publisher<T: Decodable>(for event: wsEvent<T>) -> AnyPublisher<T, Never> {
        let decoder = JSONDecoder()
        return incomingDataPublisher
            .filter { $0.domain == event.domain }
            .compactMap { tuple -> T? in
                if event.domain == .main {
                    guard let raw = try? decoder.decode(wsRawNotificationEnvelope.self, from: tuple.data),
                          raw.type == event.eventName else {
                        return nil
                    }

                    let decoded = try? decoder.decode(wsNotificationEnvelope<T>.self, from: tuple.data)
                    return decoded?.payload
                } else {
                    guard let raw = try? decoder.decode(wsRawNSNotificationEnvelope.self, from: tuple.data),
                        raw.event == event.eventName else {
                        return nil
                    }
                    let decoded = try? decoder.decode(wsNSNotificationEnvelope<T>.self, from: tuple.data)
                    return decoded?.payload
                }
            }
            .eraseToAnyPublisher()
    }

    public func sendAndWait<Req: Codable & Sendable, Res: Decodable & Sendable>(
        request: wsRequest<Req>,
        expectedEvent: wsEvent<Res>,
        timeout: TimeInterval = 10.0
    ) async -> Res? {
        
        let waiter = wsWaiter<Res>()
        let pub = publisher(for: expectedEvent)
        
        let result = await waiter.wait(publisher: pub, timeout: timeout) {
            self.send(request: request)
        }
        
        if result == nil {
            errorManager.shared.log("wsController", "WebSocket request timed out for \(request.domain). Reconnecting...")
            self.disconnect(domain: request.domain, userInitiated: false)
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.connect(to: request.domain)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            let retryWaiter = wsWaiter<Res>()
            let retryPub = publisher(for: expectedEvent)
            return await retryWaiter.wait(publisher: retryPub, timeout: timeout) {
                self.send(request: request)
            }
        }
        
        return result
    }

    #if DEBUG
    internal func simulateIncomingMessage(domain: wsDomain, data: Data) {
        incomingDataSubject.send((domain: domain, data: data))
    }
    #endif
}

