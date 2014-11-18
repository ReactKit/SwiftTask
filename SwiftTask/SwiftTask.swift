//
//  SwiftTask.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftState

// TODO: nest inside Task class
public enum TaskState: String, StateType, Printable
{
    case Paused = "Paused"
    case Running = "Running"
    case Fulfilled = "Fulfilled"
    case Rejected = "Rejected"
    case Any = "Any"
    
    case Cancelled = "Cancelled" // NOTE: .Cancelled is never added to StateMachine's routes, but is returned via `task.state`
    
    public init(nilLiteral: Void)
    {
        self = Any
    }
    
    public var description: String
    {
        return self.rawValue
    }
}

// TODO: nest inside Task class
public enum TaskEvent: String, StateEventType, Printable
{
    case Pause = "Pause"
    case Resume = "Resume"
    case Progress = "Progress"
    case Fulfill = "Fulfill"
    case Reject = "Reject"      // also used in cancellation for simplicity
    case Any = "Any"
    
    public init(nilLiteral: Void)
    {
        self = Any
    }
    
    public var description: String
    {
        return self.rawValue
    }
}

// NOTE: use class instead of struct to pass reference to closures so that future values can be stored
// TODO: nest inside Task class
public class TaskConfiguration
{
    public var pause: (Void -> Void)?
    public var resume: (Void -> Void)?
    public var cancel: (Void -> Void)?
    
//    deinit
//    {
//        println("deinit: TaskConfiguration")
//    }
    
    internal func clear()
    {
        self.pause = nil
        self.resume = nil
        self.cancel = nil
    }
}

public class Task<Progress, Value, Error>
{
    public typealias ErrorInfo = (error: Error?, isCancelled: Bool)
    
    public typealias ProgressHandler = (Progress) -> Void
    public typealias FulFillHandler = (Value) -> Void
    public typealias RejectHandler = (Error) -> Void
    public typealias Configuration = TaskConfiguration
    
    public typealias ProgressTuple = (oldProgress: Progress?, newProgress: Progress)
    public typealias BulkProgress = (completedCount: Int, totalCount: Int)
    
    public typealias PromiseInitClosure = (fulfill: FulFillHandler, reject: RejectHandler) -> Void
    public typealias InitClosure = (progress: ProgressHandler, fulfill: FulFillHandler, reject: RejectHandler, configure: TaskConfiguration) -> Void
    
    internal typealias _RejectHandler = (ErrorInfo) -> Void
    internal typealias _InitClosure = (progress: ProgressHandler, fulfill: FulFillHandler, _reject: _RejectHandler, configure: TaskConfiguration) -> Void
    
    internal typealias Machine = StateMachine<TaskState, TaskEvent>
    
    internal var machine: Machine!

    /// progress value
    public internal(set) var progress: Progress?
    
    /// fulfilled value
    public internal(set) var value: Value?
    
    /// rejected/cancelled tuple info
    public internal(set) var errorInfo: ErrorInfo?
    
    public var state: TaskState
    {
        // return .Cancelled if .Rejected & errorInfo.isCancelled=true
        if self.machine.state == .Rejected {
            if let errorInfo = self.errorInfo {
                if errorInfo.isCancelled {
                    return .Cancelled
                }
            }
        }
            
        return self.machine.state
    }
    
