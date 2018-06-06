//
//  Observe.swift
//  FastModuleCore
//
//  Created by ian luo on 17/01/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation

public protocol Observeable {
    @discardableResult
    func observeEvent(action: String,
                      callback: @escaping (Event) -> Void) -> Module
    @discardableResult
    func observeValue<Type>(action: String,
                            type: Type.Type,
                            callback: @escaping (Type) -> Void) -> Module
    @discardableResult
    func observeResult<Type>(action: String,
                             type: Type.Type,
                             callback: @escaping (Event.Result<Type>) -> Void) -> Module
    @discardableResult
    func observeError(action: String,
                      callback: @escaping (Error) -> Void) -> Module
    
    func notify<Type>(action: String,
                      value: Type)
    func raiseError(action: String,
                    error: Error)
    
    func whileValue<Type: Equatable>(action: String,
                                     value: Type,
                                     callback: @escaping (Type) -> Void)
    
    @discardableResult
    func provideData<Param, Result>(name: String,
                                    paramType: Param.Type,
                                    callback: @escaping (Param) -> Result) -> Module
    func requestData<Param, Result>(name: String,
                                    param: Param,
                                    `default`: Result) -> Result
}

/// 保存 module 的监听对象引用，不持有 module 和监听对象的
private class ModuleObserverMapper {
    private class ModuleObserverContext {
        private var observersMap: [String : [(Event) -> Any?]] = [:]
        fileprivate func add(key: String, newObserver: @escaping (Event) -> Any?) {
            if let observers = observersMap[key] {
                var newListener = observers
                newListener.append(newObserver)
                observersMap[key] = newListener
            } else {
                observersMap[key] = [newObserver]
            }
        }
        
        init(key: String, observer: @escaping (Event) -> Any?) {
            add(key: key, newObserver: observer)
        }
        
        fileprivate func observer(for key: String) -> [(Event) -> Any?]? {
            var observables: [(Event) -> Any?] = []
            
            if let wildCard = observersMap["*"] {
                observables.append(contentsOf: wildCard)
            }
            
            // 如果 key 中包含 / 符号，则表示需要通知的 key 可能是带有 :key 格式参数占位符的，需要进行匹配, 否则直接对 key 取值
            if key.contains("/") {
                matchedKeys(notifyKey: key).forEach {
                    if let o = observersMap[$0] {
                        observables.append(contentsOf: o)
                    }
                }
                return observables.count > 0 ? observables : nil
            } else {
                if let matched = observersMap[key] {
                    observables.append(contentsOf: matched)
                }
                return observables
            }
        }
        
        private func matchedKeys(notifyKey: String) -> [String] {
            var matched: [String] = []
            observersMap.keys.forEach {
                if $0.matchActionBinding(string: notifyKey) {
                    matched.append($0)
                }
            }
            return matched
        }
    }
    
    private static var moduleObserverMapperContent = NSMapTable<AnyObject, ModuleObserverContext>.weakToStrongObjects()
    
    func addObserver(module: AnyObject,
                     key: String,
                     observer: @escaping (Event) -> Any?) {
        if let liseners = ModuleObserverMapper.moduleObserverMapperContent.object(forKey: module) {
            liseners.add(key: key,
                         newObserver: observer)
            ModuleObserverMapper.moduleObserverMapperContent.setObject(liseners,
                                                                       forKey: module)
        } else {
            ModuleObserverMapper.moduleObserverMapperContent
                .setObject(ModuleObserverContext(key: key,
                                                 observer: observer), forKey: module)
        }
    }
    
    func observers(for key: String,
                   in module: AnyObject) -> [(Event) -> Any?]? {
        return ModuleObserverMapper.moduleObserverMapperContent.object(forKey: module)?.observer(for: key)
    }
}

private struct ObserverContext {
    fileprivate static let moduleObserveMapper = ModuleObserverMapper()
}

extension Module {
    /// 通知所有监听者成功的消息
    /// - Parameter key: 监听者所监听的 key
    /// - Parameter value: 监听者将要收到的 value
    /// - Parameter request: 该 value 所对应的请求
    public func notify<Type>(action: String,
                             value: Type) {
        ObserverContext.moduleObserveMapper.observers(for: action,
                                                      in: self as AnyObject)?.forEach {
            _ = $0(Event.success(value, action: action,
                                 module: self))
        }
    }
    
