//
//  SwiftTask.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftState

// NOTE: nested type inside generic Task class is not allowed in Swift 1.1
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
public class TaskConfiguration
{
    public var pause: (Void -> Void)?
    public var resume: (Void -> Void)?
    public var cancel: (Void -> Void)?
    
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
    internal typealias _InitClosure = (machine: Machine, progress: ProgressHandler, fulfill: FulFillHandler, _reject: _RejectHandler, configure: TaskConfiguration) -> Void
    
    internal typealias Machine = StateMachine<TaskState, TaskEvent>
    
    private var machine: Machine!
    
    // store initial parameters for cloning task when using `try()`
    internal let _weakified: Bool
    internal var _initClosure: _InitClosure?    // will be nil on fulfilled/rejected
    
    /// wrapper closure for `_initClosure` to invoke only once when started `.Running`
    internal var _performInitClosure: (Void -> Void)?
    
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
    /// Creates a new task.
    ///
    /// - e.g. Task<P, V, E>(weakified: false, paused: false) { progress, fulfill, reject, configure in ... }
    ///
    /// :param: weakified Weakifies progress/fulfill/reject handlers to let player (inner asynchronous implementation inside initClosure) NOT CAPTURE this created new task. Normally, weakified = false should be set to gain "player -> task" retaining, so that task will be automatically deinited when player is deinited. If weakified = true, task must be manually retained somewhere else, or it will be immediately deinited.
    ///
    /// :param: paused Flag to invoke `initClosure` immediately or not. If `paused = true`, task's initial state will be `.Paused` and needs to `resume()` in order to start `.Running`. If `paused = false`, `initClosure` will be invoked immediately.
    ///
    /// :param: initClosure e.g. { progress, fulfill, reject, configure in ... }. fulfill(value) and reject(error) handlers must be called inside this closure, where calling progress(progressValue) handler is optional. Also as options, configure.pause/resume/cancel closures can be set to gain control from outside e.g. task.pause()/resume()/cancel(). When using configure, make sure to use weak modifier when appropriate to avoid "task -> player" retaining which often causes retain cycle.
    ///
    /// :returns: New task.
    ///
    public init(weakified: Bool, paused: Bool, initClosure: InitClosure)
    {
        self._weakified = weakified
        
        let _initClosure: _InitClosure = { machine, progress, fulfill, _reject, configure in
            // NOTE: don't expose rejectHandler with ErrorInfo (isCancelled) for public init
            initClosure(progress: progress, fulfill: fulfill, reject: { (error: Error?) in _reject(ErrorInfo(error: error, isCancelled: false)) }, configure: configure)
        }
        
        self.setup(weakified, paused: paused, _initClosure)
    }
    
    ///
    /// creates a new task without weakifying progress/fulfill/reject handlers
    ///
    /// - e.g. Task<P, V, E>(paused: false) { progress, fulfill, reject, configure in ... }
    ///
    public convenience init(paused: Bool, initClosure: InitClosure)
    {
        self.init(weakified: false, paused: paused, initClosure: initClosure)
    }
    
    ///
    /// creates a new task without weakifying progress/fulfill/reject handlers (non-paused)
    ///
    /// - e.g. Task<P, V, E> { progress, fulfill, reject, configure in ... }
    ///
    public convenience init(initClosure: InitClosure)
    {
        self.init(weakified: false, paused: false, initClosure: initClosure)
    }
    
    ///
    /// creates fulfilled task (non-paused)
    ///
    /// - e.g. Task<P, V, E>(value: someValue)
    ///
    public convenience init(value: Value)
    {
        self.init(initClosure: { progress, fulfill, reject, configure in
            fulfill(value)
        })
    }
    
    ///
    /// creates rejected task (non-paused)
    ///
    /// - e.g. Task<P, V, E>(error: someError)
    ///
    public convenience init(error: Error)
    {
        self.init(initClosure: { progress, fulfill, reject, configure in
            reject(error)
        })
    }
    
    ///
    /// creates promise-like task which only allows fulfill & reject (no progress & configure)
    ///
    /// - e.g. Task<Any, Value, Error> { fulfill, reject in ... }
    ///
    public convenience init(promiseInitClosure: PromiseInitClosure)
    {
        self.init(initClosure: { progress, fulfill, reject, configure in
            promiseInitClosure(fulfill: fulfill, reject: { (error: Error) in reject(error) })
        })
    }
    
