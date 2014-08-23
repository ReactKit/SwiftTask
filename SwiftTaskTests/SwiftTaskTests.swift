//
//  SwiftTaskTests.swift
//  SwiftTaskTests
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

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
        
        Task<Float, String, NSError>(value: "OK").then { (value: String) -> Void in
            XCTAssertEqual(value, "OK")
        }
    }
    
    func testInit_error()
    {
        // NOTE: this is non-async test
        if self.isAsync { return }
        
        Task<Float, String, String>(error: "ERROR").catch { (error: String?, isCancelled: Bool) -> String in
            XCTAssertEqual(error!, "ERROR")
            return "OK"
        }
    }
    
    //--------------------------------------------------
    // MARK: - Fulfill
    //--------------------------------------------------
    
    func testFulfill_then()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testFulfill_then_catch()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
         
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Void in
            
            XCTFail("Should never reach here.")
            
        }
        
        self.wait()
    }
    
    func testFulfill_catch_then()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.catch { (error: NSError?, isCancelled: Bool) -> String in
            
            XCTFail("Should never reach here.")
            
            return "ERROR"
            
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK", "value should be derived from 1st task, passing through 2nd catching task.")
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testFulfill_thenTaskFulfill()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.then { (value: String) -> Task<Float, String, NSError> in
            
            XCTAssertEqual(value, "OK")
            
            return Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    fulfill("OK2")
                }
                
            }
            
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK2")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testFulfill_thenTaskReject()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        }.then { (value: String) -> Task<Float, String, NSError> in
            
            XCTAssertEqual(value, "OK")
            
            return Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    reject(NSError())
                }
                
            }
            
        }.then { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Void in
            
            XCTAssertTrue(error != nil)
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Reject
    //--------------------------------------------------
    
    func testReject_catch()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject(NSError())
            }
            
        }.catch { (error: NSError?, isCancelled: Bool) -> String in
                
            XCTAssertTrue(error != nil)
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
            return "ERROR"
        }
        
        self.wait()
    }
    
    func testReject_then_catch()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject(NSError())
            }
            
        }.then { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
                
        }.catch { (error: NSError?, isCancelled: Bool) -> Void in
            
            XCTAssertTrue(error != nil)
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_catch_then()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject(NSError())
            }
        
        }.catch { (error: NSError?, isCancelled: Bool) -> String in
            
            XCTAssertTrue(error != nil)
            XCTAssertFalse(isCancelled)
            
            return "ERROR"
            
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "ERROR", "value should be derived from 2nd catching task.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_catchTaskFulfill()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject(NSError())
            }
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Task<Float, String, NSError> in
            
            XCTAssertTrue(error != nil)
            XCTAssertFalse(isCancelled)
            
            return Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    fulfill("OK2")
                }
                
            }
            
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK2")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testReject_catchTaskReject()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject(NSError())
            }
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Task<Float, String, NSError> in
            
            XCTAssertTrue(error != nil)
            XCTAssertFalse(isCancelled)
            
            return Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
                
                self.perform {
                    reject(NSError())
                }
                
            }
            
        }.then { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Void in
            
            XCTAssertTrue(error != nil)
            XCTAssertFalse(isCancelled)
            
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
        
        Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            self.perform {
                progress(0.0)
                progress(0.2)
                progress(0.5)
                progress(0.8)
                progress(1.0)
                fulfill("OK")
            }
            
        }.progress { (progress: Float) in
            
            progressCount++
            
            if self.isAsync {
                // 0.0 <= progress <= 1.0
                XCTAssertGreaterThanOrEqual(progress, 0)
                XCTAssertLessThanOrEqual(progress, 1)
                
                // 1 <= progressCount <= 5
                XCTAssertGreaterThanOrEqual(progressCount, 1)
                XCTAssertLessThanOrEqual(progressCount, 5)
            }
            else {
                XCTFail("When isAsync=false, 1st task closure is already performed before registering this progress closure, so this closure should not be reached.")
            }
            
        }.then { (value: String) -> Void in
            
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
    
    //--------------------------------------------------
    // MARK: - Cancel
    //--------------------------------------------------
    
    func testCancel()
    {
        typealias ErrorString = String
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        
        // define task
        let task = Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            var isCancelled = false
            
            // 1st delay (t=20ms)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20_000_000), dispatch_get_main_queue()) {
                progress(0.0)
                progress(0.2)
                progress(0.5)
                
                // 2nd delay (t=120ms)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), dispatch_get_main_queue()) {
                    
                    // NOTE: no need to call reject() because it's already rejected (cancelled) internally
                    if isCancelled { return }
                    
                    XCTFail("Should never reach here because of cancellation.")
                    
                    progress(0.8)
                    progress(1.0)
                    fulfill("OK")
                }
            }
            
            // configure cancel for cleanup after reject or task.cancel()
            configure.cancel = {
                isCancelled = true;
                return
            }
            
        }
            
        task.progress { (progress: Float) in
            
            progressCount++
            
            // 0.0 <= progress <= 0.5 (not 1.0)
            XCTAssertGreaterThanOrEqual(progress, 0)
            XCTAssertLessThanOrEqual(progress, 0.5)
            
            // 1 <= progressCount <= 3 (not 5)
            XCTAssertGreaterThanOrEqual(progressCount, 1)
            XCTAssertLessThanOrEqual(progressCount, 3, "progressCount should be stopped to 3 instead of 5 because of cancellation.")
            
        }.then { (value: String) -> Void in
            
            XCTFail("Should never reach here because of cancellation.")
            
        }.catch { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "I get bored.")
            XCTAssertTrue(isCancelled)
            
            XCTAssertEqual(progressCount, 3, "progressCount should be stopped to 3 instead of 5 because of cancellation.")
            
            expect.fulfill()
                
        }
        
        // cancel at time between 1st & 2nd delay (t=50ms)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50_000_000), dispatch_get_main_queue()) {
            
            task.cancel(error: "I get bored.")
            
            XCTAssertEqual(task.state, TaskState.Cancelled)
            
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
        
        // define task
        let task = Task<Float, String, NSError> { (progress, fulfill, reject, configure) in
            
            var isPaused = false
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // 1st delay (t=20ms)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20_000_000), globalQueue) {
                progress(0.0)
                progress(0.2)
                progress(0.5)
                
                // 2nd delay (t=120ms)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    
                    while isPaused {
                        NSThread.sleepForTimeInterval(0.1)
                    }
                    
                    progress(0.8)
                    progress(1.0)
                    fulfill("OK")
                }
            }
            
            configure.pause = {
                isPaused = true;
                return
            }
            configure.resume = {
                isPaused = false;
                return
            }
            
        }
        
        task.progress { (progress: Float) in
            
            progressCount++
            return
            
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            XCTAssertEqual(progressCount, 5)
            expect.fulfill()
            
        }
        
        // pause at time between 1st & 2nd delay (t=50ms)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50_000_000), dispatch_get_main_queue()) {
            
            task.pause()
            XCTAssertEqual(task.state, TaskState.Paused)
            
            // resume after 100ms (t=200ms)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150_000_000), dispatch_get_main_queue()) {
                
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
    func testAll_then()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, NSError>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10_000_000), globalQueue) {
                    progress(0.1)
                }
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    progress(1.0)
                    fulfill("OK \(i)")
                }
                
            }
            
            //
            // NOTE: 
            // For tracking each task's progress, you simply call `task.progress`
            // instead of `Task.all(tasks).progress`.
            //
            task.progress { (progress: Any) in
                println("each progress = \(progress)")
                return
            }
            
            tasks.append(task)
        }
        
        Task.all(tasks).progress { (progress: Task.BulkProgress) in
            
            println("all progress = \(progress.completedCount) / \(progress.totalCount)")
        
        }.then { (values: [String]) -> Void in
            
            for i in 0..<values.count {
                XCTAssertEqual(values[i], "OK \(i)")
            }
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    /// any rejected test
    func testAll_catch()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, NSError>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
        for i in 0..<5 {
            // define fulfilling task
            let task = Task { (progress, fulfill, reject, configure) in
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    fulfill("OK \(i)")
                }
            }
            tasks.append(task)
        }
        
        for i in 0..<5 {
            // define rejecting task
            let task = Task { (progress, fulfill, reject, configure) in
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    reject(NSError())
                }
            }
            tasks.append(task)
        }
        
        Task.all(tasks).then { (values: [String]) -> Void in
            
            XCTFail("Should never reach here because of Task.all failure.")
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Void in
            
            XCTAssertTrue(error != nil, "Task.all non-cancelled error returns 1st-errored object (spec).")
            expect.fulfill()
            
        }
    
        self.wait()
    }
    
    func testAll_cancel()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        typealias ErrorString = String
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isCancelled = false
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    if isCancelled {
                        return
                    }
                    fulfill("OK \(i)")
                }
                
                configure.cancel = {
                    isCancelled = true
                    return
                }
                
            }
            
            tasks.append(task)
        }
        
        let groupedTask = Task.all(tasks)
        
        groupedTask.then { (values: [String]) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.catch { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "Cancel")
            XCTAssertTrue(isCancelled)
            expect.fulfill()
                
        }
        
        // cancel before fulfilled
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000), dispatch_get_main_queue()) {
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
        typealias ErrorString = String
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isPaused = false
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500_000_000), globalQueue) {
                    while isPaused {
                        NSThread.sleepForTimeInterval(0.1)
                    }
                    fulfill("OK \(i)")
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
        
        groupedTask.then { (values: [String]) -> Void in
            
            for i in 0..<values.count {
                XCTAssertEqual(values[i], "OK \(i)")
            }
            
            expect.fulfill()
            
        }
        
        // pause & resume
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000), dispatch_get_main_queue()) {
            
            groupedTask.pause()
            XCTAssertEqual(groupedTask.state, TaskState.Paused)
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000_000), dispatch_get_main_queue()) {
                
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
    func testAny_then()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        typealias ErrorString = String
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    
                    if i == 5 {
                        fulfill("OK \(i)")
                    }
                    else {
                        reject("Failed \(i)")
                    }
                }
                
            }
            
            tasks.append(task)
        }
        
        Task.any(tasks).then { (value: String) -> Void in
                
            XCTAssertEqual(value, "OK 5")
            
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    /// all rejected test
    func testAny_catch()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        typealias ErrorString = String
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    reject("Failed \(i)")
                }
                
            }
            
            tasks.append(task)
        }
        
        Task.any(tasks).then { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.catch { (error: ErrorString?, isCancelled: Bool) -> Void in
            
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
        typealias ErrorString = String
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isCancelled = false
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), globalQueue) {
                    if isCancelled {
                        return
                    }
                    fulfill("OK \(i)")
                }
                
                configure.cancel = {
                    isCancelled = true
                    return
                }
                
            }
            
            tasks.append(task)
        }
        
        let groupedTask = Task.any(tasks)
        
        groupedTask.then { (value: String) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.catch { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "Cancel")
            XCTAssertTrue(isCancelled)
            expect.fulfill()
                
        }
        
        // cancel before fulfilled
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000), dispatch_get_main_queue()) {
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
        typealias ErrorString = String
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            let globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            // define task
            let task = Task { (progress, fulfill, reject, configure) in
                
                var isPaused = false
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500_000_000), globalQueue) {
                    while isPaused {
                        NSThread.sleepForTimeInterval(0.1)
                    }
                    fulfill("OK \(i)")
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
        
        groupedTask.then { (value: String) -> Void in
            
            XCTAssertTrue(value.hasPrefix("OK"))
            expect.fulfill()
            
        }
        
        // pause & resume
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000), dispatch_get_main_queue()) {
            
            groupedTask.pause()
            XCTAssertEqual(groupedTask.state, TaskState.Paused)
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000_000), dispatch_get_main_queue()) {
                
                groupedTask.resume()
                XCTAssertEqual(groupedTask.state, TaskState.Running)
                
            }
        }
        
        self.wait()
    }
}
