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
    private var spinlock = OS_SPINLOCK_INIT
    private var _rawValue: T
    
    internal var rawValue: T
    {
        get {
            lock()
            let rawValue = self._rawValue
            unlock()
            
            return rawValue
        }
        
        set(newValue) {
            lock()
            self._rawValue = newValue
            unlock()
        }
    }
    
    init(_ rawValue: T)
    {
        self._rawValue = rawValue
    }
    
    private func lock()
    {
        withUnsafeMutablePointer(&self.spinlock, OSSpinLockLock)
    }
    
    private func unlock()
    {
        withUnsafeMutablePointer(&self.spinlock, OSSpinLockUnlock)
    }
}