//
//  _TestCase.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

typealias ErrorString = String

class _TestCase: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        println("\n\n\n")
    }
    
    override func tearDown()
    {
        println("\n\n\n")
        super.tearDown()
    }
    
    func wait(_ timeout: NSTimeInterval = 3)
    {
        self.waitForExpectationsWithTimeout(timeout) { error in
            println("wait error = \(error)")
        }
    }
    
    var isAsync: Bool { return false }
    
    func perform(closure: Void -> Void)
    {
        if self.isAsync {
            Async.main(after: 0.01, block: closure)
        }
        else {
            closure()
        }
    }
}