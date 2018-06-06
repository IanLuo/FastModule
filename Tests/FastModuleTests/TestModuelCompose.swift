//
//  TestModuelCompose.swift
//  FastModuleTests
//
//  Created by ian luo on 06/02/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation
@testable import FastModule
import XCTest

private enum TestError: Error {
    case testError
}

private var image: UIImage?
private var error: Error?

private struct TestModule2: DynamicModuleTemplate {
    func setupChildModules(nestable: Nestable) {
        
    }
    
    func setupBindings(executable: Executable) {
        executable.bindAction(pattern: "processImage/:image") { parameter, responder, _ in
            responder.success(value: parameter[":image"] as Any)
        }
        
        executable.bindAction(pattern: "loadImage") { _, responder, _ in
            responder.success(value: image as Any)
            responder.failure(error: TestError.testError)
        }
    }
    
    func setupObservations(observeable: Observeable) {
        
    }
    
    init() {
        
    }
    
    
}

public class TestModuleCompose: XCTestCase {
    public func testNext() {
        DynamicModule.register()
        
        image = UIImage()
        ModuleContext.executor(request: TestModule2.request(name: "test", pattern: "loadImage"), type: UIImage?.self)
            .flatMap { (v: UIImage?) -> Executor<UIImage?> in
                let request = Request(path: "//test/processImage", parameter: ["image": v as Any])
                return ModuleContext.executor(request: request, type: UIImage?.self)
            }
            .run {
                switch $0 {
                case .failure(let error):
                    XCTAssert(type(of: error) == type(of: TestError.testError))
                case .success(let value):
                    XCTAssertEqual(image!, value)
                }
        }
    }
    
    public func testNextShort() {
        DynamicModule.register()

        image = UIImage()
        var isHit = false
        ModuleContext.executor(request: TestModule2.request(name: "test", pattern: "loadImage"), type: UIImage?.self)
            .then(requestPattern: "processImage/#image")
            .run {
                isHit = true
                switch $0 {
                case .failure(let error):
                    XCTAssert(type(of: error) == type(of: TestError.testError))
                case .success(let value):
                    XCTAssertEqual(image!, value as! UIImage)
                }
        }
        XCTAssertTrue(isHit)
    }
}
