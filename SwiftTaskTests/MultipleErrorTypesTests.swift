//
//  MultipleErrorTypesTests.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/24.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import Async
import XCTest

class MultipleErrorTypesTests: _TestCase
{
    enum MyEnum
    {
        case Default
    }
    
    struct Dummy {}
    
    typealias Task1 = Task<String, String, String>
    typealias Task2 = Task<MyEnum, MyEnum, MyEnum>
    
    var flow = [Int]()
    
    // delayed task + counting flow 1 & 2
    func _task1(#success: Bool) -> Task1
    {
        return Task1 { progress, fulfill, reject, configure in
            println("[task1] start")
            self.flow += [1]
            
            Async.main(after: 0.1) {
                println("[task1] end")
                self.flow += [2]
                
                success ? fulfill("OK") : reject("NG")
            }
            return
        }
    }
    
    // delayed task + counting flow 4 & 5
    func _task2(#success: Bool) -> Task2
    {
        return Task2 { progress, fulfill, reject, configure in
            println("[task2] start")
            self.flow += [4]
            
            Async.main(after: 0.1) {
                println("[task2] end")
                self.flow += [5]
                
                success ? fulfill(.Default) : reject(.Default)
            }
            return
        }
    }
    
    func testMultipleErrorTypes_then()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        self._task1(success: true)
            .then { value, errorInfo -> Task2 in
                
                println("task1.then")
                self.flow += [3]
                
                return self._task2(success: true)
                
            }
            .then { value, errorInfo -> Void in
                
                println("task1.then.then (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                expect.fulfill()
                
            }
        
        self.wait()
    }
    
    func testMultipleErrorTypes_success()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        self._task1(success: true)
            .success { value -> Task2 in
                
                println("task1.success")
                self.flow += [3]
                
                return self._task2(success: true)
                
            }
            .success { value -> Void in
                
                println("task1.success.success (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                expect.fulfill()
                
            }
        
        self.wait()
    }

    func testMultipleErrorTypes_failure()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        self._task1(success: false)
            .failure { errorInfo -> Task<Dummy, String /* must be task1's value type to recover */, Dummy> in
                
                println("task1.failure")
                self.flow += [3]
                
                //
                // NOTE:
                // Returning `Task2` won't work since same Value type as `task1` is required inside `task1.failure()`,
                // so use `then()` to promote `Task2` to `Task<..., Task1.Value, ...>`.
                //
                return self._task2(success: false).then { value, errorInfo in
                    return Task<Dummy, String, Dummy>(error: Dummy())  // error task
                }
            }
            .failure { errorInfo -> String /* must be task1's value type to recover */ in
                
                println("task1.failure.failure (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                expect.fulfill()
                
                return "DUMMY"
            }
        
        self.wait()
    }
}