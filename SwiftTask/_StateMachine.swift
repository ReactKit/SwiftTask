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
    internal private(set) var state: TaskState
    
    internal private(set) var progress: Progress?    // NOTE: always nil if `weakified = true`
    internal private(set) var value: Value?
    internal private(set) var errorInfo: ErrorInfo?
    
    /// wrapper closure for `_initClosure` to invoke only once when started `.Running`,
    /// and will be set to `nil` afterward
    internal var initResumeClosure: (Void -> Void)?
    
    internal private(set) lazy var progressTupleHandlers = _Handlers<ProgressTupleHandler>()
    internal private(set) lazy var completionHandlers = _Handlers<Void -> Void>()
    
    internal let configuration = TaskConfiguration()
    
    private let _recursiveLock = _RecursiveLock()
    
    internal init(weakified: Bool, paused: Bool)
    {
        self.weakified = weakified
        self.state = paused ? .Paused : .Running
    }
    
    internal func addProgressTupleHandler(inout token: _HandlerToken?, _ progressTupleHandler: ProgressTupleHandler) -> Bool
    {
        self._recursiveLock.lock()
        if self.state == .Running || self.state == .Paused {
            token = self.progressTupleHandlers.append(progressTupleHandler)
            self._recursiveLock.unlock()
            return token != nil
        }
        else {
            self._recursiveLock.unlock()
            return false
        }
    }
    
    internal func removeProgressTupleHandler(handlerToken: _HandlerToken?) -> Bool
    {
        self._recursiveLock.lock()
        if let handlerToken = handlerToken {
            let removedHandler = self.progressTupleHandlers.remove(handlerToken)
            self._recursiveLock.unlock()
            return removedHandler != nil
        }
        else {
            self._recursiveLock.unlock()
            return false
        }
    }
    
    internal func addCompletionHandler(inout token: _HandlerToken?, _ completionHandler: Void -> Void) -> Bool
    {
        self._recursiveLock.lock()
        if self.state == .Running || self.state == .Paused {
            token = self.completionHandlers.append(completionHandler)
            self._recursiveLock.unlock()
            return token != nil
        }
        else {
            self._recursiveLock.unlock()
            return false
        }
    }
    
    internal func removeCompletionHandler(handlerToken: _HandlerToken?) -> Bool
    {
        self._recursiveLock.lock()
        if let handlerToken = handlerToken {
            let removedHandler = self.completionHandlers.remove(handlerToken)
            self._recursiveLock.unlock()
            return removedHandler != nil
        }
        else {
            self._recursiveLock.unlock()
            return false
        }
    }
    
    internal func handleProgress(progress: Progress)
    {
        self._recursiveLock.lock()
        if self.state == .Running {
            
            let oldProgress = self.progress
            
            // NOTE: if `weakified = false`, don't store progressValue for less memory footprint
            if !self.weakified {
                self.progress = progress
            }
            
            for handler in self.progressTupleHandlers {
                handler(oldProgress: oldProgress, newProgress: progress)
            }
            self._recursiveLock.unlock()
        }
        else {
            self._recursiveLock.unlock()
        }
    }
    
    internal func handleFulfill(value: Value)
    {
        self._recursiveLock.lock()
        if self.state == .Running {
            self.state = .Fulfilled
            self.value = value
            self._finish()
            self._recursiveLock.unlock()
        }
        else {
            self._recursiveLock.unlock()
        }
    }
    
    internal func handleRejectInfo(errorInfo: ErrorInfo)
    {
        self._recursiveLock.lock()
        if self.state == .Running || self.state == .Paused {
            self.state = errorInfo.isCancelled ? .Cancelled : .Rejected
            self.errorInfo = errorInfo
            self._finish()
            self._recursiveLock.unlock()
        }
        else {
            self._recursiveLock.unlock()
        }
    }
    
    internal func handlePause() -> Bool
    {
        self._recursiveLock.lock()
        if self.state == .Running {
            self.configuration.pause?()
            self.state = .Paused
            self._recursiveLock.unlock()
            return true
        }
        else {
            self._recursiveLock.unlock()
            return false
        }
    }
    
    internal func handleResume() -> Bool
    {
        //
        // NOTE:
        // `initResumeClosure` should be invoked first before `configure.resume()`
        // to let downstream prepare setting upstream's progress/fulfill/reject handlers
        // before upstream actually starts sending values, which often happens
        // when downstream's `configure.resume()` is configured to call upstream's `task.resume()`
        // which eventually calls upstream's `initResumeClosure`
        // and thus upstream starts sending values.
        //
        
        self._recursiveLock.lock()
        
        self._handleInitResumeIfNeeded()
        let resumed = _handleResume()
        
        self._recursiveLock.unlock()
        
        return resumed
    }
    
    ///
    /// Invokes `initResumeClosure` on 1st resume (only once).
    ///
    /// If initial state is `.Paused`, `state` will be temporarily switched to `.Running`
    /// during `initResumeClosure` execution, so that Task can call progress/fulfill/reject handlers safely.
    ///
    private func _handleInitResumeIfNeeded()
    {
        if (self.initResumeClosure != nil) {
            
            let isInitPaused = (self.state == .Paused)
            if isInitPaused {
                self.state = .Running  // switch `.Paused` => `.Resume` temporarily without invoking `configure.resume()`
            }
            
            // NOTE: performing `initResumeClosure` might change `state` to `.Fulfilled` or `.Rejected` **immediately**
            self.initResumeClosure?()
            self.initResumeClosure = nil
            
            // switch back to `.Paused` if temporary `.Running` has not changed
            // so that consecutive `_handleResume()` can perform `configure.resume()`
            if isInitPaused && self.state == .Running {
                self.state = .Paused
            }
        }
    }
    
    private func _handleResume() -> Bool
    {
        if self.state == .Paused {
            self.configuration.resume?()
            self.state = .Running
            return true
        }
        else {
            return false
        }
    }
    
    internal func handleCancel(error: Error? = nil) -> Bool
    {
        self._recursiveLock.lock()
        if self.state == .Running || self.state == .Paused {
            self.state = .Cancelled
            self.errorInfo = ErrorInfo(error: error, isCancelled: true)
            self._finish()
            self._recursiveLock.unlock()
            return true
        }
        else {
            self._recursiveLock.unlock()
            return false
        }
    }
    
    private func _finish()
    {
        for handler in self.completionHandlers {
            handler()
        }
        
        self.progressTupleHandlers.removeAll()
        self.completionHandlers.removeAll()
        
        self.configuration.finish()
        
        self.initResumeClosure = nil
        self.progress = nil
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