//
//  Handler.swift
//  SwiftTask
//
//  Created by Jordan Kay on 6/15/17.
//  Copyright © 2017 Yasuhiro Inami. All rights reserved.
//

struct HandlerToken {
    let key: Int
}

struct Handlers<T> {
    typealias KeyValue = (key: Int, value: T)
    
    private var currentKey: Int = 0
    private var elements: [KeyValue] = []
    
    mutating func append(_ value: T) -> HandlerToken {
        currentKey = currentKey &+ 1
        elements += [(key: currentKey, value: value)]
        return HandlerToken(key: currentKey)
    }
    
    mutating func remove(_ token: HandlerToken) -> T? {
        for i in 0..<elements.count {
            if elements[i].key == token.key {
                return elements.remove(at: i).value
            }
        }
        return nil
    }
    
    mutating func removeAll(keepCapacity: Bool = false) {
        elements.removeAll(keepingCapacity: keepCapacity)
    }
}

extension Handlers: Sequence {
    func makeIterator() -> AnyIterator<T> {
        return AnyIterator(elements.map { $0.value }.makeIterator())
    }
}
