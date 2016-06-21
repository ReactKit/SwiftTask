//
//  _InterruptableTask.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2014/12/25.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask
import Async
typealias _InterruptableTask = Task<Int, String, String>

/// 1. Invokes `progressCount/2` progresses at t=0.2
/// 2. Checks cancel & pause at t=0.4
/// 3. Invokes remaining `progressCount-progressCount/2` progresses at t=0.4~ (if not paused)
/// 4. Either fulfills with "OK" or rejects with "ERROR" at t=0.4~ (if not paused)
func _interruptableTask(progressCount: Int, finalState: TaskState = .Fulfilled) -> _InterruptableTask
{
    return _InterruptableTask { progress, fulfill, reject, configure in
        
        // NOTE: not a good flag, watch out for race condition!
        var isCancelled = false
        var isPaused = false
        
        // 1st delay (t=0.2)
        Async.background(after: 0.2) {
            
            for p in 1...progressCount/2 {
                Async.main { progress(p) }
            }
            
            // 2nd delay (t=0.4)
            Async.background(after: 0.2) {
                
                // NOTE: no need to call reject() because it's already rejected (cancelled) internally
                if isCancelled { return }
                
                while isPaused {
                    print("pausing...")
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                for p in progressCount/2+1...progressCount {
                    Async.main { progress(p) }
                }
                
                Async.main {
                    if finalState == .Fulfilled {
                        fulfill("OK")
                    }
                    else {
                        reject("ERROR")
                    }
                }
            }
        }
        
        configure.pause = {
            isPaused = true;
            return
        }
        configure.resume = {
            isPaused = false;
            return
        }
        configure.cancel = {
            isCancelled = true;
            return
        }
        
    }
}
