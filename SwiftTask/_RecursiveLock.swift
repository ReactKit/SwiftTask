//
//  _RecursiveLock.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Darwin

internal final class _RecursiveLock
{
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>
    private let attribute: UnsafeMutablePointer<pthread_mutexattr_t>
    
    internal init()
    {
        self.mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        self.attribute = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
        
        pthread_mutexattr_init(self.attribute)
        pthread_mutexattr_settype(self.attribute, PTHREAD_MUTEX_RECURSIVE)
        pthread_mutex_init(self.mutex, self.attribute)
    }
    
    deinit
    {
        pthread_mutexattr_destroy(self.attribute)
        pthread_mutex_destroy(self.mutex)
        #if swift(>=4.1)
        self.attribute.deallocate()
        #else
        self.attribute.deallocate(capacity: 1)
        #endif
        #if swift(>=4.1)
        self.mutex.deallocate()
        #else
        self.mutex.deallocate(capacity: 1)
        #endif
    }
    
    internal func lock()
    {
        pthread_mutex_lock(self.mutex)
    }
    
    internal func unlock()
    {
        pthread_mutex_unlock(self.mutex)
    }
}
