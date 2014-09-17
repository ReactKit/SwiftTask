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
    
    public static func convertFromNilLiteral() -> TaskState
    {
        return Any
    }
    
    public var description: String
    {
        return self.toRaw()
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
    
    public static func convertFromNilLiteral() -> TaskEvent
    {
        return Any
    }
    
    public var description: String
    {
        return self.toRaw()
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
    
    public typealias BulkProgress = (completedCount: Int, totalCount: Int)
    
    public typealias PromiseInitClosure = (fulfill: FulFillHandler, reject: RejectHandler) -> Void
    public typealias InitClosure = (progress: ProgressHandler, fulfill: FulFillHandler, reject: RejectHandler, configure: TaskConfiguration) -> Void
    
    internal typealias _RejectHandler = (ErrorInfo) -> Void
    internal typealias _InitClosure = (progress: ProgressHandler, fulfill: FulFillHandler, _reject: _RejectHandler, configure: TaskConfiguration) -> Void
    
    internal typealias Machine = StateMachine<TaskState, TaskEvent>
    
    internal var machine: Machine!

    public internal(set) var progress: Progress?
    public internal(set) var value: Value?
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
    
    public convenience init(closure: PromiseInitClosure)
    {
        self.init(closure: { (progress, fulfill, reject, configure) in
            closure(fulfill: fulfill, reject: { (error: Error) in reject(error) })
            return
        })
    }
    
    public init(closure: InitClosure)
    {
        setup { (progress, fulfill, _reject: ErrorInfo -> Void, configure) in
            // NOTE: don't expose rejectHandler with ErrorInfo (isCancelled) for public init
            closure(progress: progress, fulfill: fulfill, reject: { (error: Error?) in _reject(ErrorInfo(error: error, isCancelled: false)) }, configure: configure)
            return
        }
    }
    
    public convenience init(value: Value)
    {
        self.init(closure: { (progress, fulfill, reject, configure) in
            fulfill(value)
            return
        })
    }
    
    public convenience init(error: Error)
    {
        self.init(closure: { (progress, fulfill, reject, configure) in
            reject(error)
            return
        })
    }
    
    internal init(_closure: _InitClosure)
    {
        setup(_closure)
    }
    
    internal func setup(_closure: _InitClosure)
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
            if let progress = context.userInfo as? Progress {
                self!.progress = progress
            }
        }
        // NOTE: use order < 100 (default) to let fulfillHandler be invoked after setting value
        self.machine.addEventHandler(.Fulfill, order: 90) { [weak self] context in
            if let value = context.userInfo as? Value {
                self!.value = value
            }
            configuration.clear()
        }
        self.machine.addEventHandler(.Reject, order: 90) { [weak self] context in
            if let errorInfo = context.userInfo as? ErrorInfo {
                self!.errorInfo = errorInfo
                configuration.cancel?() // NOTE: call configured cancellation on reject as well
            }
            configuration.clear()
        }
        
        let progressHandler: ProgressHandler = { [weak self] (progress: Progress) in
            if let self_ = self {
                self_.machine <-! (.Progress, progress)
            }
        }
        
        let fulfillHandler: FulFillHandler = { /*[weak self]*/ (value: Value) in
            self.machine <-! (.Fulfill, value)     // NOTE: capture self
            return
        }
        
        let rejectHandler: _RejectHandler = { /*[weak self]*/ (errorInfo: ErrorInfo) in
            self.machine <-! (.Reject, errorInfo)  // NOTE: capture self
            return
        }
        
        _closure(progress: progressHandler, fulfill: fulfillHandler, _reject: rejectHandler, configure: configuration)
        
    }
    
