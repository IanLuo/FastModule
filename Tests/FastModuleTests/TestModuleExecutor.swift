//
//  TestModuleExecutor.swift
//  FastModuleTests
//
//  Created by ian luo on 08/02/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation
import XCTest
@testable import FastModule

enum TError: Error {
    case error
}

public class TestModuleExecutor: XCTestCase {
    func testSynchorizedValue() {
        let value = ""
        TestModule.register()
        Executor<String>.value(module: ModuleContext.request("//test"), value: value).run {
            switch $0 {
            case .success(let v):
                XCTAssertEqual(v, value)
            default:
                XCTAssert(false)
            }
        }
    }
    
    func testSynchorizedError() {
        let error = TError.error
        TestModule.register()
        Executor<String>.error(module: ModuleContext.request("//test"), error: error).run {
            switch $0 {
            case .failure(let e):
                XCTAssert(e is TError)
            default:
                XCTAssert(false)
            }
        }
    }
    
    func testRequestPattern() {
        TestModule.register()
        
        var isHit = false
        let request = Request(requestPattern: "pattern/#value1/#value2", arguments: "11111", 2222222)
        ModuleContext.request("//test/")
            .observeValue(action: "pattern/#value1/#value2", type: [String: Any].self) { (value: [String: Any]) -> Void in
                XCTAssertEqual(value["p1"] as! String, "11111")
                XCTAssertEqual(value["p2"] as! Int, 2222222)
                isHit = true
            }.executor(request: request)
            .run { _ in}
        
        XCTAssertTrue(isHit)
    }
}
