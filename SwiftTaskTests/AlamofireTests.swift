//
//  AlamofireTests.swift
//  SwiftTaskTests
//
//  Created by Yasuhiro Inami on 2014/08/21.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import Alamofire
import XCTest

class AlamofireTests: _TestCase
{
    typealias Progress = Double

    func testFulfill()
    {
        let expect = self.expectation(description: #function)
        
        let task = Task<Progress, String, Error> { progress, fulfill, reject, configure in

            Alamofire.request("http://httpbin.org/get", method: .get, parameters: ["foo": "bar"])
            .response { response in
                
                if let error = response.error {
                    reject(error)
                    return
                }
                
                fulfill("OK")
                    
            }
            
            return
            
        }
        
        task.success { (value: String) -> Void in
            XCTAssertEqual(value, "OK")
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testReject()
    {
        let expect = self.expectation(description: #function)
        
        let task = Task<Progress, String?, Error> { progress, fulfill, reject, configure in
            
            let dummyURLString = "http://xxx-swift-task.org/get"
            
            Alamofire.request(dummyURLString, method: .get, parameters: ["foo": "bar"])
            .response { response in
                
                if let error = response.error {
                    reject(error)   // pass non-nil error
                    return
                }
                
                if let status = response.response?.statusCode, status >= 300 {
                    reject(NSError(domain: "", code: 0, userInfo: nil))
                }
                
                fulfill("OK")
                
            }
            
        }
            
        task.success { (value: String?) -> Void in
            
            XCTFail("Should never reach here.")
            
        }.failure { (error: Error?, isCancelled: Bool) -> Void in
            
            XCTAssertTrue(error != nil, "Should receive non-nil error.")
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testProgress()
    {
        let expect = self.expectation(description: #function)
        
        // define task
        let task = Task<Progress, String, Error> { progress, fulfill, reject, configure in
            
            Alamofire.download("http://httpbin.org/stream/100", method: .get, to: DownloadRequest.suggestedDownloadDestination())
                
            .downloadProgress { progress_ in

                progress(progress_.fractionCompleted)
                
            }.response { response in
                
                if let error = response.error {
                    reject(error)
                    return
                }
                
                fulfill("OK")  // return nil anyway
                
            }
            
            return
            
        }
        
        // set progress & then
        task.progress { _, progress_ in
            print("progress = \(progress_)")
        }.then { value, errorInfo -> Void in
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testNSProgress()
    {
        let expect = self.expectation(description: #function)
        let nsProgress = Foundation.Progress(totalUnitCount: 100)
        
        // define task
        let task = Task<Progress, String, Error> { progress, fulfill, reject, configure in
            
            nsProgress.becomeCurrent(withPendingUnitCount: 50)
            
            // NOTE: test with url which returns totalBytesExpectedToWrite != -1
            Alamofire.download("http://httpbin.org/bytes/1024", method: .get, to: DownloadRequest.suggestedDownloadDestination())
            .response { response in
                
                if let error = response.error {
                    reject(error)
                    return
                }
                
                fulfill("OK")  // return nil anyway
                    
            }
            
            nsProgress.resignCurrent()
            
        }
        
        task.then { value, errorInfo -> Void in
            XCTAssertTrue(nsProgress.completedUnitCount == 50)
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
    func testCancel()
    {
        let expect = self.expectation(description: #function)
        
        let task = Task<Progress, String?, Error> { progress, fulfill, reject, configure in
            
            let downloadRequst = Alamofire.download("http://httpbin.org/stream/100", method: .get, to: DownloadRequest.suggestedDownloadDestination())
            .response { response in
                
                if let error = response.error {
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
            
        } // end of 1st task definition (NOTE: don't chain with `then` or `failure` for 1st task cancellation)
            
        task.success { (value: String?) -> Void in
            
            XCTFail("Should never reach here because task is cancelled.")
            
        }.failure { (error: Error?, isCancelled: Bool) -> Void in
            
            XCTAssertTrue(error == nil, "Should receive nil error via task.cancel().")
            XCTAssertTrue(isCancelled)
            
            expect.fulfill()
                
        }
        
        // cancel after 1ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            
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
