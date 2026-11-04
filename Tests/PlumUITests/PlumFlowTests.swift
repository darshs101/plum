import XCTest

final class PlumFlowTests: XCTestCase {
    private var restaurantName: String { Bundle(for: Self.self).object(forInfoDictionaryKey: "PLUM_QA_RESTAURANT_NAME") as? String ?? "Plum Integration Atlanta" }
    @MainActor func testARealSignupAndRelaunch() throws {
        continueAfterFailure = false
        let bundle = Bundle(for: Self.self)
        let email = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_SIGNUP_EMAIL") as? String)
        let username = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_SIGNUP_USERNAME") as? String)
        let password = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_PASSWORD") as? String)
        let app = XCUIApplication(); app.launch()
        if app.buttons["Not Now"].waitForExistence(timeout: 2) { app.buttons["Not Now"].tap() }
        if app.buttons["Skip for now"].waitForExistence(timeout: 3) { app.swipeUp(); app.buttons["Skip for now"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        if app.tabBars.firstMatch.waitForExistence(timeout: 12) { try signOutFromProfile(app) }
        XCTAssertTrue(app.buttons["Create an account with email"].waitForExistence(timeout: 15), app.debugDescription)
        app.buttons["Create an account with email"].tap()
        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap(); emailField.typeText(email)
        let usernameField = app.textFields["auth.username"]
        usernameField.tap(); usernameField.typeText(username)
        let passwordField = app.secureTextFields["auth.password"]
        passwordField.tap(); passwordField.typeText(password)
        app.buttons["auth.submit"].tap()
        XCTAssertTrue(app.buttons["Skip for now"].waitForExistence(timeout: 15), app.debugDescription)
        if app.buttons["Not Now"].waitForExistence(timeout: 3) { app.buttons["Not Now"].tap() }
        app.swipeUp()
        app.buttons["Skip for now"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.staticTexts[username].waitForExistence(timeout: 10), app.debugDescription)
        attach(app, name: "Fresh signup and profile")
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "Fresh account session should survive relaunch")
        try signOutFromProfile(app)
    }
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
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", restaurantName)).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        attach(app, name: "Persisted Saved Places")
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "Session should survive a relaunch")
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 15))
        attach(app, name: "Profile after relaunch")
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.textFields["Search restaurants, dishes, people, lists"].waitForExistence(timeout: 10))
        app.textFields["Search restaurants, dishes, people, lists"].tap()
        app.textFields["Search restaurants, dishes, people, lists"].typeText(restaurantName)
        app.textFields["Search restaurants, dishes, people, lists"].typeText("\n")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", restaurantName)).firstMatch
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
        XCTAssertTrue(restaurant.waitForExistence(timeout: 10)); restaurant.tap(); restaurant.typeText(restaurantName)
        let match = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", restaurantName)).firstMatch
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
    @MainActor func testMPostCommentAndEditPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let post = app.buttons.matching(NSPredicate(format: "label == %@", restaurantName)).firstMatch
        XCTAssertTrue(post.waitForExistence(timeout: 10), app.debugDescription); post.tap()
        XCTAssertTrue(app.buttons["post.like"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["post.like"].tap()
        app.swipeUp()
        let comment = app.textFields["post.comment"]
        XCTAssertTrue(comment.waitForExistence(timeout: 5), app.debugDescription)
        comment.tap(); comment.typeText("Simulator audit comment")
        app.buttons["post.sendComment"].tap()
        XCTAssertTrue(app.staticTexts["Simulator audit comment"].waitForExistence(timeout: 10), app.debugDescription)
        app.swipeDown()
        app.buttons["post.options"].tap(); app.buttons["Edit post"].tap()
        let caption = app.textFields["edit.caption"]
        for _ in 0..<4 { if caption.exists { break }; app.swipeUp() }
        XCTAssertTrue(caption.waitForExistence(timeout: 8), app.debugDescription)
        caption.tap()
        caption.typeText("Edited in simulator audit")
        app.swipeUp()
        app.buttons["edit.save"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Edited in simulator audit")).firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        attach(app, name: "Comment and edited post persisted")
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
            if app.buttons["Get started"].waitForExistence(timeout: 3) {
                app.swipeUp()
                app.buttons["Get started"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            if app.buttons["Not Now"].waitForExistence(timeout: 2) { app.buttons["Not Now"].tap() }
        }
    }
    @MainActor private func signOutFromProfile(_ app: XCUIApplication) throws {
        app.tabBars.buttons.element(boundBy: 3).tap()
        let signOut = app.buttons["Sign out"]
        for _ in 0..<6 { if signOut.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(signOut.waitForExistence(timeout: 5), app.debugDescription)
        signOut.tap()
        XCTAssertTrue(app.buttons["Create an account with email"].waitForExistence(timeout: 10), app.debugDescription)
    }
    @MainActor private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
