//
//  Request.swift
//  FastModuleCore
//
//  Created by ian luo on 17/01/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation

private struct Constants {
    static let keyApp = "keyApp"
    static let keyModlule = "keyModlule"
    static let keyAction = "keyAction"
    static let keyPriority = "keyPriority"
    static let keyParameters = "keyParameters"
}

/// 模块的一个操作，被封装为一个请求。
///
/// - 如果请求被发送至 ModuleContext，将会创建一个对应的 module 实例，如果有 action，在实例初始化完成后，会执行这个 action
/// - 如果请求被发送至一个 Module 的实例，将会忽略请求的定位 module 的部分，也就是除开 action 的 path 的前半部分，获取 action 后执行 module 中的对应方法
public struct Request: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    /// 通过字符串创建请求对象，参数的类型全部为字符串
    public init(stringLiteral value: StringLiteralType) {
        var value = value
        if case let extractURLParameter = value.extractEmbededURL(), extractURLParameter.count > 0 {
            extractURLParameter.forEach {
                self[$0.key] = $0.value
            }
        }
        
        let urlString = value.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.union(.urlHostAllowed).union(.urlQueryAllowed).union(.urlFragmentAllowed)) ?? ""

        if let url = URL(string: urlString) {
            storage[ModuleContext.Priority.key] = ModuleContext.Priority.default
            storage[ModuleContext.InstanceStyle.key] = ModuleContext.InstanceStyle.default
            storage[Constants.keyApp] = url.scheme ?? "local"
            storage[Constants.keyModlule] = url.host
            storage[Constants.keyAction] = url.path.dropHead { $0 == "/" }
            
            url.query?
                .components(separatedBy: "&")
                .map { $0.components(separatedBy: "=") }
                .filter { $0.count > 1 }
                .reduce([String: Any]()) { last, next in
                    var new = last; new[next[0]] = next[1]; return new
                }
                .filter { (key, value) in
                    switch key {
                    case ModuleContext.Priority.key:
                        storage[ModuleContext.Priority.key] = Int(value as! String)
                        return false
                    case ModuleContext.InstanceStyle.key:
                        storage[ModuleContext.InstanceStyle.key] = ModuleContext.InstanceStyle(rawValue: value as! String)
                        return false
                    default: return true
                    }
                }
                .forEach({
                    self[$0.key] = $0.value
                })
        }
    }
    
    /// 初始化请求
    /// - Parameter path: 请求路径
    /// - Parameter parametersDatasource: 返回一个字典，作为请求的参数
    public init(path: String,
                instanceStyle: String? = ModuleContext.InstanceStyle.new.rawValue,
                priority: Int? = 1,
                parameter: [String : Any]? = nil) {
        
        self.init(stringLiteral: path)
        storage[ModuleContext.InstanceStyle.key] = ModuleContext.InstanceStyle(rawValue: instanceStyle ?? "")
        storage[ModuleContext.Priority.key] = priority
        
        parameter?.forEach {
            self[$0.key] = $0.value
        }
    }
    
    /// 用于初始化参数不能转换为字符串的请求
    public init(requestPattern: String, arguments: Any...) {
        self.init(requestPattern: requestPattern, arguments: arguments)
    }
    
    public init(requestPattern: String, arguments: [Any]) {
        var request = Request(stringLiteral: requestPattern)
        
        let keys = request.action.requestPatternKeys
        
        guard keys.count <= arguments.count
            else { fatalError("not enough arguments. key placeholders((\(keys.count)), arguments(\(arguments.count)") }
        
        for (index, key) in keys.enumerated() {
            request[key] = arguments[index]
        }
        
        self.init(path: requestPattern,
                  instanceStyle: request.instanceStyle.rawValue,
                  priority: request.priority,
                  parameter: request.parameters)
    }
    
    private var storage: [String : Any] = [:]
    
    /// app scheme
    public var app: String {
        return storage[Constants.keyApp] as? String ?? ""
    }
    
    /// module id
    public var module: String {
        return storage[Constants.keyModlule] as? String ?? ""
    }
    
    /// 请求的 action 名，对应到 module 的一个相应请求的方法
    public var action: String {
        return storage[Constants.keyAction] as? String ?? ""
    }
    
    /// 一个请求的参数
    public var parameters: [String : Any]? {
        return storage[Constants.keyParameters] as? [String : Any]
    }
    
    /// 请求对应模块的优先级，将会调度到不小于这个优先级的 module 最接近的一个
    public var priority: Int {
        return storage[ModuleContext.Priority.key] as? Int ?? ModuleContext.Priority.default
    }
    
    /// 模块实例的创建方式
    public var instanceStyle: ModuleContext.InstanceStyle {
        return storage[ModuleContext.InstanceStyle.key] as? ModuleContext.InstanceStyle ?? ModuleContext.InstanceStyle.default
    }
    
    public var pattern: String {
        let module = self.module.count > 0 ? self.module : "unknown"
        return "\(app)://\(module)/\(action)"
    }
    
    public var singleton: Request {
        var request = self
        request.storage[ModuleContext.InstanceStyle.key] = ModuleContext.InstanceStyle.singleton.rawValue
        return request
    }
    
    /// 获取请求参数
    public subscript(key: String) -> Any? {
        set {
            if storage[Constants.keyParameters] == nil {
                if let newValue = newValue {
                    let params: [String : Any] = [key: newValue as Any]
                    storage[Constants.keyParameters] = params
                }
            } else {
                var params: [String : Any]? = storage[Constants.keyParameters] as? [String : Any]
                params?[key] = newValue
                storage[Constants.keyParameters] = params
            }
        }
        get { return (storage[Constants.keyParameters] as? [String : Any])?[key] }
    }
}

extension Request {
    public func bindAction(_ actionPattern: String, callback: ([String: Any]) -> Void) {
        if actionPattern.matchActionBinding(string: action) {
            callback(resolveParameters(for: actionPattern))
        }
    }
    
    public func resolveParameters(for pattern: String) -> [String: Any] {
        var params: [String: Any] = [:]
        parameters?.forEach {
            params[$0.key] = $0.value
        }
        
        let patternKeys = pattern.bindingPatternKeys
        for (index, value) in action.extractBindingValues(binding: pattern).enumerated() {
            switch value {
            case let (value) where value is String && (value as! String).hasPrefix("#"):
                if let value = params[(value as! String)] {
                    params[patternKeys[index]] = value
                } else {
                    fallthrough
                }
            default:
                params[patternKeys[index]] = value
            }
        }
        return params
    }
}

extension Request: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        Request content: \n app: \(app) \n module: \(module) \n
        action: \(action) \n parameters: \(parameters ?? [:])
        """
    }
}

extension String {
    fileprivate func dropHead(when: (Character?) -> Bool) -> String {
        if when(self.first) {
            return String(dropFirst(1))
        }
        return self
    }
}