    /// internal-init for accessing private `machine` inside `_initClosure`
    /// (NOTE: _initClosure has _RejectHandler as argument)
    internal init(weakified: Bool = false, paused: Bool = false, _initClosure: _InitClosure)
    {
        self._weakified = weakified
        
        self.setup(weakified, paused: paused, _initClosure)
    }
    
    internal func setup(weakified: Bool, paused: Bool, _initClosure: _InitClosure)
    {
//        #if DEBUG
//            println("[init] \(self)")
//        #endif
        
        let configuration = Configuration()
        
        let initialState: TaskState = paused ? .Paused : .Running
        
        // NOTE: Swift 1.1 compiler fails if using [weak self] instead...
        weak var weakSelf = self
        
        // setup state machine
        self.machine = Machine(state: initialState) {
            
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
            
            // NOTE: use order = 90 (< default = 100) to prepare setting value before handling progress/fulfill/reject
            $0.addEventHandler(.Progress, order: 90) { context in
                if let progressTuple = context.userInfo as? ProgressTuple {
                    weakSelf?.progress = progressTuple.newProgress
                }
            }
            $0.addEventHandler(.Fulfill, order: 90) { context in
                if let value = context.userInfo as? Value {
                    weakSelf?.value = value
                }
                configuration.clear()
            }
            $0.addEventHandler(.Reject, order: 90) { context in
                if let errorInfo = context.userInfo as? ErrorInfo {
                    weakSelf?.errorInfo = errorInfo
                    configuration.cancel?() // NOTE: call configured cancellation on reject as well
                }
                configuration.clear()
            }
            
            // clear `_initClosure` & all StateMachine's handlers to prevent retain cycle
            $0.addEventHandler(.Fulfill, order: 255) { context in
                weakSelf?._initClosure = nil
                weakSelf?._performInitClosure = nil
                weakSelf?.machine?.removeAllHandlers()
            }
            $0.addEventHandler(.Reject, order: 255) { context in
                weakSelf?._initClosure = nil
                weakSelf?._performInitClosure = nil
                weakSelf?.machine?.removeAllHandlers()
            }
            
        }
        
        self._initClosure = _initClosure
        
        // will be invoked only once
        self._performInitClosure = { [weak self] in
            
            if let self_ = self {
                
                var progressHandler: ProgressHandler
                var fulfillHandler: FulFillHandler
                var rejectHandler: _RejectHandler
                
                if weakified {
                    progressHandler = { [weak self_] (progress: Progress) in
                        if let self_ = self_ {
                            let oldProgress = self_.progress
                            self_.machine <-! (.Progress, (oldProgress, progress))
                        }
                    }
                    
                    fulfillHandler = { [weak self_] (value: Value) in
                        if let self_ = self_ {
                            self_.machine <-! (.Fulfill, value)
                        }
                    }
                    
                    rejectHandler = { [weak self_] (errorInfo: ErrorInfo) in
                        if let self_ = self_ {
                            self_.machine <-! (.Reject, errorInfo)
                        }
                    }
                }
                else {
                    progressHandler = { (progress: Progress) in
                        let oldProgress = self_.progress
                        self_.machine <-! (.Progress, (oldProgress, progress))
                        return
                    }
                    
                    fulfillHandler = { (value: Value) in
                        self_.machine <-! (.Fulfill, value)
                        return
                    }
                    
                    rejectHandler = { (errorInfo: ErrorInfo) in
                        self_.machine <-! (.Reject, errorInfo)
                        return
                    }
                }
            
                _initClosure(machine: self_.machine, progress: progressHandler, fulfill: fulfillHandler, _reject: rejectHandler, configure: configuration)
                
            }
        
        }
        
        if !paused {
            self.resume()
        }
    }
    
    deinit
    {
//        #if DEBUG
//            println("[deinit] \(self)")
//        #endif
        
        // cancel in case machine is still running
        self._cancel(error: nil)
    }
    
