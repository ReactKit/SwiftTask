//
//  Cancellable.swift
//  SwiftTask
//
//  Created by Yasuhiro Inami on 2015/05/09.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

public protocol Cancellable {
    associatedtype ErrorType
    
    func cancel(error: ErrorType) -> Bool
}

public class Canceller: Cancellable {
    private var cancelHandler: (() -> Void)?
    
    public required init(cancelHandler: @escaping () -> Void) {
        self.cancelHandler = cancelHandler
    }
    
    @discardableResult public func cancel(error: Void = ()) -> Bool {
        guard let cancelHandler = cancelHandler else { return false }
        
        self.cancelHandler = nil
        cancelHandler()
        return true
    }
}

public class AutoCanceller: Canceller {
    deinit {
        cancel()
    }
}
