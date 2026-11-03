import XCTest

final class PlumFlowTests: XCTestCase {
    @MainActor func testLoginProfileCollectionsAndRelaunch() throws {
        continueAfterFailure = false
        let bundle = Bundle(for: Self.self)
        let email = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_EMAIL") as? String)
        let password = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_PASSWORD") as? String)
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Not Now"].waitForExistence(timeout: 2) { app.buttons["Not Now"].tap() }
        let signIn = app.buttons["Already have an account? Sign in"]
        if signIn.waitForExistence(timeout: 15) { signIn.tap() }
        if app.textFields["auth.email"].waitForExistence(timeout: 3) {
            app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(email)
            app.secureTextFields["auth.password"].tap(); app.secureTextFields["auth.password"].typeText(password)
            app.buttons["auth.submit"].tap()
        }
        let getStarted = app.buttons["Get started"]
        if getStarted.waitForExistence(timeout: 8) { getStarted.tap() }
        if app.buttons["Not Now"].waitForExistence(timeout: 2) { app.buttons["Not Now"].tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Private account"].exists)
        let saved = app.buttons["Saved Places"]
        if !saved.exists { app.swipeUp() }
        XCTAssertTrue(saved.waitForExistence(timeout: 5), app.debugDescription)
        saved.tap()
        XCTAssertTrue(app.staticTexts["Plum Integration Atlanta"].waitForExistence(timeout: 8), app.debugDescription)
        attach(app, name: "Persisted Saved Places")
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "Session should survive a relaunch")
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 15))
        attach(app, name: "Profile after relaunch")
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.textFields["Search restaurants, dishes, people, lists"].waitForExistence(timeout: 10))
        app.textFields["Search restaurants, dishes, people, lists"].tap()
        app.textFields["Search restaurants, dishes, people, lists"].typeText("Plum Integration Atlanta")
        app.textFields["Search restaurants, dishes, people, lists"].typeText("\n")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Plum Integration Atlanta")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), app.debugDescription)
        result.tap()
        XCTAssertTrue(app.buttons["Remove from Saved Places"].waitForExistence(timeout: 10), app.debugDescription)
        attach(app, name: "Live restaurant detail")
    }
    @MainActor func testComposerPublishesMultiDishPhotoPost() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        app.tabBars.buttons.element(boundBy: 2).tap()
        let restaurant = app.textFields["Search restaurants"]
        XCTAssertTrue(restaurant.waitForExistence(timeout: 10)); restaurant.tap(); restaurant.typeText("Plum Integration Atlanta")
        let match = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Plum Integration Atlanta")).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 10), app.debugDescription); match.tap()
        let dish = app.textFields["Search or name a dish"].firstMatch
        dish.tap(); dish.typeText("Integration dish")
        if app.buttons["Integration dish"].waitForExistence(timeout: 5) { app.buttons["Integration dish"].tap() }
        app.buttons["Add another dish"].tap()
        let second = app.textFields.matching(identifier: "Search or name a dish").element(boundBy: 1)
        second.tap(); second.typeText("QA second dish")
        app.swipeUp()
        let photo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add or change photos")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5), app.debugDescription); photo.tap()
        let cell = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), app.debugDescription); cell.tap()
        if app.buttons["Done"].waitForExistence(timeout: 3) { app.buttons["Done"].tap() }
        app.swipeUp()
        let publish = app.buttons["Post tasting"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5), app.debugDescription)
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: publish); waitForExpectations(timeout: 10)
        publish.tap()
        XCTAssertTrue(app.alerts["Your tasting is on Plum"].waitForExistence(timeout: 20), app.debugDescription)
        attach(app, name: "Multi-dish photo post saved"); app.alerts.buttons["Done"].tap()
    }
    @MainActor func testZSignOutLeavesWelcomeReady() throws {
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let signOut = app.buttons["Sign out"]
        for _ in 0..<5 { if signOut.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(signOut.waitForExistence(timeout: 5)); signOut.tap()
        XCTAssertTrue(app.buttons["Create an account with email"].waitForExistence(timeout: 10), app.debugDescription)
        attach(app, name: "Signed out and ready for user")
    }
    @MainActor private func signInIfNeeded(_ app: XCUIApplication) throws {
        let signIn = app.buttons["Already have an account? Sign in"]
        if signIn.waitForExistence(timeout: 3) {
            signIn.tap()
            let bundle = Bundle(for: Self.self)
            let email = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_EMAIL") as? String)
            let password = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_PASSWORD") as? String)
            app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(email)
            app.secureTextFields["auth.password"].tap(); app.secureTextFields["auth.password"].typeText(password)
            app.buttons["auth.submit"].tap()
            if app.buttons["Not Now"].waitForExistence(timeout: 3) { app.buttons["Not Now"].tap() }
            if app.buttons["Get started"].waitForExistence(timeout: 3) { app.buttons["Get started"].tap() }
        }
    }
    @MainActor private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
