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
    
    internal var rawValue: T
    {
        get {
            self._lock()
            let rawValue = self._rawValue
            self._unlock()
            
            return rawValue
        }
        
        set(newValue) {
            self._lock()
            self._rawValue = newValue
            self._unlock()
        }
    }
    
    internal init(_ rawValue: T)
    {
        self._rawValue = rawValue
    }
    
    internal func update(f: T -> T) -> T
    {
        self._lock()
        let oldValue = self._rawValue
        self._rawValue = f(oldValue)
        self._unlock()
        
        return oldValue
    }
    
    internal func tryUpdate(f: T -> (T, Bool)) -> (T, Bool)
    {
        self._lock()
        let oldValue = self._rawValue
        let (newValue, shouldUpdate) = f(oldValue)
        if shouldUpdate {
            self._rawValue = newValue
        }
        self._unlock()
        
        return (oldValue, shouldUpdate)
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

extension _Atomic: Printable
{
    internal var description: String
    {
        return toString(self.rawValue)
    }
}