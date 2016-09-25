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
        
        let expect = self.expectation(description: #function)
        
        var latestProgressValue: Float?
        var canceller: AutoCanceller? = nil
        
        // define task
        Task { progress, fulfill, reject, configure in
            progress(0.0)
            Async.main(after: 0.1) {
                progress(1.0)
                fulfill("OK")
            }
        }.progress { oldProgress, newProgress in
            
            print("progress1 = \(newProgress)")
            latestProgressValue = newProgress
        
        }.progress(&canceller) { oldProgress, newProgress in
            
            print("progress2 = \(newProgress)")
            XCTFail("Should never reach here because this progress-handler will be removed soon.")
            
        }.then { value, errorInfo -> Void in
            
            XCTAssertTrue(value == "OK")
            XCTAssertTrue(errorInfo == nil)
            expect.fulfill()
                
        }
        
        XCTAssertTrue(canceller != nil, "Async `task` will return non-nil `progressToken`.")
        
        // remove progress-handler
        canceller = nil
        
        self.wait()
        
        XCTAssertTrue(latestProgressValue == 1.0)
    }
    
    func testRemoveThen()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>

        let expect = self.expectation(description: #function)
        var canceller: AutoCanceller? = nil
        
        // define task
        Task { progress, fulfill, reject, configure in
            
            Async.main(after: 0.1) {
                fulfill("OK")
            }
            return
            
        }.success { value -> String in
                
            XCTAssertEqual(value, "OK")
            return "Now OK"
        
        }.then(&canceller) { value, errorInfo -> String in
            
            print("Should never reach here")
            
            XCTFail("Should never reach here because this then-handler will be removed soon.")
            
            return "Never reaches here"
            
        }.then { value, errorInfo -> Void in
            
            print("value = \(value)")
            print("errorInfo = \(errorInfo)")
            
            XCTAssertTrue(value == nil)
            XCTAssertTrue(errorInfo != nil)
            XCTAssertTrue(errorInfo!.error == nil)
            XCTAssertTrue(errorInfo!.isCancelled, "Deallocation of `canceller` will force `task2` (where `task2 = task.then(&canceller)`) to deinit immediately and tries cancellation if it is still running.")
            
            expect.fulfill()
                
        }
        
        // remove then-handler
        canceller = nil
        
        self.wait()
    }
}
