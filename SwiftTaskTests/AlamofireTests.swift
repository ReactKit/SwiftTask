//
//  AlamofireTests.swift
//  SwiftTaskTests
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import XCTest

class AlamofireTests: _TestCase
{
    typealias Progress = (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)

    func testFulfill()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        let task = Task<Progress, String, NSError> { (progress, fulfill, reject, configure) in
            
            request(.GET, "http://httpbin.org/get", parameters: ["foo": "bar"])
            .response { (request, response, data, error) in
                    
                println(request)
                println(response)
                println(error)
                
                if let error = error {
                    reject(error)
                    return
                }
                
                fulfill("OK")
                    
            }
            
            return
            
        }
        
        task.then { (value: String) -> Void in
            XCTAssertEqual(value, "OK")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testReject()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        let task = Task<Progress, String?, NSError> { (progress, fulfill, reject, configure) in
            
            let dummyURLString = "http://xxx-swift-task.org/get"
            
            request(.GET, dummyURLString, parameters: ["foo": "bar"])
            .response { (request, response, data, error) in
                
                println(request)
                println(response)
                println(error)
                
                if let error = error {
                    reject(error)   // pass non-nil error
                    return
                }
                
                fulfill("OK")
                
            }
            
        }
            
        task.then { (value: String?) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Void in
            
//            println(error)
            
            XCTAssertTrue(error != nil, "Should receive non-nil error.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testProgress()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        // define task
        let task = Task<Progress, String, NSError> { (progress, fulfill, reject, configure) in
            
            download(.GET, "http://httpbin.org/stream/100", Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask))
                
            .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
                
                progress((bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) as Progress)
                
            }.response { (request, response, data, error) in
                
                println(request)
                println(response)
                println(error)
                
                if let error = error {
                    reject(error)
                    return
                }
                
                fulfill("OK")  // return nil anyway
                
            }
            
            return
            
        }
        
        // set progress & then
        task.progress { progress in
            
            println("bytesWritten = \(progress.bytesWritten)")
            println("totalBytesWritten = \(progress.totalBytesWritten)")
            println("totalBytesExpectedToWrite = \(progress.totalBytesExpectedToWrite)")
            
        }.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testNSProgress()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        var nsProgress = NSProgress(totalUnitCount: 100)
        
        // define task
        let task = Task<Progress, String, NSError> { (progress, fulfill, reject, configure) in
            
            nsProgress.becomeCurrentWithPendingUnitCount(50)
            
            // NOTE: test with url which returns totalBytesExpectedToWrite != -1
            download(.GET, "http://httpbin.org/bytes/1024", Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask))
            
            .response { (request, response, data, error) in
                
                println(request)
                println(response)
                println(error)
                
                if let error = error {
                    reject(error)
                    return
                }
                
                fulfill("OK")  // return nil anyway
                    
            }
            
            nsProgress.resignCurrent()
            
        }
        
        // set then
        task.then { (value: String) -> Void in
            
            XCTAssertEqual(value, "OK")
            XCTAssertEqual(nsProgress.completedUnitCount, 50)
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    //
    // NOTE: temporarily ignored Alamofire-cancelling test due to NSURLSessionDownloadTaskResumeData issue.
    //
    // Error log:
    //   Property list invalid for format: 100 (property lists cannot contain NULL)
    //   Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '*** setObjectForKey: object cannot be nil (key: NSURLSessionDownloadTaskResumeData)'
    // 
    // Ref:
    //   nsurlsession - (NSURLSessionDownloadTask cancelByProducingResumeData) crashes nsnetwork daemon iOS 7.0 - Stack Overflow
    //   http://stackoverflow.com/questions/25297750/nsurlsessiondownloadtask-cancelbyproducingresumedata-crashes-nsnetwork-daemon
    //
    func __testCancel()
    {
        var expect = self.expectationWithDescription(__FUNCTION__)
        
        let task = Task<Progress, String?, NSError> { (progress, fulfill, reject, configure) in
            
            let downloadRequst = download(.GET, "http://httpbin.org/stream/100", Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask))

            .response { (request, response, data, error) in
                
                println(request)
                println(response)
                println(error)
                
                if let error = error {
                    reject(error)
                    return
                }
                
                fulfill("OK")
                    
            }
            
            // configure cancel for cleanup after reject or task.cancel()
            // NOTE: use weak to let task NOT CAPTURE downloadRequst via configure
            configure.cancel = { [weak downloadRequst] in
                if let downloadRequst = downloadRequst {
                    downloadRequst.cancel()
                }
            }
            
        } // end of 1st task definition (NOTE: don't chain with `then` or `catch` for 1st task cancellation)
            
        task.then { (value: String?) -> Void in
            
            XCTFail("Should never reach here because task is cancelled.")
            
        }.catch { (error: NSError?, isCancelled: Bool) -> Void in
            
//            println(error)
            
            XCTAssertTrue(error == nil, "Should receive nil error via task.cancel().")
            XCTAssertTrue(isCancelled)
            
            expect.fulfill()
                
        }
        
        // cancel after 1ms
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1_000_000), dispatch_get_main_queue()) {
            
            task.cancel()   // sends no error
            
            XCTAssertEqual(task.state, TaskState.Cancelled)
            
        }
        
        self.wait()
    }

    // TODO:
    func __testPauseResume()
    {

    }
}
