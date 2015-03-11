//
//  SwiftTask.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

// NOTE: nested type inside generic Task class is not allowed in Swift 1.1
public enum TaskState: String, Printable
{
    case Paused = "Paused"
    case Running = "Running"
    case Fulfilled = "Fulfilled"
    case Rejected = "Rejected"
    case Cancelled = "Cancelled"
    
    public var description: String
    {
        return self.rawValue
    }
}

// NOTE: use class instead of struct to pass reference to `_initClosure` to set `pause`/`resume`/`cancel` closures
public class TaskConfiguration
{
    public var pause: (Void -> Void)?
    public var resume: (Void -> Void)?
    public var cancel: (Void -> Void)?
    
    public init()
    {
        
    }
    
    internal func clear()
    {
        self.pause = nil
        self.resume = nil
        self.cancel = nil
    }
}

public class Task<Progress, Value, Error>: Printable
{
    public typealias ProgressTuple = (oldProgress: Progress?, newProgress: Progress)
    public typealias ErrorInfo = (error: Error?, isCancelled: Bool)
    
    public typealias ProgressHandler = (Progress -> Void)
    public typealias FulfillHandler = (Value -> Void)
    public typealias RejectHandler = (Error -> Void)
    public typealias Configuration = TaskConfiguration
    
    public typealias PromiseInitClosure = (fulfill: FulfillHandler, reject: RejectHandler) -> Void
    public typealias InitClosure = (progress: ProgressHandler, fulfill: FulfillHandler, reject: RejectHandler, configure: TaskConfiguration) -> Void
    
    internal typealias _Machine = _StateMachine<Progress, Value, Error>
    
    internal typealias _InitClosure = (machine: _Machine, progress: ProgressHandler, fulfill: FulfillHandler, _reject: _RejectInfoHandler, configure: TaskConfiguration) -> Void
    
    internal typealias _ProgressTupleHandler = (ProgressTuple -> Void)
    internal typealias _RejectInfoHandler = (ErrorInfo -> Void)
    
    internal let _machine: _Machine
    
    // store initial parameters for cloning task when using `try()`
    internal let _weakified: Bool
    internal let _paused: Bool
    internal var _initClosure: _InitClosure!    // retained throughout task's lifetime
    
    /// wrapper closure for `_initClosure` to invoke only once when started `.Running`,
    /// and will be set to `nil` afterward
    internal var _performInitClosure: (Void -> Void)?
    
    public var state: TaskState { return self._machine.state }
    
    /// progress value (NOTE: always nil when `weakified = true`)
    public var progress: Progress? { return self._machine.progress }
    
    /// fulfilled value
    public var value: Value? { return self._machine.value }
    
    /// rejected/cancelled tuple info
    public var errorInfo: ErrorInfo? { return self._machine.errorInfo }
    
    public var name: String = "DefaultTask"
    
    public var description: String
    {
        var valueString: String?
        
        switch (self.state) {
            case .Fulfilled:
                valueString = "value=\(self.value!)"
            case .Rejected, .Cancelled:
                valueString = "errorInfo=\(self.errorInfo!)"
            default:
                valueString = "progress=\(self.progress)"
        }
        
        return "<\(self.name); state=\(self.state.rawValue); \(valueString!))>"
    }
    
