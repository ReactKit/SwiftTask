//
//  Atomic.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

final class Atomic<T> {
    private var storedRawValue: T
    private var spinlock = OS_SPINLOCK_INIT
    
    init(_ rawValue: T) {
        storedRawValue = rawValue
    }
    
    func withRawValue<U>(_ f: (T) -> U) -> U {
        lock()
        defer { unlock() }
        
        return f(storedRawValue)
    }
    
    func update(_ f: (T) -> T) -> T {
        return updateIf { f($0) }!
    }
    
    func updateIf(_ f: (T) -> T?) -> T? {
        return modify { value in f(value).map { ($0, value) } }
    }
    
    func modify<U>(_ f: (T) -> (T, U)?) -> U? {
        lock()
        defer { unlock() }
        
        guard let (newValue, returnValue) = f(storedRawValue) else { return nil }
        storedRawValue = newValue
        return returnValue
    }
}

extension Atomic: RawRepresentable {
    var rawValue: T {
        get {
            lock()
            defer { unlock() }
            
            return storedRawValue
        }
        
        set {
            lock()
            defer { unlock() }
            
            storedRawValue = newValue
        }
    }
    
    convenience init(rawValue: T) {
        self.init(rawValue)
    }
}

extension Atomic: CustomStringConvertible {
    var description: String {
        return String(describing: rawValue)
    }
}

private extension Atomic {
    func lock() {
        withUnsafeMutablePointer(to: &spinlock, OSSpinLockLock)
    }
    
    func unlock() {
        withUnsafeMutablePointer(to: &spinlock, OSSpinLockUnlock)
    }
}
