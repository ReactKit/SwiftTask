//
//  RemoveHandlerTests.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/28.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import Async
import XCTest

class RemoveHandlerTests: _TestCase
{
    func testRemoveProgress()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        var progressToken: HandlerToken? = nil
        
        // define task
        let task = Task { progress, fulfill, reject, configure in
            
            progress(0.0)
            
            Async.main(after: 0.1) {
                progress(1.0)
                
                fulfill("OK")
            }
            
        }
        
        task.progress { oldProgress, newProgress in
            
            println("progress1 = \(newProgress)")
        
        }.progress(&progressToken) { oldProgress, newProgress in
            
            println("progress2 = \(newProgress)")
            XCTFail("Should never reach here because this progress-handler will be removed soon.")
            
        }.then { value, errorInfo -> Void in
            
            XCTAssertTrue(value == "OK")
            XCTAssertTrue(errorInfo == nil)
            expect.fulfill()
                
        }
        
        XCTAssertTrue(progressToken != nil, "Async `task` will return non-nil `progressToken`.")
        
        // remove progress-handler
        task.removeProgress(progressToken!)
        
        self.wait()
    }
    
    func testRemoveThen()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        
        // define task
        let task = Task { progress, fulfill, reject, configure in
            
            progress(0.0)
            
            Async.main(after: 0.1) {
                progress(1.0)
                fulfill("OK")
            }
            
        }
        
        var thenToken: HandlerToken? = nil
        
        // NOTE: reference to `task2` is required in order to call `task2.removeThen(thenToken)`
        let task2 = task.success { value -> String in
                
            XCTAssertEqual(value, "OK")
            return "Now OK"
                
        }
        
        task2.then(&thenToken) { value, errorInfo -> String in
            
            println("Should never reach here")
            
            XCTFail("Should never reach here because this then-handler will be removed soon.")
            
            return "Never reaches here"
            
        }.then { value, errorInfo -> Void in
            
            XCTAssertTrue(value == nil)
            XCTAssertTrue(errorInfo != nil)
            XCTAssertTrue(errorInfo!.error == nil)
            XCTAssertTrue(errorInfo!.isCancelled, "`task2.removeThen(token)` will force `let task3 = task2.then(&token)` to deinit immediately and tries cancellation if it is still running.")
            
            expect.fulfill()
                
        }
        
        // remove then-handler
        task2.removeThen(thenToken!)
        
        self.wait()
    }
}