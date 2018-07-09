//
//  TestDynamicModule.swift
//  FastModuleTests
//
//  Created by ian luo on 26/03/2018.
//

import Foundation
import XCTest
@testable import FastModule

private struct TestDynamicModuleClass: DynamicModuleTemplate {
    func setupChildModules(nestable: Nestable) {
        
    }
    
    func setupBindings(executable: Executable) {
        executable.bindAction(pattern: "action") { (parameter, responder, request) in
            responder.success(value: "ohhhhhhhh")
        }
    }
    
    func setupObservations(observeable: Observeable) {
        
    }
}

public class TestDynamicModule: XCTestCase {
    func testCreateDynamicModule() {
        var isHit = false
        ModuleContext.request(TestDynamicModuleClass.request(name: "test", pattern: "action", arguments: "what the parameter is"), callbackType: String.self) {
            XCTAssertEqual("ohhhhhhhh", $0.value)
            isHit = true
        }
        
        XCTAssertTrue(isHit)
    }
}
