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
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), dispatch_get_main_queue()) {
                progress(0.0)
                progress(1.0)
                
                if arc4random_uniform(2) == 0 {
                    fulfill("OK")
                }
                else {
                    reject("ERROR")
                }
            }
            
        }
            
        task ~ { (progress: Float) in
            
            println("progress = \(progress)")
            
        } *** { (value: String) -> String in  // then(onFulfilled)
            
            XCTAssertEqual(value, "OK")
            return "Now OK"
                
        } !!! { (error: ErrorString?, isCancelled: Bool) -> String in  // catch(onRejected)
            
            XCTAssertEqual(error!, "ERROR")
            return "Now RECOVERED"
            
        } >>> { (value: String?, errorInfo: Task.ErrorInfo?) -> Task in // then(onFulfilled+onRejected)
            
            println("value = \(value)") // either "Now OK" or "Now RECOVERED"
            
            XCTAssertTrue(value!.hasPrefix("Now"))
            XCTAssertTrue(errorInfo == nil)
            
            return Task(error: "ABORT")
            
        } >>> { (value: String?, errorInfo: Task.ErrorInfo?) -> Void in // then(onFulfilled+onRejected)
                
            println("errorInfo = \(errorInfo)")
            
            XCTAssertTrue(value == nil)
            XCTAssertEqual(errorInfo!.error!, "ABORT")
            expect.fulfill()
                
        }
        
        self.wait()
    }

}