    ///
    /// Creates new task.
    /// e.g. Task<P, V, E>(weakified: false) { progress, fulfill, reject, configure in ... }
    ///
    /// :param: weakified Weakifies progress/fulfill/reject handlers to let player (inner asynchronous implementation inside initClosure) NOT CAPTURE this created new task. Normally, weakified = false should be set to gain "player -> task" retaining, so that task will be automatically deinited when player is deinited. If weakified = true, task must be manually retained somewhere else, or it will be immediately deinited.
    ///
    /// :param: initClosure e.g. { progress, fulfill, reject, configure in ... }. fulfill(value) and reject(error) handlers must be called inside this closure, where calling progress(progressValue) handler is optional. Also as options, configure.pause/resume/cancel closures can be set to gain control from outside e.g. task.pause()/resume()/cancel(). When using configure, make sure to use weak modifier when appropriate to avoid "task -> player" retaining which often causes retain cycle.
    ///
    /// :returns: New task.
    ///
    public init(weakified: Bool, initClosure: InitClosure)
    {
        self.setup(weakified) { (progress, fulfill, _reject: ErrorInfo -> Void, configure) in
            // NOTE: don't expose rejectHandler with ErrorInfo (isCancelled) for public init
            initClosure(progress: progress, fulfill: fulfill, reject: { (error: Error?) in _reject(ErrorInfo(error: error, isCancelled: false)) }, configure: configure)
            return
        }
    }
    
    /// creates task without weakifying progress/fulfill/reject handlers
    public convenience init(initClosure: InitClosure)
    {
        self.init(weakified: false, initClosure: initClosure)
    }
    
    /// creates fulfilled task
    public convenience init(value: Value)
    {
        self.init(initClosure: { progress, fulfill, reject, configure in
            fulfill(value)
            return
        })
    }
    
    /// creates rejected task
    public convenience init(error: Error)
    {
        self.init(initClosure: { progress, fulfill, reject, configure in
            reject(error)
            return
        })
    }
    
    /// creates promise-like task which only allows fulfill & reject (no progress & configure)
    public convenience init(promiseInitClosure: PromiseInitClosure)
    {
        self.init(initClosure: { progress, fulfill, reject, configure in
            promiseInitClosure(fulfill: fulfill, reject: { (error: Error) in reject(error) })
            return
        })
    }
    
    internal init(_initClosure: _InitClosure)
    {
        self.setup(false, _initClosure)
    }
    
    internal func setup(weakified: Bool, _initClosure: _InitClosure)
    {
        let configuration = Configuration()
        
        // setup state machine
        self.machine = Machine(state: .Running) {
            
            $0.addRouteEvent(.Pause, transitions: [.Running => .Paused])
            $0.addRouteEvent(.Resume, transitions: [.Paused => .Running])
            $0.addRouteEvent(.Progress, transitions: [.Running => .Running])
            $0.addRouteEvent(.Fulfill, transitions: [.Running => .Fulfilled])
            $0.addRouteEvent(.Reject, transitions: [.Running => .Rejected, .Paused => .Rejected])
            
            $0.addEventHandler(.Resume) { context in
                configuration.resume?()
                return
            }
            
            $0.addEventHandler(.Pause) { context in
                configuration.pause?()
                return
            }
            
        }
        
        // TODO: how to nest these inside StateMachine's initClosure? (using `self` is not permitted)
        self.machine.addEventHandler(.Progress, order: 90) { [weak self] context in
            if let progressTuple = context.userInfo as? ProgressTuple {
                if let self_ = self {
                    self_.progress = progressTuple.newProgress
                }
            }
        }
        // NOTE: use order < 100 (default) to let fulfillHandler be invoked after setting value
        self.machine.addEventHandler(.Fulfill, order: 90) { [weak self] context in
            if let value = context.userInfo as? Value {
                if let self_ = self {
                    self_.value = value
                }
            }
            configuration.clear()
        }
        self.machine.addEventHandler(.Reject, order: 90) { [weak self] context in
            if let errorInfo = context.userInfo as? ErrorInfo {
                if let self_ = self {
                    self_.errorInfo = errorInfo
                }
                configuration.cancel?() // NOTE: call configured cancellation on reject as well
            }
            configuration.clear()
        }
        
        var progressHandler: ProgressHandler
        var fulfillHandler: FulFillHandler
        var rejectHandler: _RejectHandler
        
        if weakified {
            progressHandler = { [weak self] (progress: Progress) in
                if let self_ = self {
                    let oldProgress = self_.progress
                    self_.machine <-! (.Progress, (oldProgress, progress))
                }
            }
            
            fulfillHandler = { [weak self] (value: Value) in
                if let self_ = self {
                    self_.machine <-! (.Fulfill, value)
                }
            }
            
            rejectHandler = { [weak self] (errorInfo: ErrorInfo) in
                if let self_ = self {
                    self_.machine <-! (.Reject, errorInfo)
                }
            }
        }
        else {
            progressHandler = { (progress: Progress) in
                let oldProgress = self.progress
                self.machine <-! (.Progress, (oldProgress, progress))
                return
            }
            
            fulfillHandler = { (value: Value) in
                self.machine <-! (.Fulfill, value)
                return
            }
            
            rejectHandler = { (errorInfo: ErrorInfo) in
                self.machine <-! (.Reject, errorInfo)
                return
            }
        }
        
        _initClosure(progress: progressHandler, fulfill: fulfillHandler, _reject: rejectHandler, configure: configuration)
        
    }
    
