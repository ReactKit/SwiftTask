//
//  RetainCycleTests.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

class Player
{
    var completionHandler: (() -> Void)?
    
    init()
    {
//        println("[init] \(self)")
    }
    
    deinit
    {
//        println("[deinit] \(self)")
    }
    
    func doSomething(completion: (() -> Void)? = nil)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) { /*[weak self] in */
            
            // NOTE: callback (either as argument or stored property) must be captured by dispatch_queue
            
            if let completion = completion {
                completion()    // NOTE: interestingly, self is also captured by just calling completion() if [weak self] is not set
            }
            else {
                self.completionHandler?()
            }
        }
    }
    
    func cancel()
    {
        // no operation, just for capturing test
    }
}

class RetainCycleTests: _TestCase
{
    typealias Task = SwiftTask.Task<Float, String, ErrorString>
    
    // weak properties for inspection
    weak var task: Task?
    weak var player: Player?
    
    func testPlayer_completionAsArgument_notConfigured()
    {
        let expect = self.expectation(description: #function)
        
        //
        // retain cycle:
        // ("x->" = will be released shortly)
        //
        // 1. dispatch_queue x-> task
        // dispatch_queue (via player impl) x-> completion -> fulfill -> task
        //
        // 2. dispatch_queue x-> player
        // dispatch_queue (via player impl) x-> player (via completion capturing)
        //
        self.task = Task { progress, fulfill, reject, configure in
            
            let player = Player()
            self.player = player
            
            // comment-out: no configuration test
//            configure.cancel = { player.cancel() }
            
            player.doSomething {
                fulfill("OK")
            }
            
        }
        
        XCTAssertNotNil(self.task, "self.task (weak) should NOT be nil because of retain cycle: task <- dispatch_queue.")
        XCTAssertNotNil(self.player, "self.player (weak) should NOT nil because player is not retained by dispatch_queue.")
        
        self.task!.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }
        
        self.wait()
        
        XCTAssertNil(self.task)
        XCTAssertNil(self.player)
    }
    
    func testPlayer_completionAsArgument_configured()
    {
        let expect = self.expectation(description: #function)
        
        //
        // retain cycle:
        // ("x->" = will be released shortly)
        //
        // 1. dispatch_queue x-> task
        // dispatch_queue (via player impl) x-> completion -> fulfill -> task
        //
        // 2. dispatch_queue x-> player
        // dispatch_queue (via player impl) x-> player (via completion capturing)
        //
        // 3. task -> player
        // task -> task.machine -> configure (via pause/resume addEventHandler) -> configure.cancel -> player
        //
        self.task = Task { progress, fulfill, reject, configure in
            
            let player = Player()
            self.player = player
            
            configure.cancel = { player.cancel() }
            
            player.doSomething {
                fulfill("OK")
            }
            
        }
        
        XCTAssertNotNil(self.task, "self.task (weak) should NOT be nil because of retain cycle: task <- dispatch_queue.")
        XCTAssertNotNil(self.player, "self.player (weak) should NOT be nil because of retain cycle: player <- configure <- task.")
        
        self.task!.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }
        
        self.wait()
        
        XCTAssertNil(self.task)
        XCTAssertNil(self.player)
    }
    
    func testPlayer_completionAsStoredProperty_notConfigured()
    {
        let expect = self.expectation(description: #function)
        
        //
        // retain cycle:
        // ("x->" = will be released shortly)
        //
        // 1. dispatch_queue x-> player -> task
        // dispatch_queue (via player impl) x-> player -> player.completionHandler -> fulfill -> task
        //
        self.task = Task { progress, fulfill, reject, configure in
            
            let player = Player()
            self.player = player
            
            // comment-out: no configuration test
//            configure.cancel = { player.cancel() }
            
            player.completionHandler = {
                fulfill("OK")
            }
            player.doSomething()
            
        }
        
        XCTAssertNotNil(self.task, "self.task (weak) should not be nil because of retain cycle: task <- player <- dispatch_queue.")
        XCTAssertNotNil(self.player, "self.player (weak) should not be nil because of retain cycle: player <- configure <- task.")
        
        self.task!.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }
        
        self.wait()
        
        XCTAssertNil(self.task)
        XCTAssertNil(self.player)
    }
    
    func testPlayer_completionAsStoredProperty_configured()
    {
        let expect = self.expectation(description: #function)
        
        //
        // retain cycle:
        // ("x->" = will be released shortly)
        //
        // 1. dispatch_queue x-> player -> task
        // dispatch_queue (via player impl) x-> player -> player.completionHandler -> fulfill -> task
        //
        // 2. task x-> player
        // task -> task.machine -> configure (via pause/resume addEventHandler) -> configure.pause/resume/cancel x-> player
        //
        self.task = Task { progress, fulfill, reject, configure in
            
            let player = Player()
            self.player = player
            
            configure.cancel = { player.cancel() }
            
            player.completionHandler = {
                fulfill("OK")
            }
            player.doSomething()
            
        }
        
        XCTAssertNotNil(self.task, "self.task (weak) should not be nil because of retain cycle: task <- player <- dispatch_queue.")
        XCTAssertNotNil(self.player, "self.player (weak) should not be nil because of retain cycle: player <- configure <- task.")
        
        self.task!.success { value -> Void in
            
            XCTAssertEqual(value, "OK")
            expect.fulfill()
            
        }
        
        self.wait()
    
        XCTAssertNil(self.task)
        XCTAssertNil(self.player)
    }
}
