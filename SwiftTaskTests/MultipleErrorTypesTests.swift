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
    enum MyEnum: CustomStringConvertible
    {
        case Default
        var description: String { return "MyEnumDefault" }
    }
    
    struct Dummy {}
    
    typealias Task1 = Task<String, String, String>
    typealias Task2 = Task<MyEnum, MyEnum, MyEnum>
    
    var flow = [Int]()
    
    // delayed task + counting flow 1 & 2
    func _task1(ok: Bool) -> Task1
    {
        return Task1 { progress, fulfill, reject, configure in
            print("[task1] start")
            self.flow += [1]
            
            Async.main(after: 0.1) {
                print("[task1] end")
                self.flow += [2]
                
                ok ? fulfill("OK") : reject("NG")
            }
            return
        }
    }
    
    // delayed task + counting flow 4 & 5
    func _task2(ok: Bool) -> Task2
    {
        return Task2 { progress, fulfill, reject, configure in
            print("[task2] start")
            self.flow += [4]
            
            Async.main(after: 0.1) {
                print("[task2] end")
                self.flow += [5]
                
                ok ? fulfill(.Default) : reject(.Default)
            }
            return
        }
    }
    
    func testMultipleErrorTypes_then()
    {
        let expect = self.expectation(description: #function)
        
        self._task1(ok: true)
            .then { value, errorInfo -> Task2 in
                
                print("task1.then")
                self.flow += [3]
                
                return self._task2(ok: true)
                
            }
            .then { value, errorInfo -> Void in
                
                print("task1.then.then (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                expect.fulfill()
                
            }
        
        self.wait()
    }
    
    func testMultipleErrorTypes_success()
    {
        let expect = self.expectation(description: #function)
        
        self._task1(ok: true)
            .success { value -> Task2 in
                
                print("task1.success")
                self.flow += [3]
                
                return self._task2(ok: true)
                
            }
            .success { value -> Void in
                
                print("task1.success.success (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                expect.fulfill()
                
            }
        
        self.wait()
    }

    func testMultipleErrorTypes_success_differentErrorType()
    {
        let expect = self.expectation(description: #function)
        
        self._task1(ok: true)
            .success { value -> Task2 in
                
                print("task1.success")
                self.flow += [3]
                
                //
                // NOTE: 
                // If Task1 and Task2 have different Error types,
                // returning `self._task2(ok: false)` inside `self._task1.success()` will fail error conversion 
                // (Task2.Error -> Task1.Error).
                //
                return self._task2(ok: false) // inner rejection with different Error type
                
            }
            .then { value, errorInfo -> Void in
                
                print("task1.success.success (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                
                XCTAssertTrue(value == nil)
                XCTAssertTrue(errorInfo != nil)
                XCTAssertTrue(errorInfo!.error == nil, "Though `errorInfo` will still be non-nil, `errorInfo!.error` will become as `nil` if Task1 and Task2 have different Error types.")
                XCTAssertTrue(errorInfo!.isCancelled == false)
                
                expect.fulfill()
                
            }
        
        self.wait()
    }
    
    func testMultipleErrorTypes_success_differentErrorType_conversion()
    {
        let expect = self.expectation(description: #function)
        
        self._task1(ok: true)
            .success { value -> Task<Void, MyEnum, String> in
                
                print("task1.success")
                self.flow += [3]
                
                //
                // NOTE:
                // Since returning `self._task2(ok: false)` inside `self._task1.success()` will fail error conversion
                // (Task2.Error -> Task1.Error) as seen in above test case,
                // it is **user's responsibility** to add conversion logic to maintain same Error type throughout task-flow.
                //
                return self._task2(ok: false)
                    .failure { Task<Void, MyEnum, String>(error: "Mapping errorInfo=\($0.error!) to String") }  // error-conversion
                
            }
            .then { value, errorInfo -> Void in
                
                print("task1.success.success (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                
                XCTAssertTrue(value == nil)
                XCTAssertTrue(errorInfo != nil)
                XCTAssertEqual(errorInfo!.error!, "Mapping errorInfo=MyEnumDefault to String",
                    "Now `self._task2()`'s error is catched by this scope by adding manual error-conversion logic by user side.")
                XCTAssertTrue(errorInfo!.isCancelled == false)
                
                expect.fulfill()
                
        }
        
        self.wait()
    }

    func testMultipleErrorTypes_failure()
    {
        let expect = self.expectation(description: #function)
        
        self._task1(ok: false)
            .failure { errorInfo -> Task<Dummy, String /* must be task1's value type to recover */, Dummy> in
                
                print("task1.failure")
                self.flow += [3]
                
                //
                // NOTE:
                // Returning `Task2` won't work since same Value type as `task1` is required inside `task1.failure()`,
                // so use `then()` to promote `Task2` to `Task<..., Task1.Value, ...>`.
                //
                return self._task2(ok: false).then { value, errorInfo in
                    return Task<Dummy, String, Dummy>(error: Dummy())  // error task
                }
            }
            .failure { errorInfo -> String /* must be task1's value type to recover */ in
                
                print("task1.failure.failure (task2 should end at this point)")
                self.flow += [6]
                
                XCTAssertEqual(self.flow, Array(1...6), "Tasks should flow in order from 1 to 6.")
                expect.fulfill()
                
                return "DUMMY"
            }
        
        self.wait()
    }
}
