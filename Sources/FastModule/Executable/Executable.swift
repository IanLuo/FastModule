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
    case canceled
}

private let keyBindings = "bindings"

public class ActionResponder {
    internal let callback: (Event.Result<Any?>) -> Void
    
    internal var isCanceld: Bool = false
    
    internal var onCancelAction: (() -> Void)? = nil
    
    internal init(request: Request, callback: @escaping (Event.Result<Any?>) -> Void) {
        self.callback = callback
        
        /// get mapped obj, multiple request with the same pattern will map to the same obj
        var obj = notificationObjectMap[request.pattern]
        
        // if no obj mapped, create one and save the mapping
        if obj == nil {
            obj = NSObject()
            notificationObjectMap[request.pattern] = obj
        }
        
        // add the cancel observer
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didCancel),
                                               name: NSNotification.Name(keyCancelRequestNotification),
                                               object: obj)
    }
    
    deinit {
        // release cancel observer
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func didCancel() {
        isCanceld = true
        callback(Event.Result.failure(ExecutionError.canceled))
        onCancelAction?()
    }
    
    /// call this function if the binding action execute successfully, pass the obj to the caller
    public func success(value: Any?) {
        guard !isCanceld else { return }
        callback(Event.Result.success(value))
    }

    /// call this function if the execution fails, pass the error obj
    public func failure(error: Error) {
        guard !isCanceld else { return }
        callback(Event.Result.failure(error))
    }
    
    /// if there's an canceling action to the binding execution action, pass the action with this function
    public func onCancel(_ action: @escaping () -> Void) {
        onCancelAction = action
    }
}

public protocol Executable {

    /// same as `bindAction` with no callback
    @discardableResult
    func fire(request: Request) -> Module
    
    /// same as `bindAction` with no callback
    @discardableResult
    func fire(requestPattern: String,
              arguments: Any...) -> Module
    
    /// update specifiled property, and notify all observers, won't hit binded action
    @discardableResult
    func update(properties: [String: Any]) -> Module
    
    /// execute the binded action, and notify all observers
    func bindAction(pattern: String,
                    callback: @escaping ([String: Any], ActionResponder, Request) -> Void)
}

private let keyCancelRequestNotification = "keyCancelRequestNotification"

/// used to map request pattern to request
private var notificationObjectMap: [String: Any] = [:]

extension Module {
    /// trigger any cancelation and dispose action for an execution
    public func dispose(request: Request) {
        /// do dispose action when binding action done
        request.disposeAction?.forEach { $0() }
        
        // notify responder to perfom action when cancel fires
        NotificationCenter.default.post(name: NSNotification.Name(keyCancelRequestNotification), object: notificationObjectMap[request.pattern])
    }
    
    @discardableResult
    public func execute<Type>(request: Request,
                              type t: Type.Type,
                              callback: @escaping (Event.Result<Type>) -> Void) -> Module {
        
        let actionResponder = ActionResponder(request: request, callback: { [weak self] in
            switch $0 {
            case .failure(let error):
                print("ERROR: \(error), pattern: \(request.action), module: \(type(of: self! as Module).identifier)")
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
        
        // find callback closue for the binded action, with matches the request action
        // for example: /some-action/#param1/#param with match '/some-action/:p1/:p2'
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
                print("warning: No handler for \(request.action), module: \(type(of: self as Module).identifier)")
            }
        }
        
        return self
    }
    
    /// retrive a binded pattern for request, nil if there's none found
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
                           callback: @escaping ([String: Any], ActionResponder, Request) -> Void) {
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

/// convinient functions for getting value from binding action
extension Dictionary where Key == String, Value == Any {
    public func required<T>(_ key: String, type: T.Type) throws -> T {
        guard let v = self[key] as? T else {
            throw ModuleError.missingParameter(key)
        }
        
        return v
    }
    
    public func optional<T>(_ key: String, type: T.Type, default: T? = nil) -> T? {
        return self[key] as? T
    }
}

extension Module {
    /// retrive all binded action names
    public var bindedActions: [String]? {
        return property(key: keyBindings, type: [String: Any].self)?.map { $0.key }
    }
}
