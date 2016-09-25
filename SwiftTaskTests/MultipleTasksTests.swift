//
//  MultipleTasksTests.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2016-05-07.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

/// Generic type for value/error to demonstrate multiple tasks working on different types.
private enum MyEnum<T> { case Default }

private typealias Value1 = MyEnum<()>
private typealias Error1 = MyEnum<Bool>
private typealias Value2 = MyEnum<Float>
private typealias Error2 = MyEnum<Double>
private typealias Value3 = MyEnum<Int>
private typealias Error3 = MyEnum<String>

/// Wrapped error type to unify `Error1`/`Error2`/`Error3`.
private enum WrappedError
{
    case ByTask1(Error1)
    case ByTask2(Error2)
    case ByTask3(Error3)

    /// For external cancellation -> internal rejection conversion.
    case Cancelled
}

class MultipleTasksTests: _TestCase
{
    func testMultipleTasksTests_success1_success2_success3()
    {
        let expect = self.expectation(description: #function)

        var flow = [Int]()

        let task1 = { Task<(), Value1, Error1>(value: .Default).on(success: { _ in flow.append(1) }) }
        let task2 = { Task<(), Value2, Error2>(value: .Default).on(success: { _ in flow.append(2) }) }
        let task3 = { Task<(), Value3, Error3>(value: .Default).on(success: { _ in flow.append(3) }) }

        task1()._mapError(WrappedError.ByTask1)
            .success { _ in
                task2()._mapError(WrappedError.ByTask2)
            }
            .success { _ in
                task3()._mapError(WrappedError.ByTask3)
            }
            .on(success: { _ in
                XCTAssertEqual(flow, [1, 2, 3])
                expect.fulfill()
            })

        self.wait()
    }

    func testMultipleTasksTests_success1_success2_failure3()
    {
        let expect = self.expectation(description: #function)

        var flow = [Int]()

        let task1 = { Task<(), Value1, Error1>(value: .Default).on(success: { _ in flow.append(1) }) }
        let task2 = { Task<(), Value2, Error2>(value: .Default).on(success: { _ in flow.append(2) }) }
        let task3 = { Task<(), Value3, Error3>(error: .Default).on(success: { _ in flow.append(3) }) }

        task1()._mapError(WrappedError.ByTask1)
            .success { _ in
                task2()._mapError(WrappedError.ByTask2)
            }
            .success { _ in
                task3()._mapError(WrappedError.ByTask3)
            }
            .on(failure: { error, isCancelled in
                guard case let .some(.ByTask3(error3)) = error else {
                    XCTFail("Wrong WrappedError.")
                    return
                }
                XCTAssertEqual(error3, Error3.Default)
                XCTAssertEqual(flow, [1, 2])
                expect.fulfill()
            })
        
        self.wait()
    }

    func testMultipleTasksTests_success1_failure2_success3()
    {
        let expect = self.expectation(description: #function)

        var flow = [Int]()

        let task1 = { Task<(), Value1, Error1>(value: .Default).on(success: { _ in flow.append(1) }) }
        let task2 = { Task<(), Value2, Error2>(error: .Default).on(success: { _ in flow.append(2) }) }
        let task3 = { Task<(), Value3, Error3>(value: .Default).on(success: { _ in flow.append(3) }) }

        task1()._mapError(WrappedError.ByTask1)
            .success { _ in
                task2()._mapError(WrappedError.ByTask2)
            }
            .success { _ in
                task3()._mapError(WrappedError.ByTask3)
            }
            .on(failure: { error, isCancelled in
                guard case let .some(.ByTask2(error2)) = error else {
                    XCTFail("Wrong WrappedError.")
                    return
                }
                XCTAssertEqual(error2, Error2.Default)
                XCTAssertEqual(flow, [1])
                expect.fulfill()
            })
        
        self.wait()
    }
    
    func testMultipleTasksTests_success1_failure2_success3_wrapped()
    {
        let expect = self.expectation(description: #function)
        
        var flow = [Int]()
        
        let task1 = { Task<(), Value1, Error1>(value: .Default).on(success: { _ in flow.append(1) }) }
        let wrapped1 = wrappedErrorTask(task1, f: WrappedError.ByTask1)
        
        let task2 = { Task<(), Value2, Error2>(error: .Default).on(success: { _ in flow.append(2) }) }
        let wrapped2 = wrappedErrorTask(task2, f: WrappedError.ByTask2)
        
        let task3 = { Task<(), Value3, Error3>(value: .Default).on(success: { _ in flow.append(3) }) }
        let wrapped3 = wrappedErrorTask(task3, f: WrappedError.ByTask3)
        
        XCTAssertEqual(flow, [])
        
        wrapped1()
            .success { _ in
                wrapped2()
            }
            .success { _ in
                wrapped3()
            }
            .on(failure: { error, isCancelled in
                guard case let .some(.ByTask2(error2)) = error else {
                    XCTFail("Wrong WrappedError.")
                    return
                }
                XCTAssertEqual(error2, Error2.Default)
                XCTAssertEqual(flow, [1])
                expect.fulfill()
            })
        
        self.wait()
    }
}

extension Task
{
    /// Converts `Task<..., Error>` to `Task<..., WrappedError>`.
    fileprivate func _mapError(_ f: @escaping (Error) -> WrappedError) -> Task<Progress, Value, WrappedError>
    {
        return self.failure { error, isCancelled -> Task<Progress, Value, WrappedError> in
            if let error = error {
                return Task<Progress, Value, WrappedError>(error: f(error))
            }
            else {
                // converts external cancellation -> internal rejection
                return Task<Progress, Value, WrappedError>(error: .Cancelled)
            }
        }
    }
}

private func wrappedErrorTask<P,V,E>(_ task: @escaping () -> Task<P,V,E>, f: @escaping (E) -> WrappedError) -> () -> Task<P,V,WrappedError> {
    return {
        task()._mapError(f)
    }
}
