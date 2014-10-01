//
//  CustomOperatorTests.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/27.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

class AsyncCustomOperatorTests: CustomOperatorTests
{
    override var isAsync: Bool { return true }
}

class CustomOperatorTests: _TestCase
{
    // then (fulfilled & rejected)
    func testThen_both()
    {
        typealias Task = SwiftTask.Task<Float, String, ErrorString>
        
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        } >>> { (value: String?, errorInfo: Task.ErrorInfo?) -> Void in
            
            XCTAssertEqual(value!, "OK")
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    // then (fulfilled only)
    func testThen_fulfilled()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, String, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                fulfill("OK")
            }
            
        } *** { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
    // catch (rejected only)
    func testCatch()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        Task<Float, Void, ErrorString> { (progress, fulfill, reject, configure) in
            
            self.perform {
                reject("ERROR")
            }
            
        } !!! { (error: ErrorString?, isCancelled: Bool) -> Void in
            
            XCTAssertEqual(error!, "ERROR")
            XCTAssertFalse(isCancelled)
            
            expect.fulfill()
                
        }
        
        self.wait()
    }
    
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
            
        } ~ { (progress: Float) in
            
            progressCount++
            
            if self.isAsync {
                // 0.0 <= progress <= 1.0
//                XCTAssertGreaterThanOrEqual(progress, 0)  // Xcode6.1-GM bug
//                XCTAssertLessThanOrEqual(progress, 1)     // Xcode6.1-GM bug
                XCTAssertTrue(progress >= 0)
                XCTAssertTrue(progress <= 1)
                
                // 1 <= progressCount <= 5
                XCTAssertGreaterThanOrEqual(progressCount, 1)
                XCTAssertLessThanOrEqual(progressCount, 5)
            }
            else {
                XCTFail("When isAsync=false, 1st task closure is already performed before registering this progress closure, so this closure should not be reached.")
            }
            
        } *** { (value: String) -> Void in
            
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
}