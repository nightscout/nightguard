//
//  scoutwatchUITests.swift
//  scoutwatchUITests
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

class NightguardUITests: XCTestCase {
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
        app.launchArguments.append("--AppleLanguages")
        app.launchArguments.append("(en-US)")
        app.launchArguments.append("--AppleLocale")
        app.launchArguments.append("\"en-US\"")
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
        let tablecells = app.tables.cells
        XCTAssertTrue(tabBarsQuery.buttons.count == 5 || tabBarsQuery.buttons.count == 6)

        // Refresh the Test-URL to refresh the correct Units (mg/dl) for the backend
        selectPreferencesTab()
        let urlTextField = tablecells.containing(.staticText, identifier:"URL").children(matching: .textField).element
        // tap to refresh
        urlTextField.tap()
        urlTextField.clearText()
        urlTextField.tap()
        urlTextField.clearText(andReplaceWith: "http://night.fritz.box")
        urlTextField.typeText("\n")
        
        testMainScreen(tabBarsQuery)
        
        testNightscoutView()
        
        testFullscreenView()
        
        // Test the Alarms Tab:
        tabBarsQuery.firstMatch.buttons.element(boundBy: 1).tap()
        snapshot("04-alarms")
        
        // Test the Care Tab:
        tabBarsQuery.firstMatch.buttons.element(boundBy: 2).tap()
        snapshot("05-care")

        // Test the Duration Tab:
        tabBarsQuery.firstMatch.buttons.element(boundBy: 3).tap()
        snapshot("06-duration")
        
        // Test the Statistics Tab:
        selectStatsTab()
        if UIDevice.current.userInterfaceIdiom == .phone {
            // only on a phone is a rotation needed if using the statistics panel
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        sleep(6)
        snapshot("07-stats")
        
        // Test the Preferences Tab:
        selectPreferencesTab()
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .portrait
        }
        sleep(1)
        snapshot("08-preferences")
    }
    
    fileprivate func selectPreferencesTab() {
        
        let tabBarsQuery = app.tabBars
        let tablecells = app.tables.cells
        
        // On small devices like the iPhone => the preferences tab is hidden in a separate popup:
        if tabBarsQuery.buttons.count == 5 {
            
            tabBarsQuery.firstMatch.buttons.element(boundBy: 4).tap()
            // Double Tab to be sure that the TabBar-Popup appears:
            //tabBarsQuery.firstMatch.buttons.element(boundBy: 4).tap()
            
            tablecells.containing(.staticText, identifier: "Preferences").element.tap()
        }
        
        // On iPads the preferences tab can be selected directly:
        if tabBarsQuery.buttons.count == 6 {
            
            tabBarsQuery.firstMatch.buttons.element(boundBy: 5).tap()
        }
    }
    
    fileprivate func selectStatsTab() {
        
        let tabBarsQuery = app.tabBars
        let tablecells = app.tables.cells
        
        // On small devices like the iPhone => the preferences tab is hidden in a separate popup:
        if tabBarsQuery.buttons.count == 5 {
                
            tabBarsQuery.firstMatch.buttons.element(boundBy: 4).tap()
            // Double Tab to be sure that the TabBar-Popup appears:
            tabBarsQuery.firstMatch.buttons.element(boundBy: 4).tap()
            tablecells.containing(.staticText, identifier: "Stats").element.tap()
        }
        
        // On iPads the preferences tab can be selected directly:
        if tabBarsQuery.buttons.count == 6 {
            
            tabBarsQuery.firstMatch.buttons.element(boundBy: 4).tap()
        }
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
        sleep(15)
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
