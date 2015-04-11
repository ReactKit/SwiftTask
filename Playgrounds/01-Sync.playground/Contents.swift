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

typealias Progress = Float
typealias Value = String
typealias Error = NSError

typealias MyTask = Task<Progress, Value, Error>

let myError = NSError(domain: "MyErrorDomain", code: 0, userInfo: nil)

//--------------------------------------------------
// Example 1: Sync fulfilled -> success
//--------------------------------------------------

let task = MyTask(value: "Hello")
    .success { value -> String in
        return "\(value) World"
    }
    .success { value -> String in
        return "\(value)!!!"
    }

task.value

//--------------------------------------------------
// Example 2: Sync rejected -> success -> failure
//--------------------------------------------------

let task2a = MyTask(error: myError)
    .success { value -> String in
        return "Never reaches here..."
    }
let task2b = task2a
    .failure { error, isCancelled -> String in
        return "ERROR: \(error!.domain)"    // recovery from failure
    }

task2a.value
task2a.errorInfo
task2b.value
task2b.errorInfo

//--------------------------------------------------
// Example 3: Sync fulfilled or rejected -> then
//--------------------------------------------------

// fulfills or rejects immediately
let task3a = MyTask { progress, fulfill, reject, configure in
    if arc4random_uniform(2) == 0 {
        fulfill("Hello")
    }
    else {
        reject(myError)
    }
}
let task3b = task3a
    .then { value, errorInfo -> String in
        if let errorInfo = errorInfo {
            return "ERROR: \(errorInfo.error!.domain)"
        }
        
        return "\(value!) World"
    }

task3a.value
task3a.errorInfo
task3b.value
task3b.errorInfo
