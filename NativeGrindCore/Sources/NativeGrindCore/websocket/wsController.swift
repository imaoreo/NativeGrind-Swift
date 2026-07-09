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
    
    public let incomingDataPublisher = PassthroughSubject<(domain: wsDomain, data: Data), Never>()
    
    @Published public private(set) var connectedDomains: Set<wsDomain> = []
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func connect(to url: URL, for domain: wsDomain) {
        guard webSocketTasks[domain] == nil else { return }
        
        let task = session.webSocketTask(with: url)
        webSocketTasks[domain] = task
        task.resume()
        
        connectedDomains.insert(domain)
        
        listen(to: domain)
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
                errorManager.shared.log("wsController","WebSocket Send Error for \(request.domain): \(error.localizedDescription)")
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
                }
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
}
