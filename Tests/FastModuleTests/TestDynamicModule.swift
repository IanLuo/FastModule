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
        TestDynamicModuleClass
            .instance(name: "test", pattern: "")
            .observeValue(action: "action", type: String.self) {
                XCTAssertEqual("ohhhhhhhh", $0)
                isHit = true
            }
            .fire(requestPattern: "action")
        
        XCTAssertTrue(isHit)
    }
}

