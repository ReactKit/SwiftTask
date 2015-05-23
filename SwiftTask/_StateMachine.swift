//
//  _StateMachine.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/01/21.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation

///
/// fast, naive event-handler-manager in replace of ReactKit/SwiftState (dynamic but slow),
/// introduced from SwiftTask 2.6.0
///
/// see also: https://github.com/ReactKit/SwiftTask/pull/22
///
internal class _StateMachine<Progress, Value, Error>
{
    internal typealias ErrorInfo = Task<Progress, Value, Error>.ErrorInfo
    internal typealias ProgressTupleHandler = Task<Progress, Value, Error>._ProgressTupleHandler
    
    internal let weakified: Bool
    internal let state: _Atomic<TaskState>
    
    internal let progress: _Atomic<Progress?> = _Atomic(nil)    // NOTE: always nil if `weakified = true`
    internal let value: _Atomic<Value?> = _Atomic(nil)
    internal let errorInfo: _Atomic<ErrorInfo?> = _Atomic(nil)
    
    internal let configuration = TaskConfiguration()
    
    /// wrapper closure for `_initClosure` to invoke only once when started `.Running`,
    /// and will be set to `nil` afterward
    internal var initResumeClosure: _Atomic<(Void -> Void)?> = _Atomic(nil)
    
    private lazy var _progressTupleHandlers = _Handlers<ProgressTupleHandler>()
    private lazy var _completionHandlers = _Handlers<Void -> Void>()
    
    private var _lock = _RecursiveLock()
    
    internal init(weakified: Bool, paused: Bool)
    {
        self.weakified = weakified
        self.state = _Atomic(paused ? .Paused : .Running)
    }
    
    internal func addProgressTupleHandler(inout token: _HandlerToken?, _ progressTupleHandler: ProgressTupleHandler) -> Bool
    {
        self._lock.lock()
        if self.state.rawValue == .Running || self.state.rawValue == .Paused {
            token = self._progressTupleHandlers.append(progressTupleHandler)
            self._lock.unlock()
            return token != nil
        }
        else {
            self._lock.unlock()
            return false
        }
    }
    
    internal func removeProgressTupleHandler(handlerToken: _HandlerToken?) -> Bool
    {
        self._lock.lock()
        if let handlerToken = handlerToken {
            let removedHandler = self._progressTupleHandlers.remove(handlerToken)
            self._lock.unlock()
            return removedHandler != nil
        }
        else {
            self._lock.unlock()
            return false
        }
    }
    
    internal func addCompletionHandler(inout token: _HandlerToken?, _ completionHandler: Void -> Void) -> Bool
    {
        self._lock.lock()
        if self.state.rawValue == .Running || self.state.rawValue == .Paused {
            token = self._completionHandlers.append(completionHandler)
            self._lock.unlock()
            return token != nil
        }
        else {
            self._lock.unlock()
            return false
        }
    }
    
    internal func removeCompletionHandler(handlerToken: _HandlerToken?) -> Bool
    {
        self._lock.lock()
        if let handlerToken = handlerToken {
            let removedHandler = self._completionHandlers.remove(handlerToken)
            self._lock.unlock()
            return removedHandler != nil
        }
        else {
            self._lock.unlock()
            return false
        }
    }
    
    internal func handleProgress(progress: Progress)
    {
        self._lock.lock()
        if self.state.rawValue == .Running {
            
            let oldProgress = self.progress.rawValue
            
            // NOTE: if `weakified = false`, don't store progressValue for less memory footprint
            if !self.weakified {
                self.progress.rawValue = progress
            }
            
            for handler in self._progressTupleHandlers {
                handler(oldProgress: oldProgress, newProgress: progress)
            }
            self._lock.unlock()
        }
        else {
            self._lock.unlock()
        }
    }
    
    internal func handleFulfill(value: Value)
    {
        self._lock.lock()
        let (_, updated) = self.state.tryUpdate { $0 == .Running ? (.Fulfilled, true) : ($0, false) }
        if updated {
            self.value.rawValue = value
            self._finish()
            self._lock.unlock()
        }
        else {
            self._lock.unlock()
        }
    }
    
