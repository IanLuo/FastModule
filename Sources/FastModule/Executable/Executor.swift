//
//  Future.swift
//  Module
//
//  Created by ian luo on 08/02/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation

public struct Executor<Type> {
    public typealias Action = (Event.Result<Type>) -> Void
    public var callback: (@escaping Action) -> Void
    private let module: Module
    
    public init(module: Module,
                _ callback: @escaping ( @escaping Action) -> Void) {
        self.module = module
        self.callback = callback
    }
    
    /// return a new executor which only handles error
    public static func error(module: Module,
                             error: Error) -> Executor {
        return Executor(module: module) { handler in
            handler(Event.Result<Type>.failure(error))
        }
    }
    
    /// return a new executor which only handles the specified return value type
    public static func value(module: Module,
                             value: Type) -> Executor {
        return Executor(module: module) { handler in
            handler(Event.Result<Type>.success(value))
        }
    }
    
    /// execute and handle the result
    public func run(_ action: @escaping ( (Event.Result<Type>) -> Void)) {
        callback(action)
    }
    
    /// execute the executor, and handle only the failure
    public func runFail(_ action: @escaping (Event.Result<Type>) -> Void) {
        self.run {
            switch $0 {
            case .failure: action($0)
            default: break
            }
        }
    }
    
    /// replace return value by execution the clouse
    public func map<Type2>(action: @escaping (Type) -> Type2) -> Executor<Type2> {
        return self.flatMap(action: {
            return Executor<Type2>.value(module: self.module,
                                         value: action($0))
        })
    }
    
    /// compose another executor to current executor, execut one by one serializaly
    public func flatMap<Type2>(action: @escaping (Type) -> Executor<Type2>) -> Executor<Type2> {
        return Executor<Type2>(module: module) { handler in
            self.run {
                switch $0 {
                case .failure(let error):
                    handler(Event.Result<Type2>.failure(error))
                case .success(let value):
                    action(value).run {
                        handler($0)
                    }
                }
            }
        }
    }
    
    /// 返回上一步的值，或者 error
    public func condition(_ action: @escaping (Type) -> Bool) -> Executor<Type> {
        return flatMap {
            if action($0) {
                return Executor<Type>.value(module: self.module,
                                            value: $0)
            } else {
                return Executor<Type>.error(module: self.module,
                                            error: ModuleError.conditionFail("\($0)"))
            }
        }
    }
    
    /// use the last executor's return value, and replace the place holder in 'requestPattern'
    /// parameter is extra parameter will pass to binding action in module handler
    public func then(module: Module? = nil,
                     requestPattern: String,
                     parameter: [String: Any]? = nil) -> Executor<Any?> {
        return self.flatMap { (value: Type) -> Executor<Any?> in
            let parameter = parameter ?? [:]
            var request = Request(requestPattern: requestPattern,
                                  arguments: value)
            parameter.forEach { request[$0.key] = $0.value }
            return (module ?? self.module).executor(request: request,
                                                    type: Any?.self)
        }
    }
    
    /// use the last executor's return value, with 'key' to store in parameter, will be passed to binding action handler
    public func then(module: Module? = nil,
                     action: String,
                     key: String,
                     parameter: [String: Any]? = nil) -> Executor<Any?> {
        return self.flatMap { (value: Type) -> Executor<Any?> in
            var parameter = parameter ?? [:]
            parameter[key] = value
            let request = Request(path: action,
                                  parameter: parameter)
            return (module ?? self.module)
                .executor(request: request,
                          type: Any?.self)
        }
    }
    
    /// use the last executor's return value, replace the placeholder in 'requestPattern', additionaly
    /// specify the return type of this executor
    public func then<Type2>(module: Module? = nil,
                            requestPattern: String,
                            type: Type2.Type) -> Executor<Type2> {
        return self.flatMap { (value: Type) -> Executor<Type2> in
            let request = Request(requestPattern: requestPattern,
                                  arguments: value)
            return (module ?? self.module).executor(request: request,
                                                    type: type)
        }
    }
    
    /// ignore the last executor's return value, once the last execution done, execute the next 'request'
    public func then(module: Module? = nil,
                     request: Request) -> Executor<Any?> {
        return self.flatMap { (value: Type) -> Executor<Any?> in
            return (module ?? self.module)
                .executor(request: request,
                          type: Any?.self)
        }
    }
    
    /// ignore the last executor's return value, once the last execution done, execute the next 'request', addiitinaly specify the return
    /// value type of this executor
    public func then<Type2>(module: Module? = nil,
                            request: Request,
                            type: Type2.Type) -> Executor<Type2> {
        return self.flatMap { (value: Type) -> Executor<Type2> in
            return (module ?? self.module)
                .executor(request: request,
                          type: type)
        }
    }
}
