//
//  Dictionary+AccessTypedValue.swift
//  FastModuleCore
//
//  Created by ian luo on 09/03/2018.
//

import Foundation

extension Dictionary {
    public func value<T>(_ key: Key, type: T.Type) -> T? {
        return self[key] as? T
    }
    
    public func int(_ key: Key) -> Int? {
        switch self[key] {
        case let value where value is String:
            return Int(value as? String ?? "")
        case let value where value is Int:
            return value as? Int
        case let value:
            return value as? Int
        }
    }
    
    public func double(_ key: Key) -> Double? {
        switch self[key] {
        case let value where value is String:
            return Double(value as? String ?? "")
        case let value where value is Double:
            return value as? Double
        case let value:
            return value as? Double
        }
    }
    
    public func truthy(_ key: Key) -> Bool {
        switch self[key] {
        case let value where value is String:
            return (value as? String ?? "").lowercased() == "true"
        case let value where value is Bool:
            return (value as? Bool) ?? false
        case let value where value is Int:
            return (int(key) ?? 0) > 0
        case let value where value is Double:
            return (double(key) ?? 0) > 0
        default:
            return false
        }
    }
}
