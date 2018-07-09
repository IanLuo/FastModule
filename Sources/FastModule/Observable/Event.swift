//
//  Event.swift
//  Module
//
//  Created by ian luo on 17/01/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation

/// Raw content of an Request
public struct Event {
    public enum Result<Type> {
        case success(Type)
        case failure(Error)
        
        public var value: Type? {
            switch self {
            case .failure(_): return nil
            case .success(let value): return value
            }
        }
    }
    
    /// 返回内容
    public var content: Result<Any?>

    /// module
    public var module: Module
    
    public var action: String
    
    public static func success(_ value: Any?,
                               action: String,
                               module: Module) -> Event {
        return Event(content: Result<Any?>.success(value),
                     module: module,
                     action: action)
    }
    
    public static func failure(_ error: Error,
                               action: String,
                               module: Module) -> Event {
        return Event(content: Result<Any?>.failure(error),
                     module: module,
                     action: action)
    }
    
    public var flatten: Event {
        if let nested = content.value as? Event {
            return nested
        } else {
            return self
        }
    }
}

extension Event: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Event: \n \(content) \n \(type(of: module).identifier)"
    }
}
