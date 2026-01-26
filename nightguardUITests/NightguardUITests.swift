//
//  scoutwatchUITests.swift
//  scoutwatchUITests
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

@MainActor
class NightguardUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        setupSnapshot(app)

        app.launchArguments.append("--uitesting")
        app.launchEnvironment["TEST"] = "1"
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        sleep(5)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testTabsBars() {
        
        // Wait for app to be ready
        if !app.buttons["actionsMenuButton"].waitForExistence(timeout: 30) {
             app.tap()
             if app.alerts.count > 0 {
                 let allowButton = app.alerts.buttons["Allow"]
                 if allowButton.exists { allowButton.tap() } 
                 else { app.alerts.buttons.firstMatch.tap() }
             }
        }
        
        let tabBar = findTabBarContainer()

        // Refresh the Test-URL
        selectPreferencesTab(using: tabBar)
        
        // Find the first text field in the first cell (which is always the URL field)
        let urlTextField = app.textFields.firstMatch
        if !urlTextField.waitForExistence(timeout: 5) {
             // Retry if not appeared
             selectPreferencesTab(using: tabBar)
        }
        
        if urlTextField.waitForExistence(timeout: 10) {
            setNightscoutUrl(urlTextField, url: readBaseUri())
            
            // Try to tap the back button if we are in a sub-view (often labelled "<" or "Back")
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists && backButton.isHittable {
                // Check if it looks like a back button (arrow or "Back")
                if backButton.label.contains("<") || backButton.label == "Back" || backButton.identifier == "Back" {
                    backButton.tap()
                } else if backButton.frame.minX < 50 {
                     // Fallback: any button on the far left of the nav bar is likely a back button
                     backButton.tap()
                }
            }
            sleep(2)
        }
        
        testMainScreen(tabBar)
        
        testNightscoutView()
        testFullscreenView()

        // Test the Alarms Tab
        selectTab(identifier: "tab_alarms", index: 1, using: tabBar)
        snapshot("04-alarms")
        
        // Test the Care Tab
        selectTab(identifier: "tab_care", index: 2, using: tabBar)
        snapshot("05-care")

        // Test the Duration Tab
        selectTab(identifier: "tab_duration", index: 3, using: tabBar)
        snapshot("06-duration")
        
        // Test the Statistics Tab:
        selectStatsTab(using: tabBar)
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        sleep(3)
        snapshot("07-stats")
        sleep(2)
        
        // Test the Preferences Tab:
        selectPreferencesTab(using: tabBar)
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .portrait
        }
        sleep(1)
        
        let prefUrlField = app.textFields.firstMatch
        if prefUrlField.waitForExistence(timeout: 5) {
            setNightscoutUrl(prefUrlField, url: "https://your.nightscout.here")
        }
        snapshot("08-preferences")
    }
    
    fileprivate func selectPreferencesTab(using tabBar: XCUIElement? = nil) {
        selectTab(identifier: "tab_prefs", index: 5, using: tabBar)
    }
    
    fileprivate func selectStatsTab(using tabBar: XCUIElement? = nil) {
        selectTab(identifier: "tab_stats", index: 4, using: tabBar)
    }

    fileprivate func selectTab(identifier: String, index: Int, using passedTabBar: XCUIElement? = nil) {
        // Comprehensive targets - search globally in app
        let sysIds = ["Main", "Alarm", "Care", "clock.arrow.circlepath", "Stats", "Prefs"]

        let targetById = app.buttons[identifier].firstMatch
        let targetBySys = index < sysIds.count ? app.buttons[sysIds[index]].firstMatch : app.buttons["nonexistent"]

        func getBestTarget() -> XCUIElement {
            // First try identifier (works on iPhone)
            if targetById.exists { return targetById }

            // Then try system IDs (works on iPad with English)
            if targetBySys.exists { return targetBySys }

            // Fallback: Find tab by index position (language-agnostic, works on iPad with any language)
            // Look for buttons in the top bar that look like tab buttons
            let allButtons = app.buttons.allElementsBoundByIndex
            var tabButtons: [XCUIElement] = []

            for button in allButtons {
                let frame = button.frame
                let id = button.identifier

                // Tab buttons are in the top area (y < 60) and are wider than pagination buttons
                // Skip pagination buttons (small width < 60)
                if frame.minY < 60 && frame.width >= 60 {
                    // Also check if it has a tab identifier or is one of the known system IDs
                    if id.contains("tab_") || sysIds.contains(id) ||
                       (!id.isEmpty && frame.width > 60 && frame.width < 200) {
                        tabButtons.append(button)
                    } else if id.isEmpty && frame.width > 60 && frame.width < 200 {
                        // On iPad, tab buttons have no identifier, just labels
                        tabButtons.append(button)
                    }
                }
            }

            // Remove duplicates by position (sometimes same button appears twice in hierarchy)
            var uniqueTabButtons: [XCUIElement] = []
            for button in tabButtons {
                let isDuplicate = uniqueTabButtons.contains { existing in
                    abs(existing.frame.minX - button.frame.minX) < 5 &&
                    abs(existing.frame.minY - button.frame.minY) < 5
                }
                if !isDuplicate {
                    uniqueTabButtons.append(button)
                }
            }

            // Sort by x position (left to right)
            uniqueTabButtons.sort { $0.frame.minX < $1.frame.minX }

            // Return the tab at the requested index
            if index < uniqueTabButtons.count {
                return uniqueTabButtons[index]
            }

            return targetById
        }

        func findPaginationButtons() -> (next: XCUIElement?, prev: XCUIElement?) {
            // Find pagination buttons by characteristics instead of labels (for localization)
            // Pagination buttons are typically:
            // - In the top bar area (y < 60)
            // - Small width (< 60 pixels)
            // - At the edges (rightmost for next, leftmost for prev)

            let allButtons = app.buttons.allElementsBoundByIndex
            var nextButton: XCUIElement?
            var prevButton: XCUIElement?
            var rightmostSmallButton: (element: XCUIElement, x: CGFloat)?
            var leftmostSmallButton: (element: XCUIElement, x: CGFloat)?

            for button in allButtons {
                let frame = button.frame
                // Check if it's in the top bar area and has small width
                if frame.minY < 60 && frame.width < 60 && frame.width > 15 {
                    // Skip if it's a known tab button
                    let id = button.identifier
                    if id.contains("tab_") || sysIds.contains(id) {
                        continue
                    }

                    // Track rightmost small button (likely "next")
                    if rightmostSmallButton == nil || frame.maxX > rightmostSmallButton!.x {
                        rightmostSmallButton = (button, frame.maxX)
                    }

                    // Track leftmost small button (likely "previous")
                    if leftmostSmallButton == nil || frame.minX < leftmostSmallButton!.x {
                        leftmostSmallButton = (button, frame.minX)
                    }
                }
            }

            // Assign next/prev based on position
            // If there's only one, assume it's the next button
            if let rightmost = rightmostSmallButton?.element,
               let leftmost = leftmostSmallButton?.element,
               rightmost != leftmost {
                nextButton = rightmost
                prevButton = leftmost
            } else if let single = rightmostSmallButton?.element {
                nextButton = single
            }

            return (nextButton, prevButton)
        }

        // On iPad floating tab bar, we may need to page through tabs to find the target
        // Try up to 3 times to page through and find the tab
        for _ in 0..<3 {
            let target = getBestTarget()
            let (nextPageButton, prevPageButton) = findPaginationButtons()

            if target.exists {
                // Check if target is obscured by page navigation buttons
                var isObscured = false
                if let nextBtn = nextPageButton, nextBtn.exists {
                    isObscured = target.frame.intersects(nextBtn.frame)
                }
                if !isObscured, let prevBtn = prevPageButton, prevBtn.exists {
                    isObscured = target.frame.intersects(prevBtn.frame)
                }

                if !isObscured && target.isHittable {
                    // Target is fully visible and hittable - tap it
                    target.tap()
                    sleep(2)
                    return
                }

                // Target exists but is obscured - try to page to reveal it
                if let nextBtn = nextPageButton, nextBtn.exists && nextBtn.isHittable {
                    nextBtn.tap()
                    sleep(1)
                    continue
                }
            } else {
                // Target doesn't exist on current page - try paging

                // Try next page first (more likely for higher index tabs)
                if index > 2, let nextBtn = nextPageButton, nextBtn.exists && nextBtn.isHittable {
                    nextBtn.tap()
                    sleep(1)
                    continue
                }

                // Try previous page (for lower index tabs like Main)
                if index <= 2, let prevBtn = prevPageButton, prevBtn.exists && prevBtn.isHittable {
                    prevBtn.tap()
                    sleep(1)
                    continue
                }

                // If we guessed wrong direction, try the other button
                if let nextBtn = nextPageButton, nextBtn.exists && nextBtn.isHittable {
                    nextBtn.tap()
                    sleep(1)
                } else if let prevBtn = prevPageButton, prevBtn.exists && prevBtn.isHittable {
                    prevBtn.tap()
                    sleep(1)
                }
            }
        }

        // Final attempt - just try to tap if it exists
        let target = getBestTarget()
        if target.exists {
            target.tap()
            sleep(2)
            return
        }

        // If not immediately available, try to reveal it
        let bar = passedTabBar ?? findTabBarContainer()

        func scrollToRevealTab(in bar: XCUIElement) -> Bool {
            // On iPad, tabs might be in a horizontal scroll view
            if bar.elementType == .scrollView {
                let target = getBestTarget()
                if target.exists && !target.isHittable {
                    // Try scrolling to make it visible
                    let startPoint = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
                    let endPoint = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
                    startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
                    usleep(500000) // 0.5 seconds
                    return true
                }
            }
            return false
        }

        func revealMoreTabs(in bar: XCUIElement) -> Bool {
            // On iPad, look for the ">" button or similar to reveal hidden tabs
            let barButtons = bar.buttons.allElementsBoundByIndex

            // Try to find and tap the ">" or "More" button
            for button in barButtons.reversed() {
                let label = button.label.lowercased()
                let identifier = button.identifier.lowercased()

                // Look for common "more" indicators
                if label.contains(">") || label.contains("more") || label.contains("seuraava") ||
                   identifier.contains(">") || identifier.contains("more") {
                    if button.exists && button.isHittable {
                        button.tap()
                        sleep(1)
                        return true
                    }
                }
            }

            // Fallback: tap the last button if it's not already our target
            if let lastBtn = barButtons.last, lastBtn.exists && lastBtn.isHittable {
                let target = getBestTarget()
                if lastBtn != target {
                    lastBtn.tap()
                    sleep(1)
                    return true
                }
            }

            return false
        }

        // Loop to handle paging (tapping the last button in the bar to reveal more)
        for attempt in 0..<5 {
            let target = getBestTarget()

            // Try scrolling first if in a scroll view
            if attempt > 0 && attempt < 3 {
                _ = scrollToRevealTab(in: bar)
            }

            if target.exists {
                if target.isHittable {
                    target.tap()
                    sleep(2)
                    return
                } else {
                    // Try force tap even if not hittable
                    target.forceTap()
                    sleep(2)
                    return
                }
            }

            // On first attempts, try to reveal hidden tabs
            if attempt < 3 {
                let didReveal = revealMoreTabs(in: bar)

                // Wait a bit after revealing to let UI update
                if didReveal {
                    sleep(1)
                }
            }

            // Check if standard More menu appeared (common on iPhone)
            if app.tables.firstMatch.exists {
                let cell = app.tables.cells[identifier].firstMatch
                if cell.exists {
                    cell.tap()
                } else {
                    let barButtons = bar.buttons.allElementsBoundByIndex
                    let itemsBeforeMore = max(1, barButtons.count - 1)
                    let listIndex = max(0, index - itemsBeforeMore)
                    if app.tables.cells.count > listIndex {
                        app.tables.cells.element(boundBy: listIndex).tap()
                    }
                }
                sleep(2)
                return
            }
        }

        // Final desperate attempt - search entire app
        let finalTarget = getBestTarget()
        if finalTarget.exists {
            finalTarget.forceTap()
            sleep(2)
        }
    }

    fileprivate func findTabBarContainer() -> XCUIElement {
        // Check for standard tab bar first (iPhone)
        if app.tabBars.firstMatch.exists { return app.tabBars.firstMatch }

        // On iPad, tabs might be in a sidebar or different container
        // Look for segmented controls (common in iPad layouts)
        if app.segmentedControls.firstMatch.exists {
            return app.segmentedControls.firstMatch
        }

        // Look for scroll views that might contain tab buttons on iPad
        let scrollViews = app.scrollViews.allElementsBoundByIndex
        for scrollView in scrollViews {
            if scrollView.buttons.count >= 3 && scrollView.buttons.count < 15 {
                return scrollView
            }
        }

        // Find Duration button as anchor
        let durationBtn = app.buttons["clock.arrow.circlepath"].firstMatch
        if durationBtn.exists {
             let container = app.otherElements.containing(.button, identifier: "clock.arrow.circlepath").allElementsBoundByIndex.first { $0.frame.minY < 150 }
             if let c = container { return c }
        }

        // Fallback: Filter for any top bar containing at least 3 buttons
        let candidates = app.otherElements.allElementsBoundByIndex.filter {
            $0.frame.minY < 150 && $0.buttons.count >= 3 && $0.buttons.count < 15
        }
        return candidates.first ?? app
    }

    fileprivate func testMainScreen(_ tabBar: XCUIElement?) {
        selectTab(identifier: "tab_main", index: 0, using: tabBar)
        sleep(3)
        snapshot("01-main")
    }
    
    fileprivate func testNightscoutView() {
        let actionsButton = app.buttons["actionsMenuButton"].firstMatch
        if actionsButton.waitForExistence(timeout: 5) {
            actionsButton.forceTap()
        }
        
        let sheet = app.sheets.firstMatch
        let popover = app.popovers.firstMatch
        
        if sheet.waitForExistence(timeout: 3) {
            sheet.buttons.element(boundBy: 0).forceTap()
        } else if popover.waitForExistence(timeout: 3) {
            popover.buttons.element(boundBy: 0).forceTap()
        }

        let closeButton = app.buttons["closeButton"].firstMatch
        if closeButton.waitForExistence(timeout: 20) {
            snapshot("02-nightscout")
            closeButton.forceTap()
        }
    }
    
    fileprivate func testFullscreenView() {
        let actionsButton = app.buttons["actionsMenuButton"].firstMatch
        if actionsButton.waitForExistence(timeout: 5) {
            actionsButton.forceTap()
        }

        let sheet = app.sheets.firstMatch
        let popover = app.popovers.firstMatch
        
        if sheet.waitForExistence(timeout: 3) {
            if sheet.buttons.count > 1 {
                sheet.buttons.element(boundBy: 1).forceTap()
            }
        } else if popover.waitForExistence(timeout: 3) {
            if popover.buttons.count > 1 {
                popover.buttons.element(boundBy: 1).forceTap()
            }
        }

        sleep(1)
        snapshot("03-fullscreen")

        let closeButton = app.buttons["fullscreenCloseButton"].firstMatch
        if closeButton.waitForExistence(timeout: 5) {
            closeButton.forceTap()
        } else {
             app.windows.firstMatch.forceTap()
        }
        sleep(1)
    }

    fileprivate func setNightscoutUrl(_ textField: XCUIElement, url: String) {
        textField.tap()
        
        // Use the clear button if available
        let clearButton = app.buttons["clear_url_button"]
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
        } else {
            // Fallback to standard clearing if button not found (e.g. field already empty)
             if let val = textField.value as? String, !val.isEmpty {
                 textField.clearText()
             }
        }
        
        textField.typeText(url)
        textField.typeText("\n")
    }

    fileprivate func readBaseUri() -> String {
        let envKey = "BASE_URI"
        if let envValue = ProcessInfo.processInfo.environment[envKey], !envValue.isEmpty {
            return envValue
        }
        
        // Attempt to find .env in project root
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let envFile = projectRoot.appendingPathComponent(".env")
        
        if let content = try? String(contentsOf: envFile, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    if key == envKey {
                        var value = parts[1].trimmingCharacters(in: .whitespaces)
                        // Remove quotes if present
                        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                            value = String(value.dropFirst().dropLast())
                        }
                        if !value.isEmpty {
                            return value
                        }
                    }
                }
            }
        }
        
        return "https://your.nightscout.app"
    }
}