    /// 通知所有监听者失败的消息
    /// - Parameter action: 监听者所监听的 action
    /// - Parameter error: 监听者将要收到的 error
    /// - Parameter request: 该 error 所对应的请求
    public func raiseError(action: String, error: Error) {
        ObserverContext.moduleObserveMapper.observers(for: action,
                                                      in: self as AnyObject)?.forEach {
            _ = $0(Event.failure(error, action: action,
                                 module: self))
        }
    }
    
    internal func raiseError(action: String, error: ModuleError,
                             request: Request?) {
        ObserverContext.moduleObserveMapper.observers(for: action,
                                                      in: self as AnyObject)?.forEach {
            _ = $0(Event.failure(error,
                                 action: action,
                                 module: self))
        }
    }
    
    /// 监听请求失败的通知
    /// - Parameter action: 监听对应的 action
    /// - Parameter callback: 当错误发生时，调用的 callback
    @discardableResult
    public func observeError(action: String,
                             callback: @escaping (Error) -> Void) -> Module {
        observeEvent(action: action) {
            switch $0.content {
            case .failure(let error): callback(error)
            default: break
            }
        }
        return self
    }
    
    /// 监听请求成功的返回值
    /// - Parameter action: 需要监听的 action
    /// - Parameter type: 该 value 的类型, 如果返回值不符合该类型，则 callback 不会被调用
    /// - Parameter callback: 返回值符合 type 时调用
    @discardableResult
    public func observeValue<Type>(action: String,
                                   type: Type.Type,
                                   callback: @escaping (Type) -> Void) -> Module {
        observeEvent(action: action) {
            switch $0.content {
            case .success(let value) where value is Type: callback(value as! Type)
            default: break
            }
        }
        return self
    }
    
    /// 监听原始的返回对象
    /// - Parameter action: 需要监听的 action
    /// - Parameter eventAction: 当 action 完成式，执行的结果，为一个 Event 对象
    @discardableResult
    public func observeEvent(action: String,
                             callback: @escaping (Event) -> Void) -> Module {
        ObserverContext.moduleObserveMapper.addObserver(module: self as AnyObject,
                                                        key: action, observer: callback)
        return self
    }
    
    /// 监听原始的返回对象
    /// - Parameter action: 需要监听的 action
    /// - Parameter callback: 当 action 完成式，执行的结果，为一个 Result 对象
    @discardableResult
    public func observeResult<Type>(action: String,
                                    type: Type.Type,
                                    callback: @escaping (Event.Result<Type>) -> Void) -> Module {
        observeEvent(action: action) {
            switch $0.content {
            case .success(let value) where value is Type: callback(Event.Result<Type>.success(value as! Type))
            case .failure(let error): callback(Event.Result<Type>.failure(error))
            default: break
            }
        }
        return self
    }
    
    public func whileValue<Type: Equatable>(action: String,
                                            value: Type,
                                            callback: @escaping (Type) -> Void) {
        observeValue(action: action, type: Type.self) {
            if $0 == value {
                callback($0)
            }
        }
    }
    
    @discardableResult
    public func provideData<Param, Result>(name: String,
                                           paramType: Param.Type,
                                           callback: @escaping (Param) -> Result) -> Module {
        ObserverContext.moduleObserveMapper.addObserver(module: self as AnyObject,
                                                        key: name) { event in
            switch event.content {
            case .success(let value) where value is Param:
                return callback(value as! Param)
            default:
                return nil
            }
        }
        return self
    }
    
    public func requestData<Param, Result>(name: String,
                                           param: Param,
                                           `default`: Result) -> Result {
        var result: Result = `default`
        ObserverContext.moduleObserveMapper.observers(for: name,
                                                      in: self as AnyObject)?.forEach {
            if let r = $0(Event.success(param,
                                        action: name,
                                        module: self)) as? Result {
                result = r
            }
        }
        return result
    }
}
