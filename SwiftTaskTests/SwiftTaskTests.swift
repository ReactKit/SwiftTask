//
//  SwiftTaskTests.swift
//  SwiftTaskTests
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

/// Safe background flag checking delay to not conflict with main-dispatch_after.
/// (0.3 may be still short for certain environment)
let SAFE_BG_FLAG_CHECK_DELAY = 0.5

class AsyncSwiftTaskTests: SwiftTaskTests
{
    override var isAsync: Bool { return true }
}

class SwiftTaskTests: _TestCase
{
    //--------------------------------------------------
    // MARK: - Init
    //--------------------------------------------------
    
    func testInit_value()
    {
        // NOTE: this is non-async test
        if self.isAsync { return }
        
        Task<Float, String, ErrorString>(value: "OK").onSuccess { (value: String) -> Void in
            XCTAssertEqual(value, "OK")
        }
    }
    
    func testInit_error()
    {
        // NOTE: this is non-async test
        if self.isAsync { return }
        
        Task<Float, String, ErrorString>(error: "ERROR").onFailure { (error: String?, isCancelled: Bool) -> String in
            
            XCTAssertEqual(error!, "ERROR")
            return "RECOVERY"
            
        }
    }
    
    // fulfill/reject handlers only, like JavaScript Promise
    func testInit_fulfill_reject()
    {
        // NOTE: this is non-async test
        if self.isAsync { return }
        
        Task<Any, String, ErrorString> { (fulfill, reject) in
            
            fulfill("OK")
            return
            
        }.onSuccess { (value: String) -> Void in
            XCTAssertEqual(value, "OK")
        }
    }
    
    //--------------------------------------------------
    // MARK: - Fulfill
    //--------------------------------------------------
    
    func testFulfill_onSuccess()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.onSuccess { (value: String) -> Void in
                
            XCTAssertEqual(value, "OK")
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    func testFulfill_onSuccess_onFailure()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
         
        }.onSuccess { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTFail("Should never reach here.")
            
        }
        