    /// Returns new task that is retryable for `tryCount-1` times.
    /// `task.try(n)` is conceptually equal to `task.failure(clonedTask1).failure(clonedTask2)...` with n-1 failure-able.
    public func try(maxTryCount: Int) -> Task
    {
        if maxTryCount < 2 { return self }
        
        let weakified = self._weakified
        let initClosure = self._initClosure
        
        if initClosure == nil { return self }
        
        let newTask = Task { [weak self] machine, progress, fulfill, _reject, configure in
        
            var chainedTasks = [self!]
            var nextTask: Task = self!
        
            for i in 1...maxTryCount-1 {
                nextTask = nextTask.progress { _, progressValue in
                    progress(progressValue)
                }.failure { _ -> Task in
                    return Task(weakified: weakified, _initClosure: initClosure!)   // create a clone-task when rejected
                }
                
                chainedTasks += [nextTask]
            }
            
            nextTask.progress { _, progressValue in
                progress(progressValue)
            }.success { value -> Void in
                fulfill(value)
            }.failure { errorInfo -> Void in
                _reject(errorInfo)
            }
            
            configure.pause = {
                for task in chainedTasks {
                    task.pause();
                }
            }
            configure.resume = {
                for task in chainedTasks {
                    task.resume();
                }
            }
            configure.cancel = {
                // NOTE: use `reverse()` to cancel from downstream to upstream
                for task in chainedTasks.reverse() {
                    task.cancel();
                }
            }
            
        }
        
        return newTask
    }
    
    ///
    /// Add progress handler delivered from `initClosure`'s `progress()` argument.
    ///
    /// - e.g. task.progress { oldProgress, newProgress in ... }
    ///
    public func progress(progressClosure: ProgressTuple -> Void) -> Task
    {
        self.machine.addEventHandler(.Progress) { [weak self] context in
            if let progressTuple = context.userInfo as? ProgressTuple {
                progressClosure(progressTuple)
            }
        }
        
        return self
    }
    
    ///
    /// then (fulfilled & rejected) + closure returning value
    ///
    /// - e.g. task.then { value, errorInfo -> NextValueType in ... }
    ///
    public func then<Value2>(thenClosure: (Value?, ErrorInfo?) -> Value2) -> Task<Progress, Value2, Error>
    {
        return self.then { (value: Value?, errorInfo: ErrorInfo?) -> Task<Progress, Value2, Error> in
            return Task<Progress, Value2, Error>(value: thenClosure(value, errorInfo))
        }
    }
    
