//
//  SwiftTaskTests.swift
//  SwiftTaskTests
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import Async
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
        
        Task<Float, String, ErrorString>(value: "OK").success { value -> Void in
            XCTAssertEqual(value, "OK")
        }
    }
    
    func testInit_error()
    {
        // NOTE: this is non-async test
        if self.isAsync { return }
        
        Task<Float, String, ErrorString>(error: "ERROR").failure { error, isCancelled -> String in
            
            XCTAssertEqual(error!, "ERROR")
            return "RECOVERY"
            
        }
    }
    
    // fulfill/reject handlers only, like JavaScript Promise
    func testInit_fulfill_reject()
    {
        // NOTE: this is non-async test
        if self.isAsync { return }
        
        Task<Any, String, ErrorString> { fulfill, reject in
            
            fulfill("OK")
            return
            
        }.success { value -> Void in
            XCTAssertEqual(value, "OK")
        }
    }
    
    //--------------------------------------------------
    // MARK: - Fulfill
    //--------------------------------------------------
    
    func testFulfill_success()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                fulfill("OK")
            }
            
        }.success { value -> Void in
                
            XCTAssertEqual(value, "OK")
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    func testFulfill_success_failure()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                fulfill("OK")
            }
         
        }.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }.failure { error, isCancelled -> Void in
            
            XCTFail("Should never reach here.")
            
        }
        
        self.wait()
    }
    
    func testFulfill_failure_success()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                fulfill("OK")
            }
            
        }.failure { error, isCancelled -> String in
            
            XCTFail("Should never reach here.")
            
            return "RECOVERY"
            
        }.success { value -> Void in
            
            XCTAssertEqual(value, "OK", "value should be derived from 1st task, passing through 2nd failure task.")
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testFulfill_success_innerTask_fulfill()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                fulfill("OK")
            }
            
        }.success { value -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(value, "OK")
            
            return Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
                
                self.perform {
                    fulfill("OK2")
                }
                
            }
            
        }.success { value -> Void in
            
            XCTAssertEqual(value, "OK2")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testFulfill_success_innerTask_reject()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                fulfill("OK")
            }
            
        }.success { value -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(value, "OK")
            
            return Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
                
                self.perform {
                    reject("ERROR")
                }
                
            }
            
        }.success { value -> Void in
            
            XCTFail("Should never reach here.")
            
        }.failure { error, isCancelled -> Void in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testFulfill_then()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        let expect = self.expectation(description: #function)
        
        Task { progress, fulfill, reject, configure in
            
            self.perform {
                fulfill("OK")
            }
            
        }.then { value, errorInfo -> String in
            // thenClosure can handle both fulfilled & rejected
                
            XCTAssertEqual(value!, "OK")
            XCTAssertTrue(errorInfo == nil)
            return "OK2"
            
        }.then { value, errorInfo -> Void in
                
            XCTAssertEqual(value!, "OK2")
            XCTAssertTrue(errorInfo == nil)
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Reject
    //--------------------------------------------------
    
    func testReject_failure()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, Void, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                reject("ERROR")
            }
            
        }.failure { error, isCancelled -> Void in
                
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_success_failure()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                reject("ERROR")
            }
            
        }.success { value -> Void in
            
            XCTFail("Should never reach here.")
                
        }.failure { error, isCancelled -> Void in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_failure_success()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                reject("ERROR")
            }
        
        }.failure { error, isCancelled -> String in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            return "RECOVERY"
            
        }.success { value -> Void in
            
            XCTAssertEqual(value, "RECOVERY", "value should be derived from 2nd failure task.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_failure_innerTask_fulfill()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                reject("ERROR")
            }
            
        }.failure { error, isCancelled -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            return Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
                
                self.perform {
                    fulfill("RECOVERY")
                }
                
            }
            
        }.success { value -> Void in
            
            XCTAssertEqual(value, "RECOVERY")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testReject_failure_innerTask_reject()
    {
        let expect = self.expectation(description: #function)
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                reject("ERROR")
            }
            
        }.failure { error, isCancelled -> Task<Float, String, ErrorString> in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            return Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
                
                self.perform {
                    reject("ERROR2")
                }
                
            }
            
        }.success { value -> Void in
            
            XCTFail("Should never reach here.")
            
        }.failure { error, isCancelled -> Void in
            
            XCTAssertEqual(error!, "ERROR2")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testReject_then()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        let expect = self.expectation(description: #function)
        
        Task { progress, fulfill, reject, configure in
            
            self.perform {
                reject("ERROR")
            }
            
        }.then { value, errorInfo -> String in
            // thenClosure can handle both fulfilled & rejected
            
            XCTAssertTrue(value == nil)
            XCTAssertEqual(errorInfo!.error!, "ERROR")
            XCTAssertFalse(errorInfo!.isCancelled)
            
            return "OK"
            
        }.then { value, errorInfo -> Void in
            
            XCTAssertEqual(value!, "OK")
            XCTAssertTrue(errorInfo == nil)
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - On
    //--------------------------------------------------
    
    func testOn_success()
    {
        let expect = self.expectation(description: #function)
        
        Task<(), String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                fulfill("OK")
            }
            
        }.on(success: { value in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }).on(failure: { error, isCancelled in
            XCTFail("Should never reach here.")
        })
        
        self.wait()
    }
    
    func testOn_failure()
    {
        let expect = self.expectation(description: #function)
        
        Task<(), String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                reject("NG")
            }
            
            }.on(success: { value in
                
                XCTFail("Should never reach here.")
                
            }).on(failure: { error, isCancelled in
                
                XCTAssertEqual(error!, "NG")
                XCTAssertFalse(isCancelled)
                expect.fulfill()
                
            })
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Progress
    //--------------------------------------------------
    
    func testProgress()
    {
        let expect = self.expectation(description: #function)
        var progressCount = 0
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                progress(0.5)
                progress(1.0)
                fulfill("OK")
            }
            
        }.progress { oldProgress, newProgress in
            
            progressCount += 1
            
            if self.isAsync {
                // 0.0 <= progress <= 1.0
                XCTAssertTrue(newProgress >= 0)
                XCTAssertTrue(newProgress <= 1)
                
                // 1 <= progressCount <= 2
                XCTAssertGreaterThanOrEqual(progressCount, 1)
                XCTAssertLessThanOrEqual(progressCount, 2)
            }
            else {
                XCTFail("When isAsync=false, 1st task closure is already performed before registering this progress closure, so this closure should not be reached.")
            }
            
        }.success { (value: String) -> Void in
            
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
    
    func testProgress_innerTask_then()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        var progressCount = 0
        
        let task = _interruptableTask(progressCount: 5)    // 1st async task (5 progresses)
        
        // chain async-task with then
        let task3 = task.then { _ -> _InterruptableTask in
            let task2 = _interruptableTask(progressCount: 7)    // 2st async task (7 progresses)
            return task2
        }
        
        task3.progress { progressValues in
            progressCount += 1
            print(progressValues)
            return
        }.success { value -> Void in
            XCTAssertEqual(value, "OK")
            XCTAssertEqual(progressCount, 7, "`task3` should receive progress only from `task2` but not from `task`.")
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testProgress_innerTask_success()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        var progressCount = 0
        
        let task = _interruptableTask(progressCount: 5)    // 1st async task (5 progresses)
        
        // chain async-task with success
        let task3 = task.success { _ -> _InterruptableTask in
            let task2 = _interruptableTask(progressCount: 7)    // 2st async task (7 progresses)
            return task2
        }
        
        task3.progress { progressValues in
            progressCount += 1
            print(progressValues)
            return
        }.success { value -> Void in
            XCTAssertEqual(value, "OK")
            XCTAssertEqual(progressCount, 7, "`task3` should receive progress only from `task2` but not from `task`.")
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testProgress_innerTask_failure()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        var progressCount = 0
        
        let task = _interruptableTask(progressCount: 5, finalState: .Rejected)  // 1st async task (5 progresses -> rejected)
        
        // chain async-task with failure
        let task3 = task.failure { _ -> _InterruptableTask in
            let task2 = _interruptableTask(progressCount: 7)    // 2st async task (7 progresses)
            return task2
        }
        
        task3.progress { progressValues in
            progressCount += 1
            print(progressValues)
            return
        }.success { value -> Void in
            XCTAssertEqual(value, "OK")
            XCTAssertEqual(progressCount, 7, "`task3` should receive progress only from `task2` but not from `task`.")
            expect.fulfill()
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Cancel
    //--------------------------------------------------
    
    func testCancel()
    {
        let expect = self.expectation(description: #function)
        var progressCount = 0
        
        let task = _interruptableTask(progressCount: 5)
        
        task.progress { oldProgress, newProgress in
            
            progressCount += 1
            
            // 1 <= progressCount <= 3 (not 5)
            XCTAssertGreaterThanOrEqual(progressCount, 1)
            XCTAssertLessThanOrEqual(progressCount, 3, "progressCount should be stopped to 3 instead of 5 because of cancellation.")
            
        }.success { value -> Void in
            
            XCTFail("Should never reach here because of cancellation.")
            
        }.failure { error, isCancelled -> Void in
            
            XCTAssertEqual(error!, "I get bored.")
            XCTAssertTrue(isCancelled)
            
            XCTAssertEqual(progressCount, 2, "progressCount should be stopped to 2 instead of 5 because of cancellation.")
            
            expect.fulfill()
                
        }
        
        // cancel at time between 1st & 2nd delay (t=0.3)
        Async.main(after: 0.3) {
            
            task.cancel(error: "I get bored.")
            
            XCTAssertEqual(task.state, TaskState.Cancelled)
            
        }
        
        self.wait()
    }
    
    func testCancel_then_innerTask()
    {
        let expect = self.expectation(description: #function)
        
        let task1 = _interruptableTask(progressCount: 5)
        
        var task2: _InterruptableTask? = nil
        
        let task3 = task1.then { value, errorInfo -> _InterruptableTask in
            
            task2 = _interruptableTask(progressCount: 5)
            return task2!
            
        }
        
        task3.failure { error, isCancelled -> String in
            
            XCTAssertEqual(error!, "I get bored.")
            XCTAssertTrue(isCancelled)
            
            expect.fulfill()
            
            return "DUMMY"
        }
        
        // cancel task3 at time between task1 fulfilled & before task2 completed (t=0.6)
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
        
        let expect = self.expectation(description: #function)
        var progressCount = 0
        
        let task = _interruptableTask(progressCount: 5)
        
        task.progress { _ in
            
            progressCount += 1
            return
            
        }.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            XCTAssertEqual(progressCount, 5)
            expect.fulfill()
            
        }
        
        // pause at t=0.3 (between _interruptableTask's 1st & 2nd delay before pause-check)
        Async.main(after: 0.3) {
            
            task.pause()
            
            XCTAssertEqual(task.state, TaskState.Paused)
            XCTAssertTrue(task.progress! == 2, "`task` should be progressed halfway.")
            
            // resume at t=0.6
            Async.main(after: 0.3) {
                
                XCTAssertEqual(task.state, TaskState.Paused)
                XCTAssertTrue(task.progress! == 2, "`task` should pause progressing.")
                
                task.resume()
                
                XCTAssertEqual(task.state, TaskState.Running, "`task` should start running again.")
                
            }
        }
        
        self.wait()
    }
    
    func testPauseResume_innerTask()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        
        let task = _interruptableTask(progressCount: 5)
        weak var innerTask: _InterruptableTask?
        
        // chain async-task with `then`
        let task2 = task.then { _ -> _InterruptableTask in
            innerTask = _interruptableTask(progressCount: 5)
            return innerTask!
        }
        
        task2.success { value -> Void in
            XCTAssertEqual(value, "OK")
            expect.fulfill()
        }
        
        // pause at t=0.3 (between _interruptableTask's 1st & 2nd delay before pause-check)
        Async.main(after: 0.3) {
            
            // NOTE: task2 will be paused,
            task2.pause()
            
            XCTAssertEqual(task2.state, TaskState.Paused)
            XCTAssertNil(task2.progress, "`task2.progress` should be nil because `innerTask.progress()` has not been invoked yet.")
            
            XCTAssertNil(innerTask, "`innerTask` should NOT be created yet.")
            
            XCTAssertEqual(task.state, TaskState.Running, "`task` should NOT be paused.")
            XCTAssertTrue(task.progress! == 2, "`task` should be halfway progressed.")
            XCTAssertNil(task.value, "`task` should NOT be fulfilled yet.")
            
            // resume at t=0.6
            Async.main(after: 0.3) {
                
                XCTAssertEqual(task2.state, TaskState.Paused)
                XCTAssertNil(task2.progress, "`task2.progress` should still be nil.")
                
                XCTAssertNotNil(innerTask, "`innerTask` should be created at this point.")
                XCTAssertEqual(innerTask!.state, task2.state, "`innerTask!.state` should be same as `task2.state`.")
                
                XCTAssertEqual(task.state, TaskState.Fulfilled, "`task` should NOT be paused, and it should be fulfilled at this point.")
                XCTAssertEqual(task.value!, "OK", "`task` should be fulfilled.")
                
                task2.resume()
                
                XCTAssertEqual(task2.state, TaskState.Running, "`task2` should be resumed.")
                
                // check tasks's states at t=0.7
                Async.main(after: 0.1) {
                    XCTAssertEqual(task2.state, TaskState.Running)
                    XCTAssertEqual(innerTask!.state, task2.state, "`innerTask!.state` should be same as `task2.state`.")
                    XCTAssertEqual(task.state, TaskState.Fulfilled)
                }
                
            }
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Try
    //--------------------------------------------------
    
    func testRetry_success()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        let maxTryCount = 3
        let fulfilledTryCount = 2
        var actualTryCount = 0
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                
                actualTryCount += 1
                
                if actualTryCount != fulfilledTryCount {
                    reject("ERROR \(actualTryCount)")
                }
                else {
                    fulfill("OK")
                }
            }
            
        }.retry(maxTryCount-1).failure { errorInfo -> String in
            
            XCTFail("Should never reach here because `task.retry(\(maxTryCount-1))` will be fulfilled at `fulfilledTryCount` try even though previous retries will be rejected.")
            
            return "DUMMY"
            
        }.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
                
        }
        
        self.wait()
        
        XCTAssertEqual(actualTryCount, fulfilledTryCount, "`actualTryCount` should be stopped at `fulfilledTryCount`, not `maxTryCount`.")
    }
    
    func testRetry_failure()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        let maxTryCount = 3
        var actualTryCount = 0
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                actualTryCount += 1
                reject("ERROR \(actualTryCount)")
            }
            
        }.retry(maxTryCount-1).failure { error, isCancelled -> String in
            
            XCTAssertEqual(error!, "ERROR \(actualTryCount)")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
            
            return "DUMMY"
            
        }
        
        self.wait()
        
        XCTAssertEqual(actualTryCount, maxTryCount, "`actualTryCount` should reach `maxTryCount` because task keeps rejected and never fulfilled.")
    }
    
    func testRetry_progress()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        let maxTryCount = 3
        var actualTryCount = 0
        var progressCount = 0
        
        Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            self.perform {
                
                progress(1.0)
                
                actualTryCount += 1
                
                if actualTryCount < maxTryCount {
                    reject("ERROR \(actualTryCount)")
                }
                else {
                    fulfill("OK")
                }
            }
            
        }.retry(maxTryCount-1).progress { _ in
            
            progressCount += 1
            
            // 1 <= progressCount <= maxTryCount
            XCTAssertGreaterThanOrEqual(progressCount, 1)
            XCTAssertLessThanOrEqual(progressCount, maxTryCount)
            
        }.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
                
        }
        
        self.wait()
        
        XCTAssertEqual(progressCount, maxTryCount)
    }
    
    func testRetry_pauseResume()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        let maxTryCount = 5
        var actualTryCount = 0
        
        let retryableTask = Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            actualTryCount += 1
            print("trying \(actualTryCount)")
            
            var isPaused = false
            
            Async.background(after: 0.1) {
                while isPaused {
                    print("pausing...")
                    Thread.sleep(forTimeInterval: 0.1)
                }
                Async.main(after: 0.2) {
                    if actualTryCount < maxTryCount {
                        reject("ERROR \(actualTryCount)")
                    }
                    else {
                        fulfill("OK")
                    }
                }
            }
            
            configure.pause = {
                isPaused = true
                return
            }
            configure.resume = {
                isPaused = false
                return
            }
            
        }.retry(maxTryCount-1)
        
        retryableTask.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }
        
        // pause `retryableTask` at some point before all tries completes
        Async.main(after: 0.5) {
            retryableTask.pause()
            return
        }
        
        Async.main(after: 1.5) {
            retryableTask.resume()
            return
        }
        
        self.wait(5)    // wait a little longer
        
        XCTAssertEqual(actualTryCount, maxTryCount)
    }
    
    func testRetry_cancel()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectation(description: #function)
        let maxTryCount = 3
        var actualTryCount = 0
        
        let task = Task<Float, String, ErrorString> { progress, fulfill, reject, configure in
            
            Async.main(after: 0.3) {
                
                actualTryCount += 1
                
                if actualTryCount < maxTryCount {
                    reject("ERROR \(actualTryCount)")
                }
                else {
                    fulfill("OK")
                }
            }
            
            return
            
        }
            
        let retryableTask = task.retry(maxTryCount-1)
            
        retryableTask.success { value -> Void in
            
            XCTFail("Should never reach here because `retryableTask` is cancelled.")
                
        }.failure { errorInfo -> Void in
            
            XCTAssertTrue(errorInfo.isCancelled)
//            expect.fulfill()
            
        }
        
        task.success { value -> Void in
            
            XCTFail("Should never reach here because `retryableTask` is cancelled so original-`task` should also be cancelled.")
            
        }.failure { errorInfo -> Void in
            
            XCTAssertTrue(errorInfo.isCancelled)
            expect.fulfill()
                
        }
        
        // cancel `retryableTask` at some point before all tries completes
        Async.main(after: 0.2) {
            retryableTask.cancel()
            return
        }
        
        self.wait()
        
        XCTAssertTrue(actualTryCount < maxTryCount, "`actualTryCount` should not reach `maxTryCount` because of cancellation.")
    }
    
    //--------------------------------------------------
    // MARK: - All
    //--------------------------------------------------
    
    /// all fulfilled test
    func testAll_success()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
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
            // For tracking each task's progress, you simply call `task.progress`
            // instead of `Task.all(tasks).progress`.
            //
            task.progress { oldProgress, newProgress in
                print("each progress = \(newProgress)")
                return
            }
            
            tasks.append(task)
        }
        
        Task.all(tasks).progress { (oldProgress: Task.BulkProgress?, newProgress: Task.BulkProgress) in
            
            print("all progress = \(newProgress.completedCount) / \(newProgress.totalCount)")
        
        }.success { values -> Void in
            
            for i in 0..<values.count {
                XCTAssertEqual(values[i], "OK \(i)")
            }
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    /// any rejected test
    func testAll_failure()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<5 {
            // define fulfilling task
            let task = Task { progress, fulfill, reject, configure in
                Async.background(after: 0.1) {
                    Async.main { fulfill("OK \(i)") }
                    return
                }
                return
            }
            tasks.append(task)
        }
        
        for _ in 0..<5 {
            // define rejecting task
            let task = Task { progress, fulfill, reject, configure in
                Async.background(after: 0.1) {
                    Async.main { reject("ERROR") }
                    return
                }
                return
            }
            tasks.append(task)
        }
        
        Task.all(tasks).success { values -> Void in
            
            XCTFail("Should never reach here because of Task.all failure.")
            
        }.failure { error, isCancelled -> Void in
            
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
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
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
        
        groupedTask.success { values -> Void in
            
            XCTFail("Should never reach here.")
            
        }.failure { error, isCancelled -> Void in
            
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
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
                var isPaused = false
                
                Async.background(after: SAFE_BG_FLAG_CHECK_DELAY) {
                    while isPaused {
                        Thread.sleep(forTimeInterval: 0.1)
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
        
        groupedTask.success { values -> Void in
            
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
    func testAny_success()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
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
        
        Task.any(tasks).success { value -> Void in
                
            XCTAssertEqual(value, "OK 5")
            
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    /// all rejected test
    func testAny_failure()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
                Async.background(after: 0.1) {
                    Async.main { reject("Failed \(i)") }
                    return
                }
                return
                
            }
            
            tasks.append(task)
        }
        
        Task.any(tasks).success { value -> Void in
            
            XCTFail("Should never reach here.")
            
        }.failure { error, isCancelled -> Void in
            
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
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
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
        
        groupedTask.success { value -> Void in
            
            XCTFail("Should never reach here.")
            
        }.failure { error, isCancelled -> Void in
            
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
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
                var isPaused = false
                
                Async.background(after: SAFE_BG_FLAG_CHECK_DELAY) {
                    while isPaused {
                        Thread.sleep(forTimeInterval: 0.1)
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
        
        groupedTask.success { value -> Void in
            
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
    func testSome_success()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        typealias Task = SwiftTask.Task<Any, String, ErrorString>
        
        let expect = self.expectation(description: #function)
        var tasks: [Task] = Array()
        
        for i in 0..<10 {
            
            // define task
            let task = Task { progress, fulfill, reject, configure in
                
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
        
        Task.some(tasks).success { values -> Void in
            
            XCTAssertEqual(values.count, 2)
            XCTAssertEqual(values[0], "OK 3")
            XCTAssertEqual(values[1], "OK 5")
            
            expect.fulfill()
            
        }.failure { error, isCancelled -> Void in
            
            XCTFail("Should never reach here because Task.some() will never reject internally.")
            
        }
        
        self.wait()
    }
}
