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
    associatedtype _Error
    
    func cancel(error: _Error) -> Bool
}

public class Canceller: Cancellable
{
    private var cancelHandler: (() -> Void)?
    
    public required init(cancelHandler: @escaping () -> Void)
    {
        self.cancelHandler = cancelHandler
    }
    
    @discardableResult public func cancel(error: Void = ()) -> Bool
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
