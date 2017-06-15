//
//  RecursiveLock.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/18.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

final class RecursiveLock {
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>
    private let attribute: UnsafeMutablePointer<pthread_mutexattr_t>
    
    init() {
        mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        attribute = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
        
        pthread_mutexattr_init(attribute)
        pthread_mutexattr_settype(attribute, PTHREAD_MUTEX_RECURSIVE)
        pthread_mutex_init(mutex, attribute)
    }
    
    deinit {
        pthread_mutexattr_destroy(attribute)
        pthread_mutex_destroy(mutex)
        
        attribute.deallocate(capacity: 1)
        mutex.deallocate(capacity: 1)
    }
    
    func lock() {
        pthread_mutex_lock(mutex)
    }
    
    func unlock() {
        pthread_mutex_unlock(mutex)
    }
}
