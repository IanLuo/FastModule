//
//  Module.swift
//  FastModuleCore
//
//  Created by ian luo on 17/01/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation
import UIKit

public protocol ExternalType {
    func initailBindingActions()
}

public enum ModuleError: Error {
    case missingParameter(String)
    case wrongValue(String, String)
    case conditionFail(String)
}

public typealias ModuleType = Executable & Observeable & Lifecycle & Nestable

/// 模块对外统一接口
public protocol Module: class, ModuleType {
    /// 唯一指定一个模块
    static var identifier: String { get }
    /// 模块路由优先级, 相同 identifier 的模块通过优先级来决定路由对象
    static var routePriority: Int { get }
    
    var instanceIdentifier: String { get }
    
    init(request: Request)
    
    static func register()
}

public protocol Lifecycle {
    func didInit()
    func binding()
    static func request(action: String?) -> Request
    static func request(properties: [String: Any]) -> Request
    static func instance(action: String?) -> Module
    static func instance(properties: [String: Any]) -> Module
    static func request(pattern: String, arguments: Any...) -> Request
    static func instance(pattern: String, arguments: Any...) -> Module
}

public protocol Nestable {
    @discardableResult
    func addChildModule(id: String, request: Request) -> Module
    func addChildModule(id: String, module: Module)
    func childModule(id: String) -> Module?
    var childModules: [Module]? { get }
    func removeFromParent() -> Module?
}

private var propertyKey: Void?

extension Module {
    public func setProperty(key: String, value: Any) {
        if var properties = objc_getAssociatedObject(self, &propertyKey) as? [String: Any] {
            properties[key] = value
            objc_setAssociatedObject(self, &propertyKey, properties, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        } else {
            objc_setAssociatedObject(self, &propertyKey, [key: value], objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
        notify(action: key, value: value)
    }
    
    public func property<T>(key: String, type: T.Type) -> T? {
        return (objc_getAssociatedObject(self, &propertyKey) as? [String: Any])?[key] as? T
    }
    
    public func removeProperty(key: String) {
        objc_setAssociatedObject(self, &propertyKey, nil, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        let value: Any? = nil
        notify(action: key, value: value)
    }
    
    public subscript(key: String) -> Any? {
        get { return property(key: key, type: Any.self) }
        set {
            if let newValue = newValue {
                setProperty(key: key, value: newValue)
            } else {
                removeProperty(key: key)
            }
        }
    }
}

extension Module {
    public func didInit() {}
    
    internal func generalBinding() {}
    
    public func binding() {}
}

/// lifecycle implementation
extension Module {
    
    public static func request(properties: [String: Any]) -> Request {
        return self.request(pattern: "instatiate-properties/#properties", arguments: properties)
    }
    
    public static func instance(properties: [String: Any]) -> Module {
        return self.instance(pattern: "instatiate-properties/#properties", arguments: properties)
    }
    
    public static func request(pattern: String, arguments: Any...) -> Request {
        return Request(requestPattern: "//" + Self.identifier + "/" + pattern, arguments: arguments)
    }
    
    public static func instance(pattern: String, arguments: Any...) -> Module {
        let request = Self.request(pattern: pattern, arguments: arguments)
        return ModuleContext.request(request)
    }
    
    public static func request(action: String? = nil) -> Request {
        if let action = action {
            return Request(path: "//" + Self.identifier + "/" + action)
        } else {
            return Request(path: "//" + Self.identifier)
        }
    }
    
    public static func instance(action: String? = nil) -> Module {
        return ModuleContext.request(self.request(action: action)) as! Self
    }
}

extension Module {
    /// retrive the instance identifier of the current module instance
    public var instanceIdentifier: String {
        if let instanceID = property(key: "keyInstanceIdentifer", type: String.self) {
            return instanceID
        } else {
            self.setProperty(key: "keyInstanceIdentifer", value: UUID().uuidString)
            return instanceIdentifier
        }
    }
}
