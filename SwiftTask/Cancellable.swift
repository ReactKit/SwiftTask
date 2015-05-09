//
//  Cancellable.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/09.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation

public protocol Cancellable
{
    typealias Error
    
    func cancel(error: Error) -> Bool
}

public class Canceller: Cancellable
{
    private var cancelHandler: (Void -> Void)?
    
    public required init(cancelHandler: Void -> Void)
    {
        self.cancelHandler = cancelHandler
    }
    
    public func cancel(error: Void) -> Bool
    {
        if let cancelHandler = self.cancelHandler {
            self.cancelHandler = nil
            cancelHandler()
            return true
        }
        
        return false
    }
}

public class AutoCanceller: Canceller
{
    deinit
    {
        self.cancel()
    }
}