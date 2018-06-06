//
//  Executable.swift
//  Module
//
//  Created by ian luo on 17/01/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation
import UIKit

public enum ExecutionError: Error {
    case actionMissing
}

private let keyBindings = "bindings"

public struct ActionResponder {
    internal let callback: (Event.Result<Any?>) -> Void
    
    public func success(value: Any?) {
        callback(Event.Result.success(value))
    }

    public func failure(error: Error) {
        callback(Event.Result.failure(error))
    }
    
    public func result(_ result: Event.Result<Any?>) {
        callback(result)
    }
}

public protocol Executable {
    @discardableResult
    func fire(request: Request) -> Module
    
    @discardableResult
    func fire(requestPattern: String,
              arguments: Any...) -> Module
    
    @discardableResult
    func update(properties: [String: Any]) -> Module
        
    func bindAction(pattern: String,
                    callback: ([String: Any], ActionResponder, Request) -> Void)
}

extension Module {
    @discardableResult
    public func execute<Type>(request: Request,
                              type t: Type.Type,
                              callback: @escaping (Event.Result<Type>) -> Void) -> Module {
        let actionResponder = ActionResponder(callback: { [weak self] in
            switch $0 {
            case .failure(let error):
                print("ERROR: \(error), pattern: \(request.action), module: \(type(of: self as! Module).identifier)")
                callback(.failure(error))
                self?.raiseError(action: request.action,
                                 error: error)
            case .success(let value) where value is Type:
                callback(.success(value as! Type))
                self?.notify(action: request.action,
                             value: value)
            default: break
            }
        })
        
        if let matchedBindingPattern = findBindedPattern(request: request) {
            let parameters = request.resolveParameters(for: matchedBindingPattern)
            if let binding = property(key: matchedBindingPattern,
                                      type: (([String: Any], ActionResponder, Request) -> Void).self) {
                binding(parameters,
                        actionResponder,
                        request)
            }
        } else {
            if request.action.count > 0 {
                print("warning: No handler for \(request.action), module: \(type(of: self as! Module).identifier)")
            }
        }
        
        return self
    }
    
    private func findBindedPattern(request: Request) -> String? {
        for pattern in property(key: keyBindings,
                                type: [String].self) ?? [] {
            if pattern.matchActionBinding(string: request.action) {
                return pattern
            }
        }
        return nil
    }
    
    @discardableResult
    public func execute<Type>(request: StringLiteralType,
                              parameter: [String: Any],
                              type: Type.Type,
                              callback: @escaping (Event.Result<Type>) -> Void) -> Module {
        
        let request = Request(path: request, parameter: parameter)
        return execute(request: request, type: type, callback: callback)
    }
    
    @discardableResult
    public func fire(request: Request) -> Module {
        execute(request: request, type: Any?.self,
                callback: { _ in })
        return self
    }
}

extension Module {
    public func bindAction(pattern: String,
                           callback: ([String: Any], ActionResponder, Request) -> Void) {
        if var bindings = property(key: keyBindings,
                                   type: [String].self) {
            bindings.append(pattern)
            setProperty(key: keyBindings,
                        value: bindings)
        } else {
            setProperty(key: keyBindings,
                        value: [pattern])
        }
        
        setProperty(key: pattern,
                    value: callback)
    }
    
    public func bindProperty<Type>(key: String,
                                   type: Type.Type,
                                   block: @escaping (Type) -> Void) {
        observeValue(action: key,
                     type: type,
                     callback: block)
    }
    
    public func passthroughProperty(child id: String,
                                    key: String,
                                    as childKey: String) {
        bindProperty(key: key,
                     type: String.self) { [weak self] in
            self?.childModule(id: id)?.update(properties: [childKey: $0])
        }
    }
    
    @discardableResult
    public func fire(requestPattern: String,
                     arguments: Any...) -> Module {
        let request = Request(requestPattern: requestPattern,
                              arguments: arguments)
        return fire(request: request)
    }
    
    @discardableResult
    public func update(properties: [String: Any]) -> Module {
        fire(request: Self.request(properties: properties))
        return self
    }
    
    public func executor(module: Module? = nil,
                         request: Request) -> Executor<Any?> {
        return executor(module: module,
                        request: request, type: Any?.self)
    }
    
    public func executor<Type>(module: Module? = nil,
                               request: Request,
                               type t: Type.Type) -> Executor<Type> {
        let module = module ?? self
        return Executor<Type>(module: self) { handler in
            module.execute(request: request,
                           type: t,
                           callback: { result in
                            _ = handler(result)
            })
        }
    }
    
    public func executor<Type>(request: StringLiteralType,
                               parameter: [String: Any],
                               type t: Type.Type) -> Executor<Type> {
        let request = Request(path: request,
                              parameter: parameter)
        return executor(request: request,
                        type: t)
    }
    
    public func executor(request: StringLiteralType,
                         parameter: [String: Any]) -> Executor<Any?> {
        let request = Request(path: request,
                              parameter: parameter)
        return executor(request: request)
    }
    
    public func executor(requestPattern: String,
                         arguments: Any...) -> Executor<Any?> {
        let request = Request(requestPattern: requestPattern,
                              arguments: arguments)
        return executor(request: request)
    }
}

extension ModuleContext {
    public static func executor<Type>(request: Request,
                                      type: Type.Type) -> Executor<Type> {
        let module = self.fetchModule(request: request)
        return Executor<Type>(module: module) { handler in
            module.execute(request: request,
                           type: type,
                           callback: { result in
                            handler(result)
            })
        }
    }
}