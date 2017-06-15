//
//  StateMachine.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/01/21.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

///
/// fast, naive event-handler-manager in replace of ReactKit/SwiftState (dynamic but slow),
/// introduced from SwiftTask 2.6.0
///
/// see also: https://github.com/ReactKit/SwiftTask/pull/22
///
class StateMachine<Progress, Value, Error> {
    typealias ErrorInfo = Task<Progress, Value, Error>.ErrorInfo
    typealias ProgressTupleHandler = Task<Progress, Value, Error>.ProgressTupleHandler
    
    /// wrapper closure for `initClosure` to invoke only once when started `.running`,
    /// and will be set to `nil` afterward
    var initResumeClosure: Atomic<(() -> Void)?> = Atomic(nil)
    
    let weakified: Bool
    let state: Atomic<TaskState>
    let progress: Atomic<Progress?> = Atomic(nil)    // NOTE: always nil if `weakified = true`
    let value: Atomic<Value?> = Atomic(nil)
    let errorInfo: Atomic<ErrorInfo?> = Atomic(nil)
    let configuration = TaskConfiguration()
    
    private var lock = RecursiveLock()
    
    private lazy var progressTupleHandlers = Handlers<ProgressTupleHandler>()
    private lazy var completionHandlers = Handlers<() -> Void>()
    
    init(weakified: Bool, paused: Bool) {
        self.weakified = weakified
        state = Atomic(paused ? .paused : .running)
    }
    
    @discardableResult func addProgressTupleHandler(_ token: inout HandlerToken?, _ progressTupleHandler: @escaping ProgressTupleHandler) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard state.rawValue == .running || state.rawValue == .paused else { return false }
        token = progressTupleHandlers.append(progressTupleHandler)
        return token != nil
    }
    
    @discardableResult func removeProgressTupleHandler(_ handlerToken: HandlerToken?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let handlerToken = handlerToken else { return false }
        let removedHandler = progressTupleHandlers.remove(handlerToken)
        return removedHandler != nil
    }
    
    @discardableResult func addCompletionHandler(_ token: inout HandlerToken?, _ completionHandler: @escaping () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard state.rawValue == .running || state.rawValue == .paused else { return false }
        token = completionHandlers.append(completionHandler)
        return token != nil
    }
    
    @discardableResult func removeCompletionHandler(_ handlerToken: HandlerToken?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let handlerToken = handlerToken else { return false }
        let removedHandler = completionHandlers.remove(handlerToken)
        return removedHandler != nil
    }
    
    func handleProgress(_ progress: Progress) {
        lock.lock()
        defer { lock.unlock() }
        
        guard state.rawValue == .running else { return }
        let oldProgress = self.progress.rawValue
        
        // NOTE: if `weakified = false`, don't store progressValue for less memory footprint
        if !weakified {
            self.progress.rawValue = progress
        }
        
        for handler in progressTupleHandlers {
            handler((oldProgress: oldProgress, newProgress: progress))
        }
    }
    
    func handleFulfill(_ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        
        let newState = state.updateIf { $0 == .running ? .fulfilled : nil }
        
        guard newState != nil else { return }
        self.value.rawValue = value
        finish()
    }
    
    func handleRejectInfo(_ errorInfo: ErrorInfo) {
        lock.lock()
        defer { lock.unlock() }
        
        let toState = errorInfo.isCancelled ? TaskState.cancelled : .rejected
        let newState = state.updateIf { $0 == .running || $0 == .paused ? toState : nil }
        
        guard newState != nil else { return }
        self.errorInfo.rawValue = errorInfo
        finish()
    }
    
    func handlePause() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let newState = state.updateIf { $0 == .running ? .paused : nil }
        
        guard newState != nil else { return false }
        configuration.pause?()
        return true
    }
    
    func handleResume() -> Bool {
        lock.lock()
        
        if let initResumeClosure = initResumeClosure.update({ _ in nil }) {
            state.rawValue = .running
            lock.unlock()
            
            initResumeClosure()
            return true
        } else {
            let resumed: Bool
            let newState = state.updateIf { $0 == .paused ? .running : nil }
            
            if newState != nil {
                configuration.resume?()
                resumed = true
            } else {
                resumed = false
            }
            
            lock.unlock()
            return resumed
        }
    }
    
    func handleCancel(_ error: Error? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let newState = state.updateIf { $0 == .running || $0 == .paused ? .cancelled : nil }
        
        guard newState != nil else { return false }
        errorInfo.rawValue = ErrorInfo(error: error, isCancelled: true)
        finish()
        return true
    }
}

private extension StateMachine {
    func finish() {
        completionHandlers.forEach { $0() }
        progressTupleHandlers.removeAll()
        completionHandlers.removeAll()
        
        configuration.finish()
        
        initResumeClosure.rawValue = nil
        progress.rawValue = nil
    }
}