        self.wait()
    }
    
    func testFulfill_onFailure_onSuccess()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> String in
            
            XCTFail("Should never reach here.")
            
            return "RECOVERY"
            
        }.onSuccess { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK", "value should be derived from 1st task, passing through 2nd failure task.")
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testFulfill_onSuccessTaskFulfill()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.onSuccess { (value: String) -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(value, "OK")
            
            return Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    fulfill("OK2")
                }
                
            }
            
        }.onSuccess { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK2")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testFulfill_onSuccessTaskReject()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.onSuccess { (value: String) -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(value, "OK")
            
            return Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    reject("ERROR")
                }
                
            }
            
        }.onSuccess { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testFulfill_onComplete()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.onComplete { (value: String?, errorInfo: Task.ErrorInfo?) -> String in
            // completeClosure can handle both fulfilled & rejected
                
            XCTAssertEqual(value!, "OK")
            XCTAssertTrue(errorInfo == nil)
            return "OK2"
                
        }.onComplete { (value: String?, errorInfo: Task.ErrorInfo?) -> Void in
                
            XCTAssertEqual(value!, "OK2")
            XCTAssertTrue(errorInfo == nil)
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Reject
    //--------------------------------------------------
    
    func testReject_onFailure()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, Void, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject("ERROR")
            }
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
                
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_onSuccess_onFailure()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject("ERROR")
            }
            
        }.onSuccess { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
                
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_onFailure_onSuccess()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject("ERROR")
            }
        
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> String in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            return "RECOVERY"
            
        }.onSuccess { (value: String) -> Void in
            
            XCTAssertEqual(value, "RECOVERY", "value should be derived from 2nd failure task.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_onFailureTaskFulfill()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject("ERROR")
            }
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            return Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    fulfill("RECOVERY")
                }
                
            }
            
        }.onSuccess { (value: String) -> Void in
            
            XCTAssertEqual(value, "RECOVERY")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testReject_onFailureTaskReject()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject("ERROR")
            }
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            return Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    reject("ERROR2")
                }
                
            }
            
        }.onSuccess { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "ERROR2")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_onComplete()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject("ERROR")
            }
            
        }.onComplete { (value: String?, errorInfo: Task.ErrorInfo?) -> String in
            // completeClosure can handle both fulfilled & rejected
            
            XCTAssertTrue(value == nil)
            XCTAssertEqual(errorInfo!.error!, "ERROR")
            XCTAssertFalse(errorInfo!.isCancelled)
            
            return "OK"
            
        }.onComplete { (value: String?, errorInfo: Task.ErrorInfo?) -> Void in
            
            XCTAssertEqual(value!, "OK")
            XCTAssertTrue(errorInfo == nil)
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Progress
    //--------------------------------------------------
    
    func testProgress()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                progress(0.0)
                progress(0.2)
                progress(0.5)
                progress(0.8)
                progress(1.0)
                fulfill("OK")
            }
            
        }.onProgress { oldValue, newValue in
            
            progressCount++
            
            if self.isAsync {
                // 0.0 <= progress <= 1.0
//                XCTAssertGreaterThanOrEqual(newValue, 0)  // TODO: Xcode6.1-GM bug
//                XCTAssertLessThanOrEqual(newValue, 1)     // TODO: Xcode6.1-GM bug
                XCTAssertTrue(newValue >= 0)
                XCTAssertTrue(newValue <= 1)
                
                // 1 <= progressCount <= 5
                XCTAssertGreaterThanOrEqual(progressCount, 1)
                XCTAssertLessThanOrEqual(progressCount, 5)
            }
            else {
                XCTFail("When isAsync=false, 1st task closure is already performed before registering this progress closure, so this closure should not be reached.")
            }
            
        }.onSuccess { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            
            if self.isAsync {
                XCTAssertEqual(progressCount, 5)
            }
            else {
                XCTAssertLessThanOrEqual(progressCount, 0, "progressCount should be 0 because progress closure should not be invoked when isAsync=false")
            }
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testProgressTuple()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                progress(0.5)
                progress(1.0)
                fulfill("OK")
            }
            
        }.onProgress { (oldValue, newValue) in     // progressTupleClosure
            
            progressCount++
            
            if self.isAsync {
                if !((oldValue == nil && newValue == 0.5) || (oldValue! == 0.5 && newValue == 1.0)) {
                    XCTFail("Invalid progressTuple (\(oldValue), \(newValue)).")
                }
            }
            else {
                XCTFail("When isAsync=false, 1st task closure is already performed before registering this progress closure, so this closure should not be reached.")
            }
            
        }.onSuccess { value -> Void in
            
            XCTAssertEqual(value, "OK")
            
            if self.isAsync {
                XCTAssertEqual(progressCount, 2)
            }
            else {
                XCTAssertLessThanOrEqual(progressCount, 0, "progressCount should be 0 because progress closure should not be invoked when isAsync=false")
            }
            
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Cancel
    //--------------------------------------------------
    
    // 1. 3 progresses at t=200ms
    // 2. checks cancel & pause, add 2 progresses at t=400ms
    typealias _InterruptableTask = Task<Float, String, ErrorString>
    func _interruptableTask() -> _InterruptableTask
    {
        return Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            // NOTE: not a good flag, watch out for race condition!
            var isCancelled = false
            var isPaused = false
            
            // 1st delay (t=200ms)
            Async.background(after: 0.2) {
                
                Async.main { progress(0.0) }
                Async.main { progress(0.2) }
                Async.main { progress(0.5) }
                
                // 2nd delay (t=400ms)
                Async.background(after: 0.2) {
                    
                    // NOTE: no need to call reject() because it's already rejected (cancelled) internally
                    if isCancelled { return }
                    
                    while isPaused {
                        NSThread.sleepForTimeInterval(0.1)
                    }
                    
                    Async.main { progress(0.8) }
                    Async.main { progress(1.0) }
                    Async.main { fulfill("OK") }
                }
            }
            
            // configure pause & cancel
            configure.pause = {
                isPaused = true;
                return
            }
            configure.resume = {
                isPaused = false;
                return
            }
            
            // configure cancel for cleanup after reject or task.cancel()
            configure.cancel = {
                isCancelled = true;
                return
            }
            
        }
    }
    
    func testCancel()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        
        let task = self._interruptableTask()
            
        task.onProgress { oldValue, newValue in
            
            progressCount++
            
            // 0.0 <= progress <= 0.5 (not 1.0)
//            XCTAssertGreaterThanOrEqual(newValue, 0)  // TODO: Xcode6.1-GM bug
//            XCTAssertLessThanOrEqual(newValue, 0.5)   // TODO: Xcode6.1-GM bug
            XCTAssertTrue(newValue >= 0)
            XCTAssertTrue(newValue <= 0.5)
            
            // 1 <= progressCount <= 3 (not 5)
            XCTAssertGreaterThanOrEqual(progressCount, 1)
            XCTAssertLessThanOrEqual(progressCount, 3, "progressCount should be stopped to 3 instead of 5 because of cancellation.")
            
        }.onSuccess { (value: String) -> Void in
            
            XCTFail("Should never reach here because of cancellation.")
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "I get bored.")
            XCTAssertTrue(isCancelled)
            
            XCTAssertEqual(progressCount, 3, "progressCount should be stopped to 3 instead of 5 because of cancellation.")
            
            expect.fulfill()
                
        }
        
        // cancel at time between 1st & 2nd delay (t=300ms)
        Async.main(after: 0.3) {
            
            task.cancel(error: "I get bored.")
            
            XCTAssertEqual(task.state, TaskState.Cancelled)
            
        }
        
        self.wait()
    }
    
    func testCancel_onCompleteTask()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        let task1 = self._interruptableTask()
        
        var task2: _InterruptableTask? = nil
        
        let task3 = task1.onComplete { (value, errorInfo) -> _InterruptableTask in
            
            task2 = self._interruptableTask()
            return task2!
            
        }
        
        task3.onFailure { (error: ErrorString?, isCancelled: Bool) -> String in
            
            XCTAssertEqual(error!, "I get bored.")
            XCTAssertTrue(isCancelled)
            
            expect.fulfill()
            
            return "DUMMY"
        }
        
        // cancel task3 at time between task1 fulfilled & before task2 completed (t=600ms)
        Async.main(after: 0.6) {
            
            task3.cancel(error: "I get bored.")
            
            XCTAssertEqual(task3.state, TaskState.Cancelled)
            
            XCTAssertTrue(task2 != nil, "task2 should be created.")
            XCTAssertEqual(task2!.state, TaskState.Cancelled, "task2 should be cancelled because task2 is created and then task3 (wrapper) is cancelled.")
            
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Pause & Resume
    //--------------------------------------------------
    
    func testPauseResume()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        
        let task = self._interruptableTask()
        
        task.onProgress { _ in
            
            progressCount++
            return
            
        }.onSuccess { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            XCTAssertEqual(progressCount, 5)
            expect.fulfill()
            
        }
        
        // pause at time between 1st & 2nd delay (t=300ms)
        Async.main(after: 0.3) {
            
            task.pause()
            
            XCTAssertEqual(task.state, TaskState.Paused)
//            XCTAssertEqual(task.onProgress!, 0.5)   // TODO: Xcode6.1-GM bug
            XCTAssertTrue(task.progress! == 0.5)
            
            // resume after 300ms (t=600ms)
            Async.main(after: 0.3) {
                
                XCTAssertEqual(task.state, TaskState.Paused)
//                XCTAssertEqual(task.onProgress!, 0.5)   // TODO: Xcode6.1-GM bug
                XCTAssertTrue(task.progress! == 0.5)
                
                task.resume()
                XCTAssertEqual(task.state, TaskState.Running)
                
            }
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - All
    //--------------------------------------------------
    
    /// all fulfilled test
    func testAll_onSuccess()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                Async.background(after: 0.1) {
                    Async.main { progress(0.1) }
                    return
                }
                
                Async.background(after: 0.2) {
                    progress(1.0)
                    Async.main { fulfill("OK \(i)") }
                }
                
            }
            
            //
            // NOTE: 
            // For tracking each task's progress, you simply call `task.onProgress`
            // instead of `Task.all(tasks).onProgress`.
            //
            task.onProgress { (_, progress: Any) in
                println("each progress = \(progress)")
                return
            }
            
            tasks.append(task)
        }
        
        Task.all(tasks).onProgress { (_, newValue: Task.BulkProgress) in
            
            println("all progress = \(newValue.completedCount) / \(newValue.totalCount)")
        
        }.onSuccess { (values: [String]) -> Void in
            
            for i in 0..<values.count {
                XCTAssertEqual(values[i], "OK \(i)")
            }
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    /// any rejected test
    func testAll_onFailure()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<5 {
            // define fulfilling task
            let task = Task { (progress, fulfill, reject, configure) in
                Async.background(after: 0.1) {
                    Async.main { fulfill("OK \(i)") }
                    return
                }
                return
            }
            tasks.append(task)
        }
        
        for i in 0..<5 {
            // define rejecting task
            let task = Task { (progress, fulfill, reject, configure) in
                Async.background(after: 0.1) {
                    Async.main { reject("ERROR") }
                    return
                }
                return
            }
            tasks.append(task)
        }
        
        Task.all(tasks).onSuccess { (values: [String]) -> Void in
            
            XCTFail("Should never reach here because of Task.all failure.")
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "ERROR", "Task.all non-cancelled error returns 1st-errored object (spec).")
            expect.fulfill()
            
        }
    
        self.wait()
    }
    
    func testAll_cancel()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isCancelled = false
                
                Async.background(after: 0.1) {
                    if isCancelled {
                        return
                    }
                    Async.main { fulfill("OK \(i)") }
                }
                
                configure.cancel = {
                    isCancelled = true
                    return
                }
                
            }
            
            tasks.append(task)
        }
        
        let groupedTask = Task.all(tasks)
        
        groupedTask.onSuccess { (values: [String]) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "Cancel")
            XCTAssertTrue(isCancelled)
            expect.fulfill()
                
        }
        
        // cancel before fulfilled
        Async.main(after: 0.01) {
            groupedTask.cancel(error: "Cancel")
            return
        }
        
        self.wait()
    }
    
    func testAll_pauseResume()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isPaused = false
                
                Async.background(after: SAFE_BG_FLAG_CHECK_DELAY) {
                    while isPaused {
                        NSThread.sleepForTimeInterval(0.1)
                    }
                    Async.main { fulfill("OK \(i)") }
                }
                
                configure.pause = {
                    isPaused = true
                    return
                }
                configure.resume = {
                    isPaused = false
                    return
                }
                
            }
            
            tasks.append(task)
        }
        
        let groupedTask = Task.all(tasks)
        
        groupedTask.onSuccess { (values: [String]) -> Void in
            
            for i in 0..<values.count {
                XCTAssertEqual(values[i], "OK \(i)")
            }
            
            expect.fulfill()
            
        }
        
        // pause & resume
        self.perform {
            
            groupedTask.pause()
            XCTAssertEqual(groupedTask.state, TaskState.Paused)
            
            Async.main(after: 1.0) {
                
                groupedTask.resume()
                XCTAssertEqual(groupedTask.state, TaskState.Running)
                
            }
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Any
    //--------------------------------------------------
    
    /// any fulfilled test
    func testAny_onSuccess()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                Async.background(after: 0.1) {
                    Async.main {
                        if i == 5 {
                            fulfill("OK \(i)")
                        }
                        else {
                            reject("Failed \(i)")
                        }
                    }
                    return
                }
                return
                
            }
            
            tasks.append(task)
        }
        
        Task.any(tasks).onSuccess { (value: String) -> Void in
                
            XCTAssertEqual(value, "OK 5")
            
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    /// all rejected test
    func testAny_onFailure()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                Async.background(after: 0.1) {
                    Async.main { reject("Failed \(i)") }
                    return
                }
                return
                
            }
            
            tasks.append(task)
        }
        
        Task.any(tasks).onSuccess { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertTrue(error == nil, "Task.any non-cancelled error returns nil (spec).")
            XCTAssertFalse(isCancelled)
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testAny_cancel()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isCancelled = false
                
                Async.background(after: SAFE_BG_FLAG_CHECK_DELAY) {
                    if isCancelled {
                        return
                    }
                    Async.main { fulfill("OK \(i)") }
                }
                
                configure.cancel = {
                    isCancelled = true
                    return
                }
                
            }
            
            tasks.append(task)
        }
        
        let groupedTask = Task.any(tasks)
        
        groupedTask.onSuccess { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "Cancel")
            XCTAssertTrue(isCancelled)
            expect.fulfill()
                
        }
        
        // cancel before fulfilled
        self.perform {
            groupedTask.cancel(error: "Cancel")
            return
        }
        
        self.wait()
    }
    
    func testAny_pauseResume()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isPaused = false
                
                Async.background(after: SAFE_BG_FLAG_CHECK_DELAY) {
                    while isPaused {
                        NSThread.sleepForTimeInterval(0.1)
                    }

                    Async.main { fulfill("OK \(i)") }
                }
                
                configure.pause = {
                    isPaused = true
                    return
                }
                configure.resume = {
                    isPaused = false
                    return
                }
                
            }
            
            tasks.append(task)
        }
        
        let groupedTask = Task.any(tasks)
        
        groupedTask.onSuccess { (value: String) -> Void in
            
            XCTAssertTrue(value.hasPrefix("OK"))
            expect.fulfill()
            
        }
        
        // pause & resume
        self.perform {
            
            groupedTask.pause()
            XCTAssertEqual(groupedTask.state, TaskState.Paused)
            
            Async.main(after: SAFE_BG_FLAG_CHECK_DELAY+0.2) {
                
                groupedTask.resume()
                XCTAssertEqual(groupedTask.state, TaskState.Running)
                
            }
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Some
    //--------------------------------------------------
    
    /// some fulfilled test
    func testSome_onSuccess()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                Async.main(after: 0.1) {
                    
                    if i == 3 || i == 5 {
                        fulfill("OK \(i)")
                    }
                    else {
                        reject("Failed \(i)")
                    }
                }
                return
                
            }
            
            tasks.append(task)
        }
        
        Task.some(tasks).onSuccess { (values: [String]) -> Void in
            
            XCTAssertEqual(values.count, 2)
            XCTAssertEqual(values[0], "OK 3")
            XCTAssertEqual(values[1], "OK 5")
            
            expect.fulfill()
            
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTFail("Should never reach here because Task.some() will never reject internally.")
            
        }
        
        self.wait()
    }
}
