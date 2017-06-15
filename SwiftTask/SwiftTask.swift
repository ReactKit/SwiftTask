//
//  SwiftTask.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

// Required for use in the playground Sources folder
import ObjectiveC

public enum TaskState: String {
    case paused = "Paused"
    case running = "Running"
    case fulfilled = "Fulfilled"
    case rejected = "Rejected"
    case cancelled = "Cancelled"
}

// NOTE: use class instead of struct to pass reference to `initClosure` to set `pause`/`resume`/`cancel` closures
public class TaskConfiguration {
    public var pause: (() -> Void)?
    public var resume: (() -> Void)?
    public var cancel: (() -> Void)?
    
    /// useful to terminate immediate-infinite-sequence while performing `initClosure`
    public var isFinished: Bool {
        return finished.rawValue
    }
    
    private var finished = Atomic(false)
    
    func finish() {
        cancel?()
        pause = nil
        resume = nil
        cancel = nil
        finished.rawValue = true
    }
}

open class Task<Progress, Value, Error> {
    public typealias ProgressTuple = (oldProgress: Progress?, newProgress: Progress)
    public typealias ErrorInfo = (error: Error?, isCancelled: Bool)
    public typealias ProgressHandler = (Progress) -> Void
    public typealias FulfillHandler = (Value) -> Void
    public typealias RejectHandler = (Error) -> Void
    public typealias Configuration = TaskConfiguration
    public typealias PromiseInitClosure = (_ fulfill: @escaping FulfillHandler, _ reject: @escaping RejectHandler) -> Void
    public typealias InitClosure = (_ progress: @escaping ProgressHandler, _ fulfill: @escaping FulfillHandler, _ reject: @escaping RejectHandler, _ configure:  TaskConfiguration) -> Void
    public typealias BulkProgress = (completedCount: Int, totalCount: Int)
    
    typealias Machine = StateMachine<Progress, Value, Error>
    typealias MachineInitClosure = (_ machine: Machine, _ progress: @escaping ProgressHandler, _ fulfill: @escaping FulfillHandler, _ reject: @escaping RejectInfoHandler, _ configure: TaskConfiguration) -> Void
    typealias ProgressTupleHandler = (ProgressTuple) -> Void
    typealias RejectInfoHandler = (ErrorInfo) -> Void
    
    public var state: TaskState {
        return machine.state.rawValue
    }
    
    /// progress value (NOTE: always nil when `weakified = true`)
    public var progress: Progress? {
        return machine.progress.rawValue
    }
    
    /// fulfilled value
    public var value: Value? {
        return machine.value.rawValue
    }
    
    /// rejected/cancelled tuple info
    public var errorInfo: ErrorInfo? {
        return machine.errorInfo.rawValue
    }
    
    public var name: String = "DefaultTask"
    
    var initClosure: MachineInitClosure!    // retained throughout task's lifetime
    
    let machine: Machine
    let weakified: Bool
    let paused: Bool
    