    ///
    /// Creates a new task.
    ///
    /// - e.g. Task<P, V, E>(weakified: false, paused: false) { progress, fulfill, reject, configure in ... }
    ///
    /// :param: weakified Weakifies progress/fulfill/reject handlers to let player (inner asynchronous implementation inside `initClosure`) NOT CAPTURE this created new task. Normally, `weakified = false` should be set to gain "player -> task" retaining, so that task will be automatically deinited when player is deinited. If `weakified = true`, task must be manually retained somewhere else, or it will be immediately deinited.
    ///
    /// :param: paused Flag to invoke `initClosure` immediately or not. If `paused = true`, task's initial state will be `.Paused` and needs to `resume()` in order to start `.Running`. If `paused = false`, `initClosure` will be invoked immediately.
    ///
    /// :param: initClosure e.g. { progress, fulfill, reject, configure in ... }. `fulfill(value)` and `reject(error)` handlers must be called inside this closure, where calling `progress(progressValue)` handler is optional. Also as options, `configure.pause`/`configure.resume`/`configure.cancel` closures can be set to gain control from outside e.g. `task.pause()`/`task.resume()`/`task.cancel()`. When using `configure`, make sure to use weak modifier when appropriate to avoid "task -> player" retaining which often causes retain cycle.
    ///
    /// :returns: New task.
    ///
    public init(weakified: Bool, paused: Bool, initClosure: InitClosure)
    {
        self._weakified = weakified
        self._paused = paused
        self._machine = _Machine(weakified: weakified, paused: paused)
        
        let _initClosure: _InitClosure = { _, progress, fulfill, _reject, configure in
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
        self.name = "FulfilledTask"
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
        self.name = "RejectedTask"
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
    
    /// internal-init for accessing `machine` inside `_initClosure`
    /// (NOTE: _initClosure has _RejectInfoHandler as argument)
    internal init(weakified: Bool = false, paused: Bool = false, _initClosure: _InitClosure)
    {
        self._weakified = weakified
        self._paused = paused
        self._machine = _Machine(weakified: weakified, paused: paused)
        
        self.setup(weakified, paused: paused, _initClosure)
    }
    
    internal func setup(weakified: Bool, paused: Bool, _initClosure: _InitClosure)
    {        
//        #if DEBUG
//            println("[init] \(self.name)")
//        #endif
        
        self._initClosure = _initClosure
        
        // will be invoked on 1st resume (only once)
        self._performInitClosure = { [weak self] in
            
            // strongify `self` on 1st resume
            if let self_ = self {
                
                var progressHandler: ProgressHandler
                var fulfillHandler: FulfillHandler
                var rejectInfoHandler: _RejectInfoHandler
                
                if weakified {
                    //
                    // NOTE:
                    // When `weakified = true`,
                    // each handler will NOT capture `self_` (strongSelf on 1st resume)
                    // so it will immediately deinit if not retained in somewhere else.
                    //
                    progressHandler = { [weak self_] (progress: Progress) in
                        if let self_ = self_ {
                            self_._machine.handleProgress(progress)
                        }
                    }
                    
                    fulfillHandler = { [weak self_] (value: Value) in
                        if let self_ = self_ {
                            self_._machine.handleFulfill(value)
                        }
                    }
                    
                    rejectInfoHandler = { [weak self_] (errorInfo: ErrorInfo) in
                        if let self_ = self_ {
                            self_._machine.handleRejectInfo(errorInfo)
                        }
                    }
                }
                else {
                    //
                    // NOTE:
                    // When `weakified = false`,
                    // each handler will capture `self_` (strongSelf on 1st resume)
                    // so that it will live until fulfilled/rejected.
                    //
                    progressHandler = { (progress: Progress) in
                        self_._machine.handleProgress(progress)
                    }
                    
                    fulfillHandler = { (value: Value) in
                        self_._machine.handleFulfill(value)
                    }
                    
                    rejectInfoHandler = { (errorInfo: ErrorInfo) in
                        self_._machine.handleRejectInfo(errorInfo)
                    }
                }
            
                _initClosure(machine: self_._machine, progress: progressHandler, fulfill: fulfillHandler, _reject: rejectInfoHandler, configure: self_._machine.configuration)
                
            }
        
        }
        
        if !paused {
            self.resume()
        }
    }
    
    deinit
    {
//        #if DEBUG
//            println("[deinit] \(self.name)")
//        #endif
        
        // cancel in case machine is still running
        self._cancel(error: nil)
    }
    
    /// Sets task name (method chainable)
    public func name(name: String) -> Self
    {
        self.name = name
        return self
    }
    
    /// Creates cloned task.
    public func clone() -> Task
    {
        let clonedTask = Task(weakified: self._weakified, paused: self._paused, _initClosure: self._initClosure)
        clonedTask.name = "\(self.name)-clone"
        return clonedTask
    }
    
    /// Returns new task that is retryable for `maxTryCount-1` times.
    public func try(maxTryCount: Int) -> Task
    {
        if maxTryCount < 2 { return self }
        
        return Task { machine, progress, fulfill, _reject, configure in
            
            let task = self.progress { _, progressValue in
                progress(progressValue)
            }.failure { [unowned self] _ -> Task in
                return self.clone().try(maxTryCount-1) // clone & try recursively
            }
                
            task.progress { _, progressValue in
                progress(progressValue) // also receive progresses from clone-try-task
            }.success { value -> Void in
                fulfill(value)
            }.failure { errorInfo -> Void in
                _reject(errorInfo)
            }
            
            configure.pause = {
                self.pause()
                task.pause()
            }
            configure.resume = {
                self.resume()
                task.resume()
            }
            configure.cancel = {
                task.cancel()   // cancel downstream first
                self.cancel()
            }
            
        }.name("\(self.name)-try(\(maxTryCount))")
    }
    
    ///
    /// Add progress handler delivered from `initClosure`'s `progress()` argument.
    ///
    /// - e.g. task.progress { oldProgress, newProgress in ... }
    ///
    /// NOTE: `oldProgress` is always nil when `weakified = true`
    ///
    public func progress(progressClosure: ProgressTuple -> Void) -> Task
    {
        self._machine.progressTupleHandlers.append(progressClosure)
        
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
        return Task<Progress2, Value2, Error> { [unowned self] newMachine, progress, fulfill, _reject, configure in
            
            //
            // NOTE: 
            // We split `self` (Task) and `self.machine` (StateMachine) separately to
            // let `completionHandler` retain `selfMachine` instead of `self`
            // so that `selfMachine`'s `completionHandlers` can be invoked even though `self` is deinited.
            // This is especially important for ReactKit's `deinitSignal` behavior.
            //
            let selfMachine = self._machine

            self._then {
                let innerTask = thenClosure(selfMachine.value, selfMachine.errorInfo)
                _bindInnerTask(innerTask, newMachine, progress, fulfill, _reject, configure)
            }
            
        }.name("\(self.name)-then")
    }

    /// invokes `completionHandler` "now" or "in the future"
    private func _then(completionHandler: Void -> Void)
    {
        switch self.state {
            case .Fulfilled, .Rejected, .Cancelled:
                completionHandler()
            default:
                self._machine.completionHandlers.append(completionHandler)
        }
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
        return Task<Progress2, Value2, Error> { [unowned self] newMachine, progress, fulfill, _reject, configure in
            
            let selfMachine = self._machine
            
            // NOTE: using `self._then()` + `selfMachine` instead of `self.then()` will reduce Task allocation
            self._then {
                if let value = selfMachine.value {
                    let innerTask = successClosure(value)
                    _bindInnerTask(innerTask, newMachine, progress, fulfill, _reject, configure)
                }
                else if let errorInfo = selfMachine.errorInfo {
                    _reject(errorInfo)
                }
            }
            
        }.name("\(self.name)-success")
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
    public func failure<Progress2>(failureClosure: ErrorInfo -> Task<Progress2, Value, Error>) -> Task<Progress2, Value, Error>
    {
        return Task<Progress2, Value, Error> { [unowned self] newMachine, progress, fulfill, _reject, configure in
            
            let selfMachine = self._machine
            
            self._then {
                if let value = selfMachine.value {
                    fulfill(value)
                }
                else if let errorInfo = selfMachine.errorInfo {
                    let innerTask = failureClosure(errorInfo)
                    _bindInnerTask(innerTask, newMachine, progress, fulfill, _reject, configure)
                }
            }
            
        }.name("\(self.name)-failure")
    }
    
    public func pause() -> Bool
    {
        return self._machine.handlePause()
    }
    
    public func resume() -> Bool
    {
        //
        // Always try `_performInitClosure` only once on `resume()`
        // even when `.Pause => .Resume` transition fails, e.g. already been fulfilled/rejected.
        //
        // NOTE:
        // **`downstream._performInitClosure` should be invoked first before `downstream.machine <-! .Resume`**
        // to add upstream's progress/fulfill/reject handlers inside `downstream.initClosure()` 
        // before their actual calls, which often happens 
        // when downstream's `resume()` is configured to call upstream's `resume()`
        // which eventually calls `upstream._performInitClosure` and thus actual event handlers.
        //
        if (self._performInitClosure != nil) {
            
            let isPaused = (self.state == .Paused)
            
            //
            // Temporarily switch to `.Running` without invoking `configure.resume()`.
            // This allows paused-inited-task to safely call progress/fulfill/reject handlers
            // inside its `initClosure` *immediately*.
            //
            if isPaused {
                self._machine.state = .Running  // switch temporarily
            }
            
            self._performInitClosure?()
            self._performInitClosure = nil
            
            // switch back to `.Paused` only if temporary `.Running` has not changed
            // (NOTE: `_performInitClosure` sometimes invokes `initClosure`'s `fulfill()`/`reject()` immediately)
            if isPaused && self.state == .Running {
                self._machine.state = .Paused   // switch back
            }
        }
        
        return self._machine.handleResume()
    }
    
    public func cancel(error: Error? = nil) -> Bool
    {
        return self._cancel(error: error)
    }
    
    internal func _cancel(error: Error? = nil) -> Bool
    {
        return self._machine.handleCancel(error: error)
    }
}

// MARK: - Helper

internal func _bindInnerTask<Progress2, Value2, Error>(
    innerTask: Task<Progress2, Value2, Error>,
    newMachine: _StateMachine<Progress2, Value2, Error>,
    progress: Task<Progress2, Value2, Error>.ProgressHandler,
    fulfill: Task<Progress2, Value2, Error>.FulfillHandler,
    _reject: Task<Progress2, Value2, Error>._RejectInfoHandler,
    configure: TaskConfiguration
    )
{
    switch innerTask.state {
        case .Fulfilled:
            fulfill(innerTask.value!)
            return
        case .Rejected, .Cancelled:
            _reject(innerTask.errorInfo!)
            return
        default:
            break
    }
    
    innerTask.progress { _, progressValue in
        progress(progressValue)
    }.then { (value: Value2?, errorInfo: Task<Progress2, Value2, Error>.ErrorInfo?) -> Void in
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
    if newMachine.state == .Paused {
        innerTask.pause()
    }
    else if newMachine.state == .Cancelled {
        innerTask.cancel()
    }
}

// MARK: - Multiple Tasks

extension Task
{
    public typealias BulkProgress = (completedCount: Int, totalCount: Int)
    
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
            
        }.name("Task.all")
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
            
        }.name("Task.any")
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
            
        }.name("Task.some")
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