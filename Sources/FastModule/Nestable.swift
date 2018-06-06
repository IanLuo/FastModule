//
//  Combining.swift
//  FastModuleCore
//
//  Created by ian luo on 27/03/2018.
//

import Foundation

private let keyChildModule = "keyChildModule"
extension Module {
    public func addChildModule(id: String, request: Request) -> Module {
        let module = ModuleContext.request(request)
        addChildModule(id: id, module: module)
        return module
    }
    
    public func addChildModule(id: String, module: Module) {
        if var childModules = childModulePair {
            childModules[id] = module
            setProperty(key: keyChildModule, value: childModules)
        } else {
            setProperty(key: keyChildModule, value: [id: module])
        }
    }
    
    public func childModule(id: String) -> Module? {
        if let dict = childModulePair {
            return dict[id]
        } else {
            return nil
        }
    }
    
    /// 直接从 property 中取出来的类型为 [String: Layoutable & AnyObject]，不能够直接转为 Layoutable 协议对象，需要进行一次转换
    private var childModulePair: [String: Module]? {
        if let dict = property(key: keyChildModule, type: [String: Any].self) {
            guard let d = dict as? [String: Module] else { return nil }
            return d
        } else {
            return nil
        }
    }
    
    public var childModules: [Module]? {
        return childModulePair?.map { $0.value }
    }
    
    public func removeFromParent() -> Module? {
        if var childModules = childModulePair {
            for case let pair in childModules where pair.value === self {
                let removed = childModules.removeValue(forKey: pair.key)
                setProperty(key: keyChildModule, value: childModules)
                return removed
            }
        }
        
        return nil
    }
}