    ///
    /// Create a new task.
    ///
    /// - e.g. Task<P, V, E>(weakified: false, paused: false) { progress, fulfill, reject, configure in ... }
    ///
    /// - Parameter weakified: Weakifies progress/fulfill/reject handlers to let player (inner asynchronous implementation inside `initClosure`) NOT CAPTURE this created new task. Normally, `weakified = false` should be set to gain "player -> task" retaining, so that task will be automatically deinited when player is deinited. If `weakified = true`, task must be manually retained somewhere else, or it will be immediately deinited.
    ///
    /// - Parameter paused: Flag to invoke `initClosure` immediately or not. If `paused = true`, task's initial state will be `.Paused` and needs to `resume()` in order to start `.Running`. If `paused = false`, `initClosure` will be invoked immediately.
    ///
    /// - Parameter initClosure: e.g. { progress, fulfill, reject, configure in ... }. `fulfill(value)` and `reject(error)` handlers must be called inside this closure, where calling `progress(progressValue)` handler is optional. Also as options, `configure.pause`/`configure.resume`/`configure.cancel` closures can be set to gain control from outside e.g. `task.pause()`/`task.resume()`/`task.cancel()`. When using `configure`, make sure to use weak modifier when appropriate to avoid "task -> player" retaining which often causes retain cycle.
    ///
    /// - Returns: New task.
    ///
    public init(weakified: Bool, paused: Bool, initClosure: @escaping InitClosure) {
        self.weakified = weakified
        self.paused = paused
        self.machine = Machine(weakified: weakified, paused: paused)
        
        let initClosure: MachineInitClosure = { _, progress, fulfill, reject, configure in
            // NOTE: don't expose rejectHandler with ErrorInfo (isCancelled) for public init
            initClosure(progress, fulfill, { error in reject(ErrorInfo(error: Optional(error), isCancelled: false)) }, configure)
        }
        
        setup(weakified: weakified, paused: paused, initClosure: initClosure)
    }
    
    ///
    /// Create a new task without weakifying progress/fulfill/reject handlers
    ///
    /// - e.g. Task<P, V, E>(paused: false) { progress, fulfill, reject, configure in ... }
    ///
    public convenience init(paused: Bool, initClosure: @escaping InitClosure) {
        self.init(weakified: false, paused: paused, initClosure: initClosure)
    }
    
    ///
    /// Create a new task without weakifying progress/fulfill/reject handlers (non-paused)
    ///
    /// - e.g. Task<P, V, E> { progress, fulfill, reject, configure in ... }
    ///
    public convenience init(initClosure: @escaping InitClosure) {
        self.init(weakified: false, paused: false, initClosure: initClosure)
    }
    
    ///
    /// Create fulfilled task (non-paused)
    ///
    /// - e.g. Task<P, V, E>(value: someValue)
    ///
    public convenience init(value: Value) {
        self.init { progress, fulfill, reject, configure in
            fulfill(value)
        }
        name = "FulfilledTask"
    }
    
    ///
    /// Create rejected task (non-paused)
    ///
    /// - e.g. Task<P, V, E>(error: someError)
    ///
    public convenience init(error: Error) {
        self.init { progress, fulfill, reject, configure in
            reject(error)
        }
        name = "RejectedTask"
    }
    
    ///
    /// Create promise-like task which only allows fulfill & reject (no progress & configure)
    ///
    /// - e.g. Task<Any, Value, Error> { fulfill, reject in ... }
    ///
    public convenience init(promiseInitClosure: @escaping PromiseInitClosure) {
        self.init { progress, fulfill, reject, configure in
            promiseInitClosure(fulfill, { error in reject(error) })
        }
    }
    
    /// internal-init for accessing `machine` inside `initClosure`
    /// (NOTE: initClosure has RejectInfoHandler as argument)
    init(weakified: Bool = false, paused: Bool = false, initClosure: @escaping MachineInitClosure) {
        self.weakified = weakified
        self.paused = paused
        self.machine = Machine(weakified: weakified, paused: paused)
        
        setup(weakified: weakified, paused: paused, initClosure: initClosure)
    }
    