    deinit
    {
//        println("deinit: \(self)")
        
        // cancel in case machine is still running
        self._cancel(error: nil)
    }
    
    public func progress(progressClosure: ProgressTuple -> Void) -> Task
    {
        self.machine.addEventHandler(.Progress) { [weak self] context in
            if let progressTuple = context.userInfo as? ProgressTuple {
                progressClosure(progressTuple)
            }
        }
        
        return self
    }
    
    /// then (fulfilled & rejected) + closure returning value
    public func then<Value2>(thenClosure: (Value?, ErrorInfo?) -> Value2) -> Task<Progress, Value2, Error>
    {
        return self.then { (value: Value?, errorInfo: ErrorInfo?) -> Task<Progress, Value2, Error> in
            return Task<Progress, Value2, Error>(value: thenClosure(value, errorInfo))
        }
    }
    
    /// then (fulfilled & rejected) + closure returning task
    public func then<Progress2, Value2>(thenClosure: (Value?, ErrorInfo?) -> Task<Progress2, Value2, Error>) -> Task<Progress2, Value2, Error>
    {
        let newTask = Task<Progress2, Value2, Error> { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            let bind = { (value: Value?, errorInfo: ErrorInfo?) -> Void in
                let innerTask = thenClosure(value, errorInfo)
                
                // NOTE: don't call `then` for innerTask, or recursive bindings may occur
                // Bad example: https://github.com/inamiy/SwiftTask/blob/e6085465c147fb2211fb2255c48929fcc07acd6d/SwiftTask/SwiftTask.swift#L312-L316
                switch innerTask.machine.state {
                    case .Fulfilled:
                        fulfill(innerTask.value!)
                    case .Rejected:
                        _reject(innerTask.errorInfo!)
                    default:
                        innerTask.machine.addEventHandler(.Fulfill) { context in
                            if let value = context.userInfo as? Value2 {
                                fulfill(value)
                            }
                        }
                        innerTask.machine.addEventHandler(.Reject) { context in
                            if let errorInfo = context.userInfo as? ErrorInfo {
                                _reject(errorInfo)
                            }
                        }
                }
                
                configure.pause = { innerTask.pause(); return }
                configure.resume = { innerTask.resume(); return }
                configure.cancel = { innerTask.cancel(); return }
            }
            
            if let self_ = self {
                switch self_.machine.state {
                    case .Fulfilled:
                        bind(self_.value!, nil)
                    case .Rejected:
                        bind(nil, self_.errorInfo!)
                    default:
                        self_.machine.addEventHandler(.Fulfill) { context in
                            if let value = context.userInfo as? Value {
                                bind(value, nil)
                            }
                        }
                        self_.machine.addEventHandler(.Reject) { context in
                            if let errorInfo = context.userInfo as? ErrorInfo {
                                bind(nil, errorInfo)
                            }
                        }
                }
            }
            
        }
        
        return newTask
    }
    