    ///
    /// then (fulfilled & rejected) + closure returning task
    ///
    /// - e.g. task.then { value, errorInfo -> NextTaskType in ... }
    ///
    public func then<Progress2, Value2>(thenClosure: (Value?, ErrorInfo?) -> Task<Progress2, Value2, Error>) -> Task<Progress2, Value2, Error>
    {
        let newTask = Task<Progress2, Value2, Error> { [weak self] machine, progress, fulfill, _reject, configure in
            
            let bind = { [weak machine] (value: Value?, errorInfo: ErrorInfo?) -> Void in
                let innerTask = thenClosure(value, errorInfo)
                
                // NOTE: don't call `then` for innerTask, or recursive bindings may occur
                // Bad example: https://github.com/inamiy/SwiftTask/blob/e6085465c147fb2211fb2255c48929fcc07acd6d/SwiftTask/SwiftTask.swift#L312-L316
                switch innerTask.machine.state {
                    case .Fulfilled:
                        fulfill(innerTask.value!)
                    case .Rejected:
                        _reject(innerTask.errorInfo!)
                    default:
                        innerTask.machine.addEventHandler(.Progress) { context in
                            if let (_, progressValue) = context.userInfo as? Task<Progress2, Value2, Error>.ProgressTuple {
                                progress(progressValue)
                            }
                        }
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
                
                // pause/cancel innerTask if descendant task is already paused/cancelled
                if machine!.state == .Paused {
                    innerTask.pause()
                }
                else if machine!.state == .Cancelled {
                    innerTask.cancel()
                }
            }
            
            if let self_ = self {
                switch self_.machine.state {
                    case .Fulfilled:
                        bind(self_.value!, nil)
                    case .Rejected:
                        bind(nil, self_.errorInfo!)
                    default:
                        // comment-out: only innerTask's progress should be sent to newTask
//                        self_.machine.addEventHandler(.Progress) { context in
//                            if let (_, progressValue) = context.userInfo as? Task<Progress2, Value2, Error>.ProgressTuple {
//                                progress(progressValue)
//                            }
//                        }
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
    
    ///
    /// success (fulfilled) + closure returning value
    ///
    /// - e.g. task.success { value -> NextValueType in ... }
    ///
    public func success<Value2>(successClosure: Value -> Value2) -> Task<Progress, Value2, Error>
    {
        return self.success { (value: Value) -> Task<Progress, Value2, Error> in
            return Task<Progress, Value2, Error>(value: successClosure(value))
        }
    }
    
    ///
    /// success (fulfilled) + closure returning task
    ///
    /// - e.g. task.success { value -> NextTaskType in ... }
    ///
    public func success<Progress2, Value2>(successClosure: Value -> Task<Progress2, Value2, Error>) -> Task<Progress2, Value2, Error>
    {
        let newTask = Task<Progress2, Value2, Error> { [weak self] machine, progress, fulfill, _reject, configure in
            
            let bind = { [weak machine] (value: Value) -> Void in
                let innerTask = successClosure(value)
                
                innerTask.progress { _, progressValue in
                    progress(progressValue)
                }.then { (value: Value2?, errorInfo: ErrorInfo?) -> Void in
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
                
                // pause/cancel innerTask if descendant task is already paused/cancelled
                if machine!.state == .Paused {
                    innerTask.pause()
                }
                else if machine!.state == .Cancelled {
                    innerTask.cancel()
                }
            }
            
            if let self_ = self {
                switch self_.machine.state {
                    case .Fulfilled:
                        bind(self_.value!)
                    case .Rejected:
                        _reject(self_.errorInfo!)
                    default:
                        // comment-out: only innerTask's progress should be sent to newTask
//                        self_.machine.addEventHandler(.Progress) { context in
//                            if let (_, progressValue) = context.userInfo as? Task<Progress2, Value2, Error>.ProgressTuple {
//                                progress(progressValue)
//                            }
//                        }
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
    
    ///
    /// failure (rejected) + closure returning value
    ///
    /// - e.g. task.failure { errorInfo -> NextValueType in ... }
    /// - e.g. task.failure { error, isCancelled -> NextValueType in ... }
    ///
    public func failure(failureClosure: ErrorInfo -> Value) -> Task
    {
        return self.failure { (errorInfo: ErrorInfo) -> Task in
            return Task(value: failureClosure(errorInfo))
        }
    }

    ///
    /// failure (rejected) + closure returning task
    ///
    /// - e.g. task.failure { errorInfo -> NextTaskType in ... }
    /// - e.g. task.failure { error, isCancelled -> NextTaskType in ... }
    ///
    public func failure(failureClosure: ErrorInfo -> Task) -> Task
    {
        let newTask = Task { [weak self] machine, progress, fulfill, _reject, configure in
            
            let bind = { [weak machine] (errorInfo: ErrorInfo) -> Void in
                let innerTask = failureClosure(errorInfo)
                
                innerTask.progress { _, progressValue in
                    progress(progressValue)
                }.then { (value: Value?, errorInfo: ErrorInfo?) -> Void in
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
                
                // pause/cancel innerTask if descendant task is already paused/cancelled
                if machine!.state == .Paused {
                    innerTask.pause()
                }
                else if machine!.state == .Cancelled {
                    innerTask.cancel()
                }
            }
            
            if let self_ = self {
                switch self_.machine.state {
                    case .Fulfilled:
                        fulfill(self_.value!)
                    case .Rejected:
                        let errorInfo = self_.errorInfo!
                        bind(errorInfo)
                    default:
                        // comment-out: only innerTask's progress should be sent to newTask
//                        self_.machine.addEventHandler(.Progress) { context in
//                            if let (_, progressValue) = context.userInfo as? Task.ProgressTuple {
//                                progress(progressValue)
//                            }
//                        }
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
        // always try `_performInitClosure` only once on `resume()`
        // even when to-Resume-transition fails, e.g. already been fulfilled/rejected
        self._performInitClosure?()
        self._performInitClosure = nil
        
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
        return Task<BulkProgress, [Value], Error> { machine, progress, fulfill, _reject, configure in
            
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
        return Task<Progress, Value, Error> { machine, progress, fulfill, _reject, configure in
            
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
        return Task<BulkProgress, [Value], Error> { machine, progress, fulfill, _reject, configure in
            
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
// MARK: - Custom Operators
// + - * / % = < > ! & | ^ ~ .
//--------------------------------------------------

infix operator ~ { associativity left }

/// abbreviation for `try()`
/// e.g. (task ~ 3).then { ... }
public func ~ <P, V, E>(task: Task<P, V, E>, tryCount: Int) -> Task<P, V, E>
{
    return task.try(tryCount)
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