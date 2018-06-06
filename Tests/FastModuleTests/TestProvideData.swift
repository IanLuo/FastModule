//
//  TestProvideData.swift
//  FastModuleTests
//
//  Created by ian luo on 14/03/2018.
//

import Foundation
import XCTest
@testable import FastModule

public class TestProvideData: XCTestCase {
    func testProvideData() {
        TestModule.register()
        
        var isProvidedData = false
        var isObservedAction = false
        let module = ModuleContext.request("//test")
        module.provideData(name: "loadData/#name", paramType: String.self) { (_) -> String in
            isProvidedData = true
            return "ianluo"
        }
        
        module.executor(request: "loadData/joe", type: String.self).run {
            isObservedAction = true
            XCTAssertEqual("ianluo", $0.value ?? "")
        }
        
        XCTAssertTrue(isProvidedData)
        XCTAssertTrue(isObservedAction)
    }
}
