//
//  DynamicLayoutableModule.swift
//  CFDemo
//
//  Created by ian luo on 26/03/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation

public let dynamicNameModule = "~module"
public let dynamicNameLayoutableModule = "~layoutable"
public let dynamicNameRoutableModule = "~routable"

open class DynamicModule: Module {
    open class var identifier: String { return dynamicNameModule }
    
    public static var routePriority: Int = 1
    
    public var instanceIdentifier: String

    public required init(request: Request) {
        instanceIdentifier = request.module
    }
    
    open func binding() {
        bindAction(pattern: "bind-the-injected-bindings") { [weak self] (parameter, responder, request) in
            if let generatorAction = parameter.value("generatorAction", type: ((Module) -> Void).self) {
                guard let strongSelf = self else { return }
                generatorAction(strongSelf)
            }
        }
    }
}

private struct ModuleDescriptor: DynamicModuleDescriptorProtocol {
    public typealias ModuleType = Module
    
    private let generatorAction: (Module) -> Void
    public init(_ generatorAction: @escaping (Module) -> Void) {
        self.generatorAction = generatorAction
    }
    
    public func request(request: Request) -> Request {
        var newRequest = request
        newRequest["generatorAction"] = generatorAction
        return newRequest
    }
    
    public func instance(request: Request) -> Module {
        return ModuleContext.request(self.request(request: request))
    }
}

public protocol DynamicModuleTemplate {
    func setupChildModules(nestable: Nestable)
    
    func setupBindings(executable: Executable)
    
    func setupObservations(observeable: Observeable)
    
    static func request(name: String,
                        pattern: String,
                        arguments: Any...) -> Request
    
    static func instance(name: String,
                         pattern: String,
                         arguments: Any...) -> Module
    
    init()
}

extension DynamicModuleTemplate {
    public static func request(name: String,
                               pattern: String,
                               arguments: Any...) -> Request {
        let request = Request(requestPattern: "//" + DynamicModule.identifier + "-" + name + "/" + pattern, arguments: arguments)
        return DynamicModuleBuilder(template: Self.init()).buildRequest(request: request)
    }
    
    public static func instance(name: String,
                                pattern: String,
                                arguments: Any...) -> Module {
        let request = self.request(name: name,
                                   pattern: pattern,
                                   arguments: arguments)
        return DynamicModuleBuilder(template: Self.init()).buildInstance(request: request)
    }
}

fileprivate struct DynamicModuleBuilder {
    private var template: DynamicModuleTemplate?
    public init(template: DynamicModuleTemplate) {
        self.template = template
    }
    
    fileprivate func buildDescriptor() -> ModuleDescriptor {
        return ModuleDescriptor { module in
            self.template?.setupChildModules(nestable: module)
            self.template?.setupBindings(executable: module)
            self.template?.setupObservations(observeable: module)
        }
    }
    
    fileprivate func buildInstance(request: Request) -> Module {
        return buildDescriptor().instance(request: request)
    }
    
    fileprivate func buildRequest(request: Request) -> Request {
        return buildDescriptor().request(request: request)
    }
}

