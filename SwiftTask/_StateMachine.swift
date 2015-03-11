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
    
    internal let weakified: Bool
    internal var state: TaskState
    
    internal var progress: Progress?
    internal var value: Value?
    internal var errorInfo: ErrorInfo?
    
    internal var progressTupleHandlers: [Task<Progress, Value, Error>._ProgressTupleHandler] = []
    internal var completionHandlers: [Void -> Void] = []
    
    internal let configuration = TaskConfiguration()
    
    internal init(weakified: Bool, paused: Bool)
    {
        self.weakified = weakified
        self.state = paused ? .Paused : .Running
    }
    
    internal func handleProgress(progress: Progress)
    {
        if self.state == .Running {
            
            let oldProgress = self.progress
            
            // NOTE: if `weakified = false`, don't store progressValue for less memory footprint
            if !self.weakified {
                self.progress = progress
            }
            
            for handler in self.progressTupleHandlers {
                handler(oldProgress: oldProgress, newProgress: progress)
            }
        }
    }
    
    internal func handleFulfill(value: Value)
    {
        if self.state == .Running {
            self.state = .Fulfilled
            self.value = value
            self.complete()
        }
    }
    
    internal func handleRejectInfo(errorInfo: ErrorInfo)
    {
        if self.state == .Running || self.state == .Paused {
            self.state = errorInfo.isCancelled ? .Cancelled : .Rejected
            self.errorInfo = errorInfo
            self.complete()
        }
    }
    
    internal func handlePause() -> Bool
    {
        if self.state == .Running {
            self.configuration.pause?()
            self.state = .Paused
            return true
        }
        else {
            return false
        }
    }
    
    internal func handleResume() -> Bool
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
        if self.state == .Running || self.state == .Paused {
            
            self.state = .Cancelled
            self.errorInfo = ErrorInfo(error: error, isCancelled: true)
            self.complete {
                // NOTE: call `configuration.cancel()` after all `completionHandlers` are invoked
                self.configuration.cancel?()
                return
            }
            
            return true
        }
        else {
            return false
        }
    }
    
    internal func complete(closure: (Void -> Void)? = nil)
    {
        for handler in self.completionHandlers {
            handler()
        }
        
        closure?()
        
        self.progressTupleHandlers.removeAll()
        self.completionHandlers.removeAll()
        self.configuration.clear()
        self.progress = nil
    }
}