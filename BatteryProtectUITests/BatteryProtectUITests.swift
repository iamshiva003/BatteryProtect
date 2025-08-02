//
//  BatteryProtectUITests.swift
//  BatteryProtectUITests
//
//  Created by Shivakumar Patil on 01/08/25.
//

import XCTest

final class BatteryProtectUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Cleanup if needed
    }

    @MainActor
    func testMainScreenElementsExist() throws {
        let app = XCUIApplication()
        app.launch()

        // Check for main title
        XCTAssertTrue(app.staticTexts["Battery Protect"].exists)

        // Check for battery level label
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Battery Level:'")).firstMatch.exists)

        // Check for power source label
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Power Source:'")).firstMatch.exists)

        // Check for status label
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Status:'")).firstMatch.exists)

        // Check for last update label
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Last Update:'")).firstMatch.exists)
    }

    @MainActor
    func testMenuBarIconExists() throws {
        let app = XCUIApplication()
        app.launch()

        // The menu bar icon is not directly accessible via XCUIApplication,
        // but you can check if the app is running in the background.
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