    internal func handleRejectInfo(errorInfo: ErrorInfo)
    {
        self._lock.lock()
        let toState = errorInfo.isCancelled ? TaskState.Cancelled : .Rejected
        let (_, updated) = self.state.tryUpdate { $0 == .Running || $0 == .Paused ? (toState, true) : ($0, false) }
        if updated {
            self.errorInfo.rawValue = errorInfo
            self._finish()
            self._lock.unlock()
        }
        else {
            self._lock.unlock()
        }
    }
    
    internal func handlePause() -> Bool
    {
        self._lock.lock()
        let (_, updated) = self.state.tryUpdate { $0 == .Running ? (.Paused, true) : ($0, false) }
        if updated {
            self.configuration.pause?()
            self._lock.unlock()
            return true
        }
        else {
            self._lock.unlock()
            return false
        }
    }
    
    internal func handleResume() -> Bool
    {
        self._lock.lock()
        if let initResumeClosure = self.initResumeClosure.update({ _ in nil }) {
            
            self.state.rawValue = .Running
            self._lock.unlock()
            
            //
            // NOTE:
            // Don't use `_lock` here so that dispatch_async'ed `handleProgress` inside `initResumeClosure()`
            // will be safely called even when current thread goes into sleep.
            //
            initResumeClosure()
            
            //
            // Comment-Out:
            // Don't call `configuration.resume()` when lazy starting.
            // This prevents inapropriate starting of upstream in ReactKit.
            //
            //self.configuration.resume?()
            
            return true
        }
        else {
            let resumed = _handleResume()
            self._lock.unlock()
            return resumed
        }
    }
    
    private func _handleResume() -> Bool
    {
        let (_, updated) = self.state.tryUpdate { $0 == .Paused ? (.Running, true) : ($0, false) }
        if updated {
            self.configuration.resume?()
            return true
        }
        else {
            return false
        }
    }
    
    internal func handleCancel(error: Error? = nil) -> Bool
    {
        self._lock.lock()
        let (_, updated) = self.state.tryUpdate { $0 == .Running || $0 == .Paused ? (.Cancelled, true) : ($0, false) }
        if updated {
            self.errorInfo.rawValue = ErrorInfo(error: error, isCancelled: true)
            self._finish()
            self._lock.unlock()
            return true
        }
        else {
            self._lock.unlock()
            return false
        }
    }
    
    private func _finish()
    {
        for handler in self._completionHandlers {
            handler()
        }
        
        self._progressTupleHandlers.removeAll()
        self._completionHandlers.removeAll()
        
        self.configuration.finish()
        
        self.initResumeClosure.rawValue = nil
        self.progress.rawValue = nil
    }
}

//--------------------------------------------------
// MARK: - Utility
//--------------------------------------------------

internal struct _HandlerToken
{
    internal let key: Int
}

internal struct _Handlers<T>: SequenceType
{
    internal typealias KeyValue = (key: Int, value: T)
    
    private var currentKey: Int = 0
    private var elements = [KeyValue]()
    
    internal mutating func append(value: T) -> _HandlerToken
    {
        self.currentKey = self.currentKey &+ 1
        
        self.elements += [(key: self.currentKey, value: value)]
        
        return _HandlerToken(key: self.currentKey)
    }
    
    internal mutating func remove(token: _HandlerToken) -> T?
    {
        for var i = 0; i < self.elements.count; i++ {
            if self.elements[i].key == token.key {
                return self.elements.removeAtIndex(i).value
            }
        }
        return nil
    }
    
    internal mutating func removeAll(keepCapacity: Bool = false)
    {
        self.elements.removeAll(keepCapacity: keepCapacity)
    }
    
    internal func generate() -> GeneratorOf<T>
    {
        return GeneratorOf(self.elements.map { $0.value }.generate())
    }
}