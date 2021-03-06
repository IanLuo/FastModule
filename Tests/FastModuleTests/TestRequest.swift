//
//  TestRequest.swift
//  FastModuleTests
//
//  Created by ian luo on 24/02/2018.
//

import Foundation
@testable import FastModule
import XCTest

public class TestRequest: XCTestCase {
    func testResolveParameters() {
        let request = Request(stringLiteral: "//usermanager/login/myname/mypassword")
        
        var isHit = false
        var params = request.resolveParameters(for: "login/:username/:password")
        
        XCTAssertEqual("myname", params[":username"] as! String)
        XCTAssertEqual("mypassword", params[":password"] as! String)

        XCTAssertTrue(isHit)

        isHit = false
        params = request.resolveParameters(for: "login/:name/mypassword")
        XCTAssertEqual("myname", params[":name"] as! String)
        
        XCTAssertTrue(isHit)
    }
    
    func testFormatRequest() {
        let format = "app://usermanager/login/#username/#password/#image?instance-style=singleton&priority=2"

        let image = UIImage()
        let request = Request(requestPattern: format, arguments: "some body", "extreamly complex password", image)
        
        XCTAssertEqual(request["#username"] as! String, "some body")
        XCTAssertEqual(request["#password"] as! String, "extreamly complex password")
        XCTAssertEqual(request["#image"] as! UIImage, image)
        XCTAssertEqual(request.instanceStyle, ModuleContext.InstanceStyle.singleton)
        XCTAssertEqual(request.priority, 2)

        var param = request.resolveParameters(for: "login/:username/:password/:image")
        XCTAssertEqual(param[":username"] as! String, "some body")
        XCTAssertEqual(param[":password"] as! String, "extreamly complex password")
        XCTAssertEqual(param[":image"] as! UIImage, image)
        
        param = request.resolveParameters(for: "login/:username/:password")
        XCTAssertEqual(param["username"] as! String, "some body")
        XCTAssertEqual(param["password"] as! String, "extreamly complex password")
        XCTAssertEqual(param["image"] as! UIImage, image)
    }
    
    func testURLinRequestParameter() {
        var request: Request = "app://usermanager/login/#url1(https://koenig-media.raywenderlich.com/uploads/2016/11/Simulator-Screen-Shot-Nov-1-2016-9.46.31-PM.png?p1=v1&p2=v2#location)/#url2(https://2koenig-media.raywenderlich.com/uploads/2016/11/Simulator-Screen-Shot-Nov-1-2016-9.46.31-PM.png?p3=v1&p4=v2#location)"
        
        XCTAssertEqual(request["#url1"] as! String, "https://koenig-media.raywenderlich.com/uploads/2016/11/Simulator-Screen-Shot-Nov-1-2016-9.46.31-PM.png?p1=v1&p2=v2#location")
        XCTAssertEqual(request["#url2"] as! String, "https://2koenig-media.raywenderlich.com/uploads/2016/11/Simulator-Screen-Shot-Nov-1-2016-9.46.31-PM.png?p3=v1&p4=v2#location")
        
        XCTAssertEqual(request.app, "app")
        XCTAssertEqual(request.module, "usermanager")
        XCTAssertEqual(request.action, "login/#url1/#url2")

        request = "//list/cell/0/pattern/#url(//image/:url)"
        XCTAssertEqual(request.module, "list")
        XCTAssertEqual(request.action, "cell/0/pattern/#url")
        XCTAssertEqual(request["#url"] as! String, "//image/:url")
    }
}
