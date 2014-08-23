//
//  _TestCase.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

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
    
    func wait()
    {
        self.waitForExpectationsWithTimeout(3) { error in println("wait error = \(error)") }
    }
    
    var isAsync: Bool { return false }
    
    func perform(closure: Void -> Void)
    {
        if self.isAsync {
            let delaySeconds: Int64 = 100_000_000  // 100ms
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delaySeconds), dispatch_get_main_queue(), closure)
        }
        else {
            closure()
        }
    }
}