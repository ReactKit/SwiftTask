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

// for async test
XCPSetExecutionShouldContinueIndefinitely()

// fulfills after 100ms
func asyncTask(value: String) -> MyTask
{
    return MyTask { progress, fulfill, reject, configure in
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100_000_000), dispatch_get_main_queue()) {
            fulfill(value)
        }
    }
}

//--------------------------------------------------
// Example 1: Async
//--------------------------------------------------

let task1a = asyncTask("Hello")
let task1b = task1a
    .success { value -> String in
        return "\(value) World"
    }

// NOTE: these values should be all nil because task is async
task1a.value
task1a.errorInfo
task1b.value
task1b.errorInfo

//--------------------------------------------------
// Example 2: Async chaining
//--------------------------------------------------

let task2a = asyncTask("Hello")
let task2b = task2a
    .success { value -> MyTask in
        return asyncTask("\(value) Cruel")  // next async
    }
    .success { value -> String in
        return "\(value) World"
    }