    // NOTE: don't use `init` for this setup method, or this will be a designated initializer
    func setup(weakified: Bool, paused: Bool, initClosure: @escaping MachineInitClosure) {
        self.initClosure = initClosure
        
        // will be invoked on 1st resume (only once)
        machine.initResumeClosure.rawValue = { [weak self] in
            // strongify `self` on 1st resume
            if let strongSelf = self {
                var progressHandler: ProgressHandler
                var fulfillHandler: FulfillHandler
                var rejectInfoHandler: RejectInfoHandler
                
                if weakified {
                    //
                    // NOTE:
                    // When `weakified = true`,
                    // each handler will NOT capture `strongSelf` (strongSelf on 1st resume)
                    // so it will immediately deinit if not retained in somewhere else.
                    //
                    progressHandler = { [weak strongSelf] (progress: Progress) in
                        if let strongSelf = strongSelf {
                            strongSelf.machine.handleProgress(progress)
                        }
                    }
                    
                    fulfillHandler = { [weak strongSelf] (value: Value) in
                        if let strongSelf = strongSelf {
                            strongSelf.machine.handleFulfill(value)
                        }
                    }
                    
                    rejectInfoHandler = { [weak strongSelf] (errorInfo: ErrorInfo) in
                        if let strongSelf = strongSelf {
                            strongSelf.machine.handleRejectInfo(errorInfo)
                        }
                    }
                } else {
                    //
                    // NOTE:
                    // When `weakified = false`,
                    // each handler will capture `strongSelf` (strongSelf on 1st resume)
                    // so that it will live until fulfilled/rejected.
                    //
                    progressHandler = { (progress: Progress) in
                        strongSelf.machine.handleProgress(progress)
                    }
                    
                    fulfillHandler = { (value: Value) in
                        strongSelf.machine.handleFulfill(value)
                    }
                    
                    rejectInfoHandler = { (errorInfo: ErrorInfo) in
                        strongSelf.machine.handleRejectInfo(errorInfo)
                    }
                }
                
                initClosure(strongSelf.machine, progressHandler, fulfillHandler, rejectInfoHandler, strongSelf.machine.configuration)
            }
        }
        
        if !paused {
            resume()
        }
    }
    
    deinit {
        // cancel in case machine is still running
        cancel(error: nil)
    }
    
    /// Sets task name (method chainable)
    public func name(_ name: String) -> Self {
        self.name = name
        return self
    }
    
    /// Creates cloned task.
    public func clone() -> Task {
        let clonedTask = Task(weakified: weakified, paused: paused, initClosure: initClosure)
        clonedTask.name = "\(name)-clone"
        return clonedTask
    }
    
