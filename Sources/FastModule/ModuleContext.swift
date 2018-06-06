//
//  ModuleContext.swift
//  Module
//
//  Created by ian luo on 18/01/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation

public struct ModuleContext {
    public enum InstanceStyle: String {
        public static var key: String { return "instance-style" }
        public static var `default`: InstanceStyle { return .new }
        case new
        case singleton
    }

    public struct Priority {
        public static let key = "priority"
        public static let `default` = 1
    }
    
    private struct SingletonSinstanceMap {
        fileprivate static var map: [String: Module] = [:]
    }
    
    public static func getRegisteredType(request: Request) -> Module.Type? {
        if let t = content[request.module] as? [Module.Type] {
            guard t.count > 0 else { return nil }
            let first = t.first!
            
            return t.reduce(first, { last, next in
                return last.routePriority < next.routePriority ? last : next
            })
        } else if (request.module.hasPrefix(dynamicNameModule)) {
            return (content[dynamicNameModule] as? [Module.Type])?.first
        } else if (request.module.hasPrefix(dynamicNameLayoutableModule)) {
            return (content[dynamicNameLayoutableModule] as? [Module.Type])?.first
        } else if (request.module.hasPrefix(dynamicNameRoutableModule)) {
            return (content[dynamicNameRoutableModule] as? [Module.Type])?.first
        }
        
        return nil
    }
    
    public static func fetchModule(request: Request) -> Module {
        guard let type = getRegisteredType(request: request) else {
            fatalError("no module registered: \(request.module)")
        }
        
        let createInstance: (Module.Type) -> Module = {
            let instance = $0.init(request: request)
            
            instance.didInit()
            
            instance.binding()
            
            instance.bindAction(pattern: "instatiate-properties/:properties") { (parameter, responder, request) in
                guard let properties = parameter[":properties"] as? [String: Any] else {
                    responder.failure(error: ModuleError.missingParameter(":properties"))
                    return
                }
                
                properties.forEach {
                    instance[$0.key] = $0.value
                }
            }

            if let routable = instance as? ExternalType {
                routable.initailBindingActions()
            }
            
            if instance is DynamicModule {
                instance.fire(request: Request(path: "bind-the-injected-bindings", parameter: request.parameters))
            }
            
            return instance
        }
        
        let instanceStyle = request.instanceStyle
        switch instanceStyle {
        case .new:
            return createInstance(type)
        case .singleton:
            if let instance = SingletonSinstanceMap.map[request.module] {
                return instance
            } else {
                SingletonSinstanceMap.map[request.module] = createInstance(type)
                return self.request(request)
            }
        }
    }
    
    /// 创建 module, 忽略执行 action 的返回值
    public static func request(_ request: Request) -> Module {
        return fetchModule(request: request).execute(request: request, type: Any.self, callback: { _ in })
    }
    
    /// 创建 module
    @discardableResult
    public static func request<T>(_ request: Request,
                                             instanceStyle: InstanceStyle = .new,
                                             callbackType: T.Type,
                                             callback: @escaping (Event.Result<T>) -> Void) -> Module? {
        
        return fetchModule(request: request).execute(request: request, type: T.self, callback: callback)
    }
    
    public static func register(identifier: String, type inType: Module.Type) {
        if let types = content[identifier] as? [Module.Type] {
            for case let sameType in types where sameType.routePriority == inType.routePriority {
                return
            }
            var newTypes = types
            newTypes.append(inType)
            content[identifier] = newTypes
        } else {
            content[identifier] = [inType]
        }
    }
}

private var content: [String : [Any]] = [:]

extension Module {
    public static func register() {
        ModuleContext.register(identifier: Self.identifier, type: self)
    }
}