    /// success (fulfilled) + closure returning value
    public func success<Value2>(fulfilledClosure: Value -> Value2) -> Task<Progress, Value2, Error>
    {
        return self.success { (value: Value) -> Task<Progress, Value2, Error> in
            return Task<Progress, Value2, Error>(value: fulfilledClosure(value))
        }
    }
    
    /// success (fulfilled) + closure returning task
    public func success<Progress2, Value2>(fulfilledClosure: Value -> Task<Progress2, Value2, Error>) -> Task<Progress2, Value2, Error>
    {
        let newTask = Task<Progress2, Value2, Error> { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            let bind = { (value: Value) -> Void in
                let innerTask = fulfilledClosure(value)
                
                innerTask.then { (value: Value2?, errorInfo: ErrorInfo?) -> Void in
                    if let value = value {
                        fulfill(value)
                    }
                    else if let errorInfo = errorInfo {
                        _reject(errorInfo)
                    }
                }
                
                configure.pause = { innerTask.pause(); return }
                configure.resume = { innerTask.resume(); return }
                configure.cancel = { innerTask.cancel(); return }
            }
            
            if let self_ = self {
                switch self_.machine.state {
                    case .Fulfilled:
                        bind(self_.value!)
                    case .Rejected:
                        _reject(self_.errorInfo!)
                    default:
                        self_.machine.addEventHandler(.Fulfill) { context in
                            if let value = context.userInfo as? Value {
                                bind(value)
                            }
                        }
                        self_.machine.addEventHandler(.Reject) { context in
                            if let errorInfo = context.userInfo as? ErrorInfo {
                                _reject(errorInfo)
                            }
                        }
                }
            }
            
        }
        
        return newTask
    }
    
    /// failure (rejected) + closure returning value
    public func failure(failureClosure: ErrorInfo -> Value) -> Task
    {
        return self.failure { (errorInfo: ErrorInfo) -> Task in
            return Task(value: failureClosure(errorInfo))
        }
    }

    /// failure (rejected) + closure returning task
    public func failure(failureClosure: ErrorInfo -> Task) -> Task
    {
        let newTask = Task { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            let bind = { (errorInfo: ErrorInfo) -> Void in
                let innerTask = failureClosure(errorInfo)
                
                innerTask.then { (value: Value?, errorInfo: ErrorInfo?) -> Void in
                    if let value = value {
                        fulfill(value)
                    }
                    else if let errorInfo = errorInfo {
                        _reject(errorInfo)
                    }
                }
                
                configure.pause = { innerTask.pause(); return }
                configure.resume = { innerTask.resume(); return }
                configure.cancel = { innerTask.cancel(); return}
            }
            
            if let self_ = self {
                switch self_.machine.state {
                    case .Fulfilled:
                        fulfill(self_.value!)
                    case .Rejected:
                        let errorInfo = self_.errorInfo!
                        bind(errorInfo)
                    default:
                        self_.machine.addEventHandler(.Fulfill) { context in
                            if let value = context.userInfo as? Value {
                                fulfill(value)
                            }
                        }
                        self_.machine.addEventHandler(.Reject) { context in
                            if let errorInfo = context.userInfo as? ErrorInfo {
                                bind(errorInfo)
                            }
                        }
                }
            }
            
        }
        
        return newTask
    }
    
    public func pause() -> Bool
    {
        return self.machine <-! .Pause
    }
    
    public func resume() -> Bool
    {
        return self.machine <-! .Resume
    }
    
    public func cancel(error: Error? = nil) -> Bool
    {
        return self._cancel(error: error)
    }
    
    internal func _cancel(error: Error? = nil) -> Bool
    {
        return self.machine <-! (.Reject, ErrorInfo(error: error, isCancelled: true))
    }
}

