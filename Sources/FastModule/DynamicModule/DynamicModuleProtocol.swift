//
//  DynamicModuleProtocol.swift
//  FastModuleCore
//
//  Created by ian luo on 27/03/2018.
//

import Foundation

public protocol DynamicModuleDescriptorProtocol {
    associatedtype ModuleType
    func request(request: Request) -> Request
    
    func instance(request: Request) -> ModuleType
}
