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

public class Task<Progress, Value, Error>
{
    public typealias ErrorInfo = (error: Error?, isCancelled: Bool)
    
    public typealias ProgressHandler = (Progress) -> Void
    public typealias FulFillHandler = (Value) -> Void
    public typealias RejectHandler = (Error) -> Void
    public typealias ConfigureHandler = (pause: (Void -> Void)?, resume: (Void -> Void)?, cancel: (Void -> Void)?)
    
    public typealias BulkProgress = (completedCount: Int, totalCount: Int)
    
    public typealias TaskClosure = (progress: ProgressHandler, fulfill: FulFillHandler, reject: RejectHandler, inout configure: ConfigureHandler) -> Void
    
    internal typealias _RejectHandler = (ErrorInfo) -> Void
    internal typealias _TaskClosure = (progress: ProgressHandler, fulfill: FulFillHandler, _reject: _RejectHandler, inout configure: ConfigureHandler) -> Void
    
    internal typealias Machine = StateMachine<TaskState, TaskEvent>
    
    internal let machine: Machine

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
    
    public convenience init(closure: TaskClosure)
    {
        self.init(_closure: { (progress, fulfill, _reject: ErrorInfo -> Void, configure) in
            // NOTE: don't expose rejectHandler with ErrorInfo (isCancelled) for public init
            closure(progress: progress, fulfill: fulfill, reject: { (error: Error?) in _reject(ErrorInfo(error: error, isCancelled: false)) }, configure: &configure)
            return
        })
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
    
    internal init(_closure: _TaskClosure)
    {
        var configureHandler: ConfigureHandler
        
        // setup state machine
        self.machine = Machine(state: .Running) {
            
            $0.addRouteEvent(.Pause, transitions: [.Running => .Paused])
            $0.addRouteEvent(.Resume, transitions: [.Paused => .Running])
            $0.addRouteEvent(.Progress, transitions: [.Running => .Running])
            $0.addRouteEvent(.Fulfill, transitions: [.Running => .Fulfilled])
            $0.addRouteEvent(.Reject, transitions: [.Running => .Rejected, .Paused => .Rejected])
            
            $0.addEventHandler(.Resume) { context in
                configureHandler.resume?()
                return
            }
            
            $0.addEventHandler(.Pause) { context in
                configureHandler.pause?()
                return
            }
            
        }
        
        // TODO: how to nest these inside StateMachine's initClosure?
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
        }
        self.machine.addEventHandler(.Reject, order: 90) { [weak self] context in
            if let errorInfo = context.userInfo as? ErrorInfo {
                self!.errorInfo = errorInfo
                configureHandler.cancel?() // NOTE: call configured cancellation on reject as well
            }
        }
        
        let progressHandler: ProgressHandler = { /*[weak self]*/ (progress: Progress) in
            self.machine <-! (.Progress, progress)  // NOTE: capture self
            return
        }
        
        let fulfillHandler: FulFillHandler = { /*[weak self]*/ (value: Value) in
            self.machine <-! (.Fulfill, value)     // NOTE: capture self
            return
        }
        
        let rejectHandler: _RejectHandler = { /*[weak self]*/ (errorInfo: ErrorInfo) in
            self.machine <-! (.Reject, errorInfo)  // NOTE: capture self
            return
        }

        _closure(progress: progressHandler, fulfill: fulfillHandler, _reject: rejectHandler, configure: &configureHandler)
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
    
    /// then + returning value
    public func then<Value2>(thenClosure: Value -> Value2) -> Task<Progress, Value2, Error>
    {
        let newTask = Task<Progress, Value2, Error> { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
        
            switch self!.machine.state {
                case .Fulfilled:
                    fulfill(thenClosure(self!.value!))
                case .Rejected:
                    _reject(self!.errorInfo!)
                default:
                    self!.machine.addEventHandler(.Fulfill) { context in
                        if let value = context.userInfo as? Value {
                            fulfill(thenClosure(value))
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
    
    /// then + returning task
    public func then<Progress2, Value2>(thenClosure: Value -> Task<Progress2, Value2, Error>) -> Task<Progress2, Value2, Error>
    {
        let newTask = Task<Progress2, Value2, Error> { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            switch self!.machine.state {
                case .Fulfilled:
                    thenClosure(self!.value!).then { (value: Value2) -> Void in
                        fulfill(value)
                    }.catch { (errorInfo: ErrorInfo) -> Void in
                        _reject(errorInfo)
                    }
                case .Rejected:
                    _reject(self!.errorInfo!)
                default:
                    self!.machine.addEventHandler(.Fulfill) { context in
                        if let value = context.userInfo as? Value {
                            thenClosure(value).then { (value: Value2) -> Void in
                                fulfill(value)
                            }.catch { (errorInfo: ErrorInfo) -> Void in
                                _reject(errorInfo)
                            }
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
        let newTask = Task { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            switch self!.machine.state {
                case .Fulfilled:
                    fulfill(self!.value!)
                case .Rejected:
                    fulfill(catchClosure(self!.errorInfo!))
                default:
                    self!.machine.addEventHandler(.Fulfill) { context in
                        if let value = context.userInfo as? Value {
                            fulfill(value)
                        }
                    }
                    self!.machine.addEventHandler(.Reject) { context in
                        if let errorInfo = context.userInfo as? ErrorInfo {
                            fulfill(catchClosure(errorInfo))
                        }
                    }
            }
            
        }
        
        return newTask
    }

    /// catch + returning task
    public func catch(catchClosure: ErrorInfo -> Task) -> Task
    {
        let newTask = Task { [weak self] (progress, fulfill, _reject: _RejectHandler, configure) in
            
            switch self!.machine.state {
                case .Fulfilled:
                    fulfill(self!.value!)
                case .Rejected:
                    catchClosure(self!.errorInfo!).then { (value: Value) -> Void in
                        fulfill(value)
                    }.catch { (errorInfo: ErrorInfo) -> Void in
                        _reject(errorInfo)
                    }
                default:
                    self!.machine.addEventHandler(.Fulfill) { context in
                        if let value = context.userInfo as? Value {
                            fulfill(value)
                        }
                    }
                    self!.machine.addEventHandler(.Reject) { context in
                        if let errorInfo = context.userInfo as? ErrorInfo {
                            catchClosure(errorInfo).then { (value: Value) -> Void in
                                fulfill(value)
                            }.catch { (errorInfo: ErrorInfo) -> Void in
                                _reject(errorInfo)
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
        return self.machine <-! (.Reject, ErrorInfo(error: error, isCancelled: true))
    }
    
}

extension Task
{
    public class func all(tasks: [Task]) -> Task<BulkProgress, [Value], Error>
    {
        return Task<BulkProgress, [Value], Error> { (progress, fulfill, _reject: _RejectHandler, configure) -> Void in
            
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
            
            configure.cancel = {
                self.cancelAll(tasks)
                return
            }
            configure.pause = {
                self.pauseAll(tasks)
                return
            }
            configure.resume = {
                self.resumeAll(tasks)
                return
            }
            
        }
    }
    
    public class func any(tasks: [Task]) -> Task
    {
        return Task<Progress, Value, Error> { (progress, fulfill, _reject: _RejectHandler, configure) -> Void in
            
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
            
            configure.cancel = {
                self.cancelAll(tasks)
                return
            }
            configure.pause = {
                self.pauseAll(tasks)
                return
            }
            configure.resume = {
                self.resumeAll(tasks)
                return
            }
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

infix operator => { associativity left precedence 255 }

public func => <P, V1, V2, E>(left: Task<P, V1, E>, right: V1 -> V2) -> Task<P, V2, E>
{
    return left.then(right)
}

public func => <P1, V1, P2, V2, E>(left: Task<P1, V1, E>, right: V1 -> Task<P2, V2, E>) -> Task<P2, V2, E>
{
    return left.then(right)
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