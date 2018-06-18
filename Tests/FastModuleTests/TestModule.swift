//
//  TestModule.swift
//  FastModuleTests
//
//  Created by ian luo on 17/01/2018.
//  Copyright © 2018 ianluo. All rights reserved.
//

import Foundation
@testable import FastModule
import XCTest

private enum TestError: Error {
    case TestError
}

public class TestModule: Module {
    public var viewController: UIViewController {
        return UIViewController()
    }
    
    public var routeHandler: UIViewController!
    
    public var childrenModules: [Module]?
    
    public func handleAction(request: Request, responder: ActionResponder) {
        switch request.action {
        case "loadData":
            loadData(parameter: request.parameters, result: responder)
        default: break
        }
    }
    
    public static var identifier: String = "test"
    
    public static var routePriority: Int = 1
    
    public let request: Request
    
    public required init(request: Request) {
        routeHandler = UIViewController()
        self.request = request
        
        bindAction(pattern: "loadData/:name") { [weak self] (_, responder, _) in
            let value = self?.requestData(name: "loadData/#name", param: "joe", default: "")
            responder.success(value: value)
        }
        
        bindAction(pattern: "pattern/:p1/:p2") { (parameter, responder, _) in
            responder.success(value: ["p1": parameter[":p1"], "p2": parameter[":p2"]])
        }
    }
    
    private func loadData(parameter: [String : Any]?, result: ActionResponder) {
        result.success(value: "execute complete")
        result.failure(error: TestError.TestError)
    }
    
    private func grayscal(parameter: [String : Any]?, result: ActionResponder) {
        result.success(value: "grayscal")
    }
}

public class ModuleBasicTests: XCTestCase {
    func testCreateModule() {
        TestModule.register()
        
        let testModule = ModuleContext.request("local://test/loadData?name=name&age=25") as! TestModule
        XCTAssertEqual(testModule.request.app, "local")
        XCTAssertEqual(testModule.request.module, "test")
        XCTAssertEqual(testModule.request.action, "loadData")
        XCTAssertEqual(testModule.request.parameters!["name"] as! String, "name")
        XCTAssertEqual(testModule.request.parameters!["age"] as! String, "25")
        
        let image = UIImage()
        let imageProccessingModule = ModuleContext.request(Request(path: "local://test/greyscale",
                                                        parameter: ["image": image])) as! TestModule

        XCTAssertEqual(imageProccessingModule.request.app, "local")
        XCTAssertEqual(imageProccessingModule.request.module, "test")
        XCTAssertEqual(imageProccessingModule.request.action, "greyscale")
        XCTAssertEqual(imageProccessingModule.request.parameters!["image"] as! UIImage, image)
    }
    
    func testModuleCreateWithActionCallback() {
        TestModule.register()
        _ = ModuleContext.request("local://test/greyscale", instanceStyle: .new,
                                  callbackType: String.self) {
            switch $0 {
            case .success(let value):
                XCTAssertEqual(value, "grayscal")
            default: XCTAssert(false)
            }
        }
    }
    
    func testModuleCreateStyle() {
        TestModule.register()
        var singletonInstance1 = ModuleContext.request("local://test?instance-style=new")
        var singletonInstance2 = ModuleContext.request("local://test?instance-style=singleton")
        
        //TODO:
    }
    
    func testExecuteAndObserve() {
        TestModule.register()
        let testModule: TestModule = ModuleContext.request("local://test/loadData?name=name&age=25") as! TestModule
        testModule.observeEvent(action: "loadData") {
            print("recived event: \($0)")
        }

        testModule.observeValue(action: "loadData", type: Bool.self) {
            print("received value: \($0)")
        }
        
        testModule.observeError(action: "loadData") {
            print("received error: \($0)")
        }
        
        testModule.execute(request: "loadData", type: String.self) {
            print("execute result: \($0)")
        }
    }
    
//    func testRouter() {
//        TestModule.register()
//        
//        let testModule: TestModule = Router.showBase(request: "//test", window: UIWindow()) as! TestModule
//        testModule.show(request: "local://test/loadData?name=name&age=25", style: .present(true)).observeResult(action: "test", type: Any.self) {
//            switch $0 {
//            case .failure(let error):
//                print("shit, failed: \(error)")
//            case .success(let value):
//                print("wonderful \(value)")
//            }
//        }
//    }
}
