//
//  scoutwatchUITests.swift
//  scoutwatchUITests
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

class nightguardUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        addUIInterruptionMonitor(withDescription: "Accept disclaimer") { alert -> Bool in
            if alert.alerts["Disclaimer!"].exists {
                alert.alerts["Disclaimer!"].scrollViews.otherElements.buttons["Accept"].tap()
                return true
            }
            return false
        }

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["TEST"] = "1"
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTabsBars() {
        
        let tabBarsQuery = app.tabBars
        XCTAssertEqual(tabBarsQuery.buttons.count, 4)

        // Refresh the Test-URL to refresh the correct Units (mg/dl) for the backend
        tabBarsQuery.firstMatch.buttons.element(boundBy: 3).tap()
        let tablecells = app.tables.cells
        let urlTextField = tablecells.containing(.staticText, identifier:"URL").children(matching: .textField).element
        // tap to refresh
        urlTextField.tap()
        urlTextField.typeText("\n")
        
        testMainScreen(tabBarsQuery)
        
        testNightscoutView()
        
        testFullscreenView()
        
        tabBarsQuery.firstMatch.buttons.element(boundBy: 1).tap()
        snapshot("04-alarms")
        
        tabBarsQuery.firstMatch.buttons.element(boundBy: 2).tap()
        if UIDevice.current.userInterfaceIdiom == .phone {
            // only on a phone is a rotation needed if using the statistics panel
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        sleep(6)
        snapshot("05-stats")
        
        tabBarsQuery.firstMatch.buttons.element(boundBy: 3).tap()
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .portrait
        }
        sleep(1)
        snapshot("06-preferences")
    }
    
    fileprivate func testMainScreen(_ tabBarsQuery: XCUIElementQuery) {
        tabBarsQuery.firstMatch.buttons.element(boundBy: 0).tap()
        sleep(3)
        snapshot("01-main")
    }
    
    fileprivate func testNightscoutView() {
        app.buttons["actionsMenuButton"].firstMatch.tap()
        // open the nightscout webview
        app.cells.element(boundBy: 0).tap()
        sleep(5)
        snapshot("02-nightscout")
        
        // close the popup
        app.buttons.element(boundBy: 1).tap()
    }
    
    fileprivate func testFullscreenView() {
        app.buttons["actionsMenuButton"].firstMatch.tap()
        // open the fullscreen night mode
        app.cells.element(boundBy: 1).tap()
        sleep(1)
        snapshot("03-fullscreen")
        
        // close the popup
        app.buttons.element(boundBy: 0).tap()
    }
}