//    deinit
//    {
//        println("deinit: \(self)")
//    }
    
    public func progress(progressClosure: Progress -> Void) -> Task
    {
        self.machine.addEventHandler(.Progress) { [weak self] context in
            if let progress = context.userInfo as? Progress {
                progressClosure(progress)
            }
        }
        
        return self
    }
    
    /// then (fulfilled & rejected) + returning value
    public func then<Value2>(thenClosure: (Value?, ErrorInfo?) -> Value2) -> Task<Progress, Value2, Error>
    {
        return self.then { (value: Value?, errorInfo: ErrorInfo?) -> Task<Progress, Value2, Error> in
            return Task<Progress, Value2, Error>(value: thenClosure(value, errorInfo))
        }
    }
    
    /// then (fulfilled & rejected) + returning task
    public func then<Progress2, Value2>(thenClosure: (Value?, ErrorInfo?) -> Task<Progress2, Value2, Error>) -> Task<Progress2, Value2, Error>
    {
        let newTask = Task<Progress2, Value2, Error> { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            let bind = { (value: Value?, errorInfo: ErrorInfo?) -> Void in
                let innerTask = thenClosure(value, errorInfo)
                
                // NOTE: don't call then/catch for innerTask, or recursive bindings may occur
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
            
            switch self!.machine.state {
                case .Fulfilled:
                    bind(self!.value!, nil)
                case .Rejected:
                    bind(nil, self!.errorInfo!)
                default:
                    self!.machine.addEventHandler(.Fulfill) { context in
                        if let value = context.userInfo as? Value {
                            bind(value, nil)
                        }
                    }
                    self!.machine.addEventHandler(.Reject) { context in
                        if let errorInfo = context.userInfo as? ErrorInfo {
                            bind(nil, errorInfo)
                        }
                    }
            }
            
        }
        
        return newTask
    }
    
    /// then (fulfilled only) + returning value
    public func then<Value2>(fulfilledClosure: Value -> Value2) -> Task<Progress, Value2, Error>
    {
        return self.then { (value: Value) -> Task<Progress, Value2, Error> in
            return Task<Progress, Value2, Error>(value: fulfilledClosure(value))
        }
    }
    
    /// then (fulfilled only) + returning task
    public func then<Progress2, Value2>(fulfilledClosure: Value -> Task<Progress2, Value2, Error>) -> Task<Progress2, Value2, Error>
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
            
            switch self!.machine.state {
                case .Fulfilled:
                    bind(self!.value!)
                case .Rejected:
                    _reject(self!.errorInfo!)
                default:
                    self!.machine.addEventHandler(.Fulfill) { context in
                        if let value = context.userInfo as? Value {
                            bind(value)
                        }
                    }
                    self!.machine.addEventHandler(.Reject) { context in
                        if let errorInfo = context.userInfo as? ErrorInfo {
                            _reject(errorInfo)
                        }
                    }
            }
            
        }
        
        return newTask
    }
    
    /// catch + returning value
    public func catch(catchClosure: ErrorInfo -> Value) -> Task
    {
        return self.catch { (errorInfo: ErrorInfo) -> Task in
            return Task(value: catchClosure(errorInfo))
        }
    }

    /// catch + returning task
    public func catch(catchClosure: ErrorInfo -> Task) -> Task
    {
        let newTask = Task { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            let bind = { (errorInfo: ErrorInfo) -> Void in
                let innerTask = catchClosure(errorInfo)
                
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
            
            switch self!.machine.state {
                case .Fulfilled:
                    fulfill(self!.value!)
                case .Rejected:
                    let errorInfo = self!.errorInfo!
                    bind(errorInfo)
                default:
                    self!.machine.addEventHandler(.Fulfill) { context in
                        if let value = context.userInfo as? Value {
                            fulfill(value)
                        }
                    }
                    self!.machine.addEventHandler(.Reject) { context in
                        if let errorInfo = context.userInfo as? ErrorInfo {
                            bind(errorInfo)
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
                task.then { (value: Value) -> Void in
                    
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
                    
                }.catch { (errorInfo: ErrorInfo) -> Void in
                    
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
                task.then { (value: Value) -> Void in
                    
                    synchronized(self) {
                        completedCount++
                        
                        if completedCount == 1 {
                            fulfill(value)
                            
                            self.cancelAll(tasks)
                        }
                    }
                    
                }.catch { (errorInfo: ErrorInfo) -> Void in
                    
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
    /// This new task will NEVER be internally rejected (thus uncatchable from outside).
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
    
    internal class func cancelAll(tasks: [Task])
    {
        for task in tasks {
            task.cancel()
        }
    }
    
    internal class func pauseAll(tasks: [Task])
    {
        for task in tasks {
            task.pause()
        }
    }
    
    internal class func resumeAll(tasks: [Task])
    {
        for task in tasks {
            task.resume()
        }
    }
}

//--------------------------------------------------
// MARK: - Custom Operators
//--------------------------------------------------

// then (fulfilled & rejected)
infix operator >>> { associativity left }

public func >>> <P, V1, V2, E>(left: Task<P, V1, E>, right: (V1?, (E?, Bool)?) -> V2) -> Task<P, V2, E>
{
    return left.then(right)
}

public func >>> <P1, V1, P2, V2, E>(left: Task<P1, V1, E>, right: (V1?, (E?, Bool)?) -> Task<P2, V2, E>) -> Task<P2, V2, E>
{
    return left.then(right)
}

// then (fulfilled only)
infix operator *** { associativity left }

public func *** <P, V1, V2, E>(left: Task<P, V1, E>, right: V1 -> V2) -> Task<P, V2, E>
{
    return left.then(right)
}

public func *** <P1, V1, P2, V2, E>(left: Task<P1, V1, E>, right: V1 -> Task<P2, V2, E>) -> Task<P2, V2, E>
{
    return left.then(right)
}

// catch (rejected only)
infix operator !!! { associativity left }

public func !!! <P, V, E>(left: Task<P, V, E>, right: (E?, Bool) -> V) -> Task<P, V, E>
{
    return left.catch(right)
}

public func !!! <P, V, E>(left: Task<P, V, E>, right: (E?, Bool) -> Task<P, V, E>) -> Task<P, V, E>
{
    return left.catch(right)
}

// progress
infix operator ~ { associativity left }

public func ~ <P, V, E>(left: Task<P, V, E>, right: P -> Void) -> Task<P, V, E>
{
    return left.progress(right)
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