    /// Returns new task that is retryable for `maxRetryCount (= maxTryCount-1)` times.
    public func retry(_ maxRetryCount: Int) -> Task {
        guard maxRetryCount >= 0 else { return self }
        
        return Task { machine, progress, fulfill, reject, configure in
            let task = self.progress {
                let (_, progressValue) = $0
                progress(progressValue)
            }.failure { [unowned self] _ -> Task in
                return self.clone().retry(maxRetryCount-1) // clone & try recursively
            }
                
            task.progress {
                let (_, progressValue) = $0
                progress(progressValue) // also receive progresses from clone-try-task
            }.success { value -> Void in
                fulfill(value)
            }.failure { errorInfo -> Void in
                reject(errorInfo)
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
        }.name("\(name)-try(\(maxRetryCount))")
    }
    
    ///
    /// Add progress handler delivered from `initClosure`'s `progress()` argument.
    ///
    /// - e.g. task.progress { oldProgress, newProgress in ... }
    ///
    /// - Note: `oldProgress` is always nil when `weakified = true`
    /// - Returns: Self (same `Task`)
    ///
    @discardableResult public func progress(progressClosure: @escaping (ProgressTuple) -> Void) -> Self {
        var dummyCanceller: Canceller? = nil
        return progress(&dummyCanceller, progressClosure)
    }
    
    public func progress<C: Canceller>(_ canceller: inout C?, _ progressClosure: @escaping (ProgressTuple) -> Void) -> Self {
        var token: HandlerToken? = nil
        machine.addProgressTupleHandler(&token, progressClosure)
        let finishedToken = token
        
        canceller = C { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.machine.removeProgressTupleHandler(finishedToken)
        }
        
        return self
    }
    
    ///
    /// `then` (fulfilled & rejected) + closure returning **value**.
    /// (similar to `map` in functional programming)
    ///
    /// - e.g. task.then { value, errorInfo -> NextValueType in ... }
    ///
    /// - Returns: New `Task`
    ///
    @discardableResult public func then<Value2>(thenClosure: @escaping (Value?, ErrorInfo?) -> Value2) -> Task<Progress, Value2, Error> {
        var dummyCanceller: Canceller? = nil
        return then(&dummyCanceller, thenClosure)
    }
    
    public func then<Value2, C: Canceller>(_ canceller: inout C?, _ thenClosure: @escaping (Value?, ErrorInfo?) -> Value2) -> Task<Progress, Value2, Error> {
        return then(&canceller) { (value, errorInfo) -> Task<Progress, Value2, Error> in
            return Task<Progress, Value2, Error>(value: thenClosure(value, errorInfo))
        }
    }
    
    ///
    /// `then` (fulfilled & rejected) + closure returning **task**.
    /// (similar to `flatMap` in functional programming)
    ///
    /// - e.g. task.then { value, errorInfo -> NextTaskType in ... }
    ///
    /// - Returns: New `Task`
    ///
    public func then<Progress2, Value2, Error2>(thenClosure: @escaping (Value?, ErrorInfo?) -> Task<Progress2, Value2, Error2>) -> Task<Progress2, Value2, Error2> {
        var dummyCanceller: Canceller? = nil
        return then(&dummyCanceller, thenClosure)
    }
    
    //
    // NOTE: then-canceller is a shorthand of `task.cancel(nil)`, i.e. these two are the same:
    //
    // - `let canceller = Canceller(); task1.then(&canceller) {...}; canceller.cancel();`
    // - `let task2 = task1.then {...}; task2.cancel();`
    //
    /// - Returns: New `Task`
    ///
    public func then<Progress2, Value2, Error2, C: Canceller>(_ canceller: inout C?, _ thenClosure: @escaping (Value?, ErrorInfo?) -> Task<Progress2, Value2, Error2>) -> Task<Progress2, Value2, Error2> {
        return Task<Progress2, Value2, Error2> { [unowned self, weak canceller] newMachine, progress, fulfill, reject, configure in
            //
            // NOTE: 
            // We split `self` (Task) and `self.machine` (StateMachine) separately to
            // let `completionHandler` retain `selfMachine` instead of `self`
            // so that `selfMachine`'s `completionHandlers` can be invoked even though `self` is deinited.
            // This is especially important for ReactKit's `deinitSignal` behavior.
            //
            let selfMachine = self.machine
            
            self.then(&canceller) {
                let innerTask = thenClosure(selfMachine.value.rawValue, selfMachine.errorInfo.rawValue)
                bindInnerTask(innerTask, newMachine, progress, fulfill, reject, configure)
            }
        }.name("\(name)-then")
    }
    
    ///
    /// `success` (fulfilled) + closure returning **value**.
    /// (synonym for `map` in functional programming)
    ///
    /// - e.g. task.success { value -> NextValueType in ... }
    ///
    /// - Returns: New `Task`
    ///
    @discardableResult public func success<Value2>(successClosure: @escaping (Value) -> Value2) -> Task<Progress, Value2, Error> {
        var dummyCanceller: Canceller? = nil
        return success(&dummyCanceller, successClosure)
    }
    
    public func success<Value2, C: Canceller>(_ canceller: inout C?, _ successClosure: @escaping (Value) -> Value2) -> Task<Progress, Value2, Error> {
        return success(&canceller) { (value: Value) -> Task<Progress, Value2, Error> in
            Task<Progress, Value2, Error>(value: successClosure(value))
        }
    }
    
    ///
    /// `success` (fulfilled) + closure returning **task**
    /// (synonym for `flatMap` in functional programming)
    ///
    /// - e.g. task.success { value -> NextTaskType in ... }
    ///
    /// - Returns: New `Task`
    ///
    public func success<Progress2, Value2, Error2>(successClosure: @escaping (Value) -> Task<Progress2, Value2, Error2>) -> Task<Progress2, Value2, Error> {
        var dummyCanceller: Canceller? = nil
        return success(&dummyCanceller, successClosure)
    }
    
    public func success<Progress2, Value2, Error2, C: Canceller>(_ canceller: inout C?, _ successClosure: @escaping (Value) -> Task<Progress2, Value2, Error2>) -> Task<Progress2, Value2, Error> {
        var localCanceller = canceller; defer { canceller = localCanceller }
        return Task<Progress2, Value2, Error> { [unowned self] newMachine, progress, fulfill, reject, configure in
            let selfMachine = self.machine
            
            // NOTE: using `self.then()` + `selfMachine` instead of `self.then()` will reduce Task allocation
            self.then(&localCanceller) {
                if let value = selfMachine.value.rawValue {
                    let innerTask = successClosure(value)
                    bindInnerTask(innerTask, newMachine, progress, fulfill, reject, configure)
                }
                else if let errorInfo = selfMachine.errorInfo.rawValue {
                    reject(errorInfo)
                }
            }
        }.name("\(name)-success")
    }
    
    ///
    /// `failure` (rejected or cancelled) + closure returning **value**.
    /// (synonym for `mapError` in functional programming)
    ///
    /// - e.g. task.failure { errorInfo -> NextValueType in ... }
    /// - e.g. task.failure { error, isCancelled -> NextValueType in ... }
    ///
    /// - Returns: New `Task`
    ///
    @discardableResult public func failure(failureClosure: @escaping (ErrorInfo) -> Value) -> Task {
        var dummyCanceller: Canceller? = nil
        return failure(&dummyCanceller, failureClosure)
    }
    
    public func failure<C: Canceller>(_ canceller: inout C?, _ failureClosure: @escaping (ErrorInfo) -> Value) -> Task {
        return failure(&canceller) { (errorInfo: ErrorInfo) -> Task in
            return Task(value: failureClosure(errorInfo))
        }
    }

    ///
    /// `failure` (rejected or cancelled) + closure returning **task**.
    /// (synonym for `flatMapError` in functional programming)
    ///
    /// - e.g. task.failure { errorInfo -> NextTaskType in ... }
    /// - e.g. task.failure { error, isCancelled -> NextTaskType in ... }
    ///
    /// - Returns: New `Task`
    ///
    public func failure<Progress2, Error2>(failureClosure: @escaping (ErrorInfo) -> Task<Progress2, Value, Error2>) -> Task<Progress2, Value, Error2> {
        var dummyCanceller: Canceller? = nil
        return failure(&dummyCanceller, failureClosure)
    }
    
    public func failure<Progress2, Error2, C: Canceller>(_ canceller: inout C?, _ failureClosure: @escaping (ErrorInfo) -> Task<Progress2, Value, Error2>) -> Task<Progress2, Value, Error2> {
        var localCanceller = canceller; defer { canceller = localCanceller }
        return Task<Progress2, Value, Error2> { [unowned self] newMachine, progress, fulfill, reject, configure in
            let selfMachine = self.machine
            
            self.then(&localCanceller) {
                if let value = selfMachine.value.rawValue {
                    fulfill(value)
                } else if let errorInfo = selfMachine.errorInfo.rawValue {
                    let innerTask = failureClosure(errorInfo)
                    bindInnerTask(innerTask, newMachine, progress, fulfill, reject, configure)
                }
            }
        }.name("\(name)-failure")
    }
    
    ///
    /// Add side-effects after completion.
    ///
    /// - Note: This method doesn't create new task, so it has better performance over `then()`/`success()`/`failure()`.
    /// - Returns: Self (same `Task`)
    ///
    @discardableResult public func on(success: ((Value) -> Void)? = nil, failure: ((ErrorInfo) -> Void)? = nil) -> Self {
        var dummyCanceller: Canceller? = nil
        return on(&dummyCanceller, success: success, failure: failure)
    }
    
    public func on<C: Canceller>(_ canceller: inout C?, success: ((Value) -> Void)? = nil, failure: ((ErrorInfo) -> Void)? = nil) -> Self {
        let selfMachine = machine
        
        then(&canceller) {
            if let value = selfMachine.value.rawValue {
                success?(value)
            } else if let errorInfo = selfMachine.errorInfo.rawValue {
                failure?(errorInfo)
            }
        }
        
        return self
    }
    
    /// Pause task.
    @discardableResult public func pause() -> Bool {
        return machine.handlePause()
    }
    
    /// Resume task.
    @discardableResult public func resume() -> Bool {
        return machine.handleResume()
    }
    
    public class func all(_ tasks: [Task]) -> Task<BulkProgress, [Value], Error> {
        guard !tasks.isEmpty else {
            return Task<BulkProgress, [Value], Error>(value: [])
        }
        
        return Task<BulkProgress, [Value], Error> { machine, progress, fulfill, reject, configure in
            var completedCount = 0
            let totalCount = tasks.count
            let lock = RecursiveLock()
            let cancelled = Atomic(false)
            
            for task in tasks {
                task.success { value in
                    lock.lock()
                    completedCount += 1
                    
                    let progressTuple = BulkProgress(completedCount: completedCount, totalCount: totalCount)
                    progress(progressTuple)
                    
                    if completedCount == totalCount {
                        var values: [Value] = Array()
                        
                        for task in tasks {
                            values.append(task.value!)
                        }
                        
                        fulfill(values)
                    }
                    lock.unlock()
                }.failure { errorInfo in
                    let changed = cancelled.updateIf { $0 == false ? true : nil }
                    
                    if changed != nil {
                        lock.lock()
                        reject(errorInfo)
                        
                        for task in tasks {
                            task.cancel()
                        }
                        lock.unlock()
                    }
                }
            }
            
            configure.pause = { self.pauseAll(tasks); return }
            configure.resume = { self.resumeAll(tasks); return }
            configure.cancel = {
                if !cancelled.rawValue {
                    self.cancelAll(tasks);
                }
            }
        }.name("Task.all")
    }
    
    public class func any(_ tasks: [Task]) -> Task {
        return Task<Progress, Value, Error> { machine, progress, fulfill, reject, configure in
            var completedCount = 0
            var rejectedCount = 0
            let totalCount = tasks.count
            let lock = RecursiveLock()
            
            for task in tasks {
                task.success { value in
                    lock.lock()
                    completedCount += 1
                    
                    if completedCount == 1 {
                        fulfill(value)
                        self.cancelAll(tasks)
                    }
                    lock.unlock()
                }.failure { errorInfo in
                    lock.lock()
                    rejectedCount += 1
                    
                    if rejectedCount == totalCount {
                        let isAnyCancelled = (tasks.filter { task in task.state == .cancelled }.count > 0)
                        
                        let errorInfo = ErrorInfo(error: nil, isCancelled: isAnyCancelled)  // NOTE: Task.any error returns nil (spec)
                        reject(errorInfo)
                    }
                    lock.unlock()
                }
            }
            
            configure.pause = { self.pauseAll(tasks); return }
            configure.resume = { self.resumeAll(tasks); return }
            configure.cancel = { self.cancelAll(tasks); return }
        }.name("Task.any")
    }
    
    /// Returns new task which performs all given tasks and stores only fulfilled values.
    /// This new task will NEVER be internally rejected.
    public class func some(_ tasks: [Task]) -> Task<BulkProgress, [Value], Error> {
        guard !tasks.isEmpty else {
            return Task<BulkProgress, [Value], Error>(value: [])
        }
        
        return Task<BulkProgress, [Value], Error> { machine, progress, fulfill, reject, configure in
            var completedCount = 0
            let totalCount = tasks.count
            let lock = RecursiveLock()
            
            for task in tasks {
                task.then { (value: Value?, errorInfo: ErrorInfo?) -> Void in
                    lock.lock()
                    completedCount += 1
                    
                    let progressTuple = BulkProgress(completedCount: completedCount, totalCount: totalCount)
                    progress(progressTuple)
                    
                    if completedCount == totalCount {
                        var values: [Value] = Array()
                        
                        for task in tasks {
                            if task.state == .fulfilled {
                                values.append(task.value!)
                            }
                        }
                        
                        fulfill(values)
                    }
                    lock.unlock()
                }
            }
            
            configure.pause = { self.pauseAll(tasks); return }
            configure.resume = { self.resumeAll(tasks); return }
            configure.cancel = { self.cancelAll(tasks); return }
        }.name("Task.some")
    }
    
    public class func cancelAll(_ tasks: [Task]) {
        tasks.forEach { $0.cancel() }
    }
    
    public class func pauseAll(_ tasks: [Task]) {
        tasks.forEach { $0.pause() }
    }
    
    public class func resumeAll(_ tasks: [Task]) {
        tasks.forEach { $0.resume() }
    }
}

private func bindInnerTask<Progress2, Value2, Error, Error2>(_ innerTask: Task<Progress2, Value2, Error2>, _ newMachine: StateMachine<Progress2, Value2, Error>, _ progress: @escaping Task<Progress2, Value2, Error>.ProgressHandler, _ fulfill: @escaping Task<Progress2, Value2, Error>.FulfillHandler, _ reject: @escaping Task<Progress2, Value2, Error>.RejectInfoHandler, _ configure: TaskConfiguration) {
    switch innerTask.state {
        case .fulfilled:
            fulfill(innerTask.value!)
            return
        case .rejected, .cancelled:
            let (error2, isCancelled) = innerTask.errorInfo!
            
            // NOTE: innerTask's `error2` will be treated as `nil` if not same type as outerTask's `Error` type
            reject((error2 as? Error, isCancelled))
            return
        default:
            break
    }
    
    innerTask.progress {
        let (_, progressValue) = $0
        progress(progressValue)
    }.then { (value: Value2?, errorInfo2: Task<Progress2, Value2, Error2>.ErrorInfo?) -> Void in
        if let value = value {
            fulfill(value)
        }
        else if let errorInfo2 = errorInfo2 {
            let (error2, isCancelled) = errorInfo2
            
            // NOTE: innerTask's `error2` will be treated as `nil` if not same type as outerTask's `Error` type
            reject((error2 as? Error, isCancelled))
        }
    }
    
    configure.pause = { innerTask.pause(); return }
    configure.resume = { innerTask.resume(); return }
    configure.cancel = { innerTask.cancel(); return }
    
    // pause/cancel innerTask if descendant task is already paused/cancelled
    if newMachine.state.rawValue == .paused {
        innerTask.pause()
    } else if newMachine.state.rawValue == .cancelled {
        innerTask.cancel()
    }
}

extension Task: Cancellable {
    @discardableResult public func cancel(error: Error? = nil) -> Bool {
        return machine.handleCancel(error)
    }
}

extension Task: CustomStringConvertible {
    open var description: String {
        var valueString: String?
        
        switch state {
        case .fulfilled:
            valueString = "value=\(value!)"
        case .rejected, .cancelled:
            valueString = "errorInfo=\(errorInfo!)"
        default:
            valueString = "progress=\(String(describing: progress))"
        }
        
        return "<\(name); state=\(state.rawValue); \(valueString!))>"
    }
}

private extension Task {
    /// invokes `completionHandler` "now" or "in the future"
    func then<C: Canceller>(_ canceller: inout C?, _ completionHandler: @escaping () -> Void) {
        switch state {
        case .fulfilled, .rejected, .cancelled:
            completionHandler()
        default:
            var token: HandlerToken? = nil
            machine.addCompletionHandler(&token, completionHandler)
            
            canceller = C { [weak self] in
                self?.machine.removeCompletionHandler(token)
            }
        }
    }
}

extension TaskState: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}