extension Task
{
    public class func all(tasks: [Task]) -> Task<BulkProgress, [Value], Error>
    {
        return Task<BulkProgress, [Value], Error> { (progress, fulfill, _reject: _RejectHandler, configure) in
            
            var completedCount = 0
            let totalCount = tasks.count
            
            for task in tasks {
                task.success { (value: Value) -> Void in
                    
                    synchronized(self) {
                        completedCount++
                        
                        let progressTuple = BulkProgress(completedCount: completedCount, totalCount: totalCount)
                        progress(progressTuple)
                        
                        if completedCount == totalCount {
                            var values: [Value] = Array()
                            
                            for task in tasks {
                                values.append(task.value!)
                            }
                            
                            fulfill(values)
                        }
                    }
                    
                }.failure { (errorInfo: ErrorInfo) -> Void in
                    
                    synchronized(self) {
                        _reject(errorInfo)
                        
                        for task in tasks {
                            task.cancel()
                        }
                    }
                }
            }
            
            configure.pause = { self.pauseAll(tasks); return }
            configure.resume = { self.resumeAll(tasks); return }
            configure.cancel = { self.cancelAll(tasks); return }
            
        }
    }
    
    public class func any(tasks: [Task]) -> Task
    {
        return Task<Progress, Value, Error> { (progress, fulfill, _reject: _RejectHandler, configure) in
            
            var completedCount = 0
            var rejectedCount = 0
            let totalCount = tasks.count
            
            for task in tasks {
                task.success { (value: Value) -> Void in
                    
                    synchronized(self) {
                        completedCount++
                        
                        if completedCount == 1 {
                            fulfill(value)
                            
                            self.cancelAll(tasks)
                        }
                    }
                    
                }.failure { (errorInfo: ErrorInfo) -> Void in
                    
                    synchronized(self) {
                        rejectedCount++
                        
                        if rejectedCount == totalCount {
                            var isAnyCancelled = (tasks.filter { task in task.state == .Cancelled }.count > 0)
                            
                            let errorInfo = ErrorInfo(error: nil, isCancelled: isAnyCancelled)  // NOTE: Task.any error returns nil (spec)
                            _reject(errorInfo)
                        }
                    }
                }
            }
            
            configure.pause = { self.pauseAll(tasks); return }
            configure.resume = { self.resumeAll(tasks); return }
            configure.cancel = { self.cancelAll(tasks); return }
            
        }
    }
    
    /// Returns new task which performs all given tasks and stores only fulfilled values.
    /// This new task will NEVER be internally rejected.
    public class func some(tasks: [Task]) -> Task<BulkProgress, [Value], Error>
    {
        return Task<BulkProgress, [Value], Error> { (progress, fulfill, _reject: _RejectHandler, configure) in
            
            var completedCount = 0
            let totalCount = tasks.count
            
            for task in tasks {
                task.then { (value: Value?, errorInfo: ErrorInfo?) -> Void in
                    
                    synchronized(self) {
                        completedCount++
                        
                        let progressTuple = BulkProgress(completedCount: completedCount, totalCount: totalCount)
                        progress(progressTuple)
                        
                        if completedCount == totalCount {
                            var values: [Value] = Array()
                            
                            for task in tasks {
                                if task.state == .Fulfilled {
                                    values.append(task.value!)
                                }
                            }
                            
                            fulfill(values)
                        }
                    }
                    
                }
            }
            
            configure.pause = { self.pauseAll(tasks); return }
            configure.resume = { self.resumeAll(tasks); return }
            configure.cancel = { self.cancelAll(tasks); return }
            
        }
    }
    
    public class func cancelAll(tasks: [Task])
    {
        for task in tasks {
            task._cancel()
        }
    }
    
    public class func pauseAll(tasks: [Task])
    {
        for task in tasks {
            task.pause()
        }
    }
    
    public class func resumeAll(tasks: [Task])
    {
        for task in tasks {
            task.resume()
        }
    }
}

//--------------------------------------------------
// MARK: - Utility
//--------------------------------------------------

internal func synchronized(object: AnyObject, closure: Void -> Void)
{
    objc_sync_enter(object)
    closure()
    objc_sync_exit(object)
}