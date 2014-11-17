//
//  BasicTests.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/27.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

class BasicTests: _TestCase
{
    func testExample()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        
        // define task
        let task = Task { (progress, fulfill, reject, configure) in
            
            Async.main(after: 0.1) {
                progress(0.0)
                progress(1.0)
                
                if arc4random_uniform(2) == 0 {
                    fulfill("OK")
                }
                else {
                    reject("ERROR")
                }
            }
            return
            
        }
            
        task.onProgress { oldValue, newValue in
            
            println("progress = \(newValue)")
            
        }.onSuccess { (value: String) -> String in  // `task.onSuccess {...}` = JavaScript's `promise.then(onFulfilled)`
            
            XCTAssertEqual(value, "OK")
            return "Now OK"
                
        }.onFailure { (error: ErrorString?, isCancelled: Bool) -> String in  // `task.onFailure {...}` = JavaScript's `promise.catch(onRejected)`
            
            XCTAssertEqual(error!, "ERROR")
            return "Now RECOVERED"
            
        }.onComplete { (value: String?, errorInfo: Task.ErrorInfo?) -> Task in // `task.onComplete {...}` = JavaScript's `promise.then(onFulfilled, onRejected)`
            
            println("value = \(value)") // either "Now OK" or "Now RECOVERED"
            
            XCTAssertTrue(value!.hasPrefix("Now"))
            XCTAssertTrue(errorInfo == nil)
            
            return Task(error: "ABORT")
            
        }.onComplete { (value: String?, errorInfo: Task.ErrorInfo?) -> Void in
                
            println("errorInfo = \(errorInfo)")
            
            XCTAssertTrue(value == nil)
            XCTAssertEqual(errorInfo!.error!, "ABORT")
            expect.fulfill()
                
        }
        
        self.wait()
    }

}