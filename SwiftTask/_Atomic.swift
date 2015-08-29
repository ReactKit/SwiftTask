//
//  _Atomic.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Darwin

internal final class _Atomic<T>
{
    private var _spinlock = OS_SPINLOCK_INIT
    private var _rawValue: T
    
    internal init(_ rawValue: T)
    {
        self._rawValue = rawValue
    }
    
    internal func withRawValue<U>(@noescape f: T -> U) -> U
    {
        self._lock()
        defer { self._unlock() }
        
        return f(self._rawValue)
    }
    
    internal func update(@noescape f: T -> T) -> T
    {
        return self.updateIf { f($0) }!
    }
    
    internal func updateIf(@noescape f: T -> T?) -> T?
    {
        return self.modify { value in f(value).map { ($0, value) } }
    }
    
    internal func modify<U>(@noescape f: T -> (T, U)?) -> U?
    {
        self._lock()
        defer { self._unlock() }
        
        let oldValue = self._rawValue
        if let (newValue, retValue) = f(oldValue) {
            self._rawValue = newValue
            return retValue
        }
        else {
            return nil
        }
    }
    
    private func _lock()
    {
        withUnsafeMutablePointer(&self._spinlock, OSSpinLockLock)
    }
    
    private func _unlock()
    {
        withUnsafeMutablePointer(&self._spinlock, OSSpinLockUnlock)
    }
}

extension _Atomic: RawRepresentable
{
    internal convenience init(rawValue: T)
    {
        self.init(rawValue)
    }
    
    internal var rawValue: T
    {
        get {
            self._lock()
            defer { self._unlock() }
            
            return self._rawValue
        }
        
        set(newValue) {
            self._lock()
            defer { self._unlock() }
            
            self._rawValue = newValue
        }
    }
}

extension _Atomic: CustomStringConvertible
{
    internal var description: String
    {
        return String(self.rawValue)
    }
}