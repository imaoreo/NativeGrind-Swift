//
//  wsWaiter.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 17/07/2026.
//

import Foundation
import Combine

@MainActor
final class wsWaiter<Res: Sendable> {
    private var continuation: CheckedContinuation<Res?, Never>?
    private var cancellable: AnyCancellable?
    private var timeoutTask: Task<Void, Never>?
    
    func wait(
        publisher: AnyPublisher<Res, Never>,
        timeout: TimeInterval,
        trigger: () -> Void = {}
    ) async -> Res? {
        return await withCheckedContinuation { cont in
            self.start(cont: cont, publisher: publisher, timeout: timeout)
            
            trigger()
        }
    }
    
    private func start(
        cont: CheckedContinuation<Res?, Never>,
        publisher: AnyPublisher<Res, Never>,
        timeout: TimeInterval
    ) {
        self.continuation = cont
        
        self.cancellable = publisher
            .receive(on: DispatchQueue.main)
            .first()
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.finish(with: nil)
                },
                receiveValue: { [weak self] value in
                    self?.finish(with: value)
                }
            )
        
        self.timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(with: nil)
        }
    }
    
    private func finish(with result: Res?) {
        guard let cont = continuation else { return }
        self.continuation = nil
        
        self.cancellable?.cancel()
        self.cancellable = nil
        
        self.timeoutTask?.cancel()
        self.timeoutTask = nil
        
        cont.resume(returning: result)
    }
}
