//
//  _TestCase.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import Async
import XCTest

typealias ErrorString = String

class _TestCase: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        print("\n\n\n")
    }
    
    override func tearDown()
    {
        print("\n\n\n")
        super.tearDown()
    }
    
    func wait(_ timeout: TimeInterval = 3)
    {
        self.waitForExpectations(timeout: timeout) { error in
            print("wait error = \(error)")
        }
    }
    
    var isAsync: Bool { return false }
    
    func perform(closure: @escaping () -> Void)
    {
        if self.isAsync {
            Async.main(after: 0.01, closure)
        }
        else {
            closure()
        }
    }
}
