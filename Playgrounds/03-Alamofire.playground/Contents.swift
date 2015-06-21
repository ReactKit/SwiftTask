//: Playground - noun: a place where people can play

import Cocoa
import XCPlayground

//
// NOTE: custom framework needs to be built first (and restart Xcode if needed)
//
// Importing Custom Frameworks Into a Playground
// https://developer.apple.com/library/prerelease/ios/recipes/Playground_Help/Chapters/ImportingaFrameworkIntoaPlayground.html
//
import SwiftTask
import Alamofire

typealias Progress = (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
typealias Value = String
typealias Error = NSError

typealias AlamofireTask = Task<Progress, Value, Error>

let myError = NSError(domain: "MyErrorDomain", code: 0, userInfo: nil)

// for async test
XCPSetExecutionShouldContinueIndefinitely()

//--------------------------------------------------
// Example 1: Alamofire progress
//--------------------------------------------------

// define task
let task = AlamofireTask { progress, fulfill, reject, configure in
    
    let request = Alamofire.download(.GET, URLString: "http://httpbin.org/stream/100", destination: Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask))
        
    request
        .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
            progress((bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) as Progress)
        }
        .response { (request, response, data, error) in
            
            // print
            data
            error?.localizedDescription
            
            if let error = error {
                reject(error)
                return
            }
            
            fulfill("OK")
            
        }
}

task
    .progress { oldProgress, newProgress in
        // print
        newProgress.bytesWritten
        newProgress.totalBytesWritten
    }
    .then { value, errorInfo -> String in
        if let errorInfo = errorInfo {
            return "ERROR: \(errorInfo.error!.domain)"
        }
        
        return "\(value!) World"
    }
