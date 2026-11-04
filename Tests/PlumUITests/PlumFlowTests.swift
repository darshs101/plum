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
        app.tabBars.buttons.element(boundBy: 4).tap()
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
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["profile.settings"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Private account"].exists)
        app.buttons["profile.collectionsTab"].tap()
        let saved = app.buttons["Saved Places"]
        if !saved.exists { app.swipeUp() }
        XCTAssertTrue(saved.waitForExistence(timeout: 5), app.debugDescription)
        saved.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", restaurantName)).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        attach(app, name: "Persisted Saved Places")
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "Session should survive a relaunch")
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["profile.settings"].waitForExistence(timeout: 15))
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
        app.tabBars.buttons.element(boundBy: 4).tap()
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
    @MainActor func testSocialNavigationPhotosAndRankedRestaurants() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(app.tabBars.buttons.count, 5)
        app.tabBars.buttons.element(boundBy: 3).tap()
        let friend = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "PLUM_QA_FRIEND_NAME") as? String)
        let friendRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", friend)).firstMatch
        XCTAssertTrue(friendRow.waitForExistence(timeout: 12), app.debugDescription); friendRow.tap()
        let message = app.textFields["dm.message"]
        let messageText = "Simulator social check " + UUID().uuidString.prefix(8)
        XCTAssertTrue(message.waitForExistence(timeout: 10)); message.tap(); message.typeText(messageText)
        app.buttons["dm.send"].tap()
        XCTAssertTrue(app.staticTexts[messageText].waitForExistence(timeout: 10), app.debugDescription)
        app.navigationBars.buttons["Messages"].tap()
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["profile.settings"].waitForExistence(timeout: 12), app.debugDescription)
        XCTAssertFalse(app.buttons["Connections & messages"].exists)
        XCTAssertFalse(app.buttons["Enable notifications"].exists)
        XCTAssertFalse(app.buttons["Edit profile"].exists)
        XCTAssertFalse(app.buttons["Sign out"].exists)
        app.buttons["Notifications"].tap()
        XCTAssertFalse(app.buttons["Manage follow requests"].exists)
        let requester = friend.replacingOccurrences(of: "_c_", with: "_d_")
        let privateRequest = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", requester, "requested to follow")).firstMatch
        XCTAssertTrue(privateRequest.waitForExistence(timeout: 12), app.debugDescription); privateRequest.tap()
        XCTAssertTrue(app.staticTexts["Only approved followers can view this private profile’s posts and collections."].waitForExistence(timeout: 10), app.debugDescription)
        app.navigationBars.buttons["Notifications"].tap()
        let confirm = app.buttons["Confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 12), app.debugDescription); confirm.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: confirm); waitForExpectations(timeout: 10)
        attach(app, name: "Flat notifications with inline requests")
        app.navigationBars.buttons["Profile"].tap()
        app.buttons["profile.settings"].tap()
        XCTAssertTrue(app.buttons["Enable notifications"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign out"].exists)
        app.buttons["Edit profile"].tap()
        app.buttons["profile.photoPicker"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription); photo.tap()
        if app.buttons["Done"].waitForExistence(timeout: 2) { app.buttons["Done"].tap() }
        app.swipeUp()
        let save = app.buttons["profile.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 6), app.debugDescription)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: save); waitForExpectations(timeout: 10)
        save.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15), app.debugDescription)
        app.navigationBars.buttons["Profile"].tap()
        app.buttons["profile.collectionsTab"].tap()
        let collection = app.buttons["Social QA rankings"]
        for _ in 0..<4 { if collection.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(collection.waitForExistence(timeout: 8), app.debugDescription); collection.tap()
        XCTAssertTrue(app.staticTexts[restaurantName].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["1."].exists)
        XCTAssertFalse(app.staticTexts["Open saved tasting"].exists)
        attach(app, name: "Ranked restaurant instead of generic saved tasting")
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["profile.settings"].waitForExistence(timeout: 10))
        attach(app, name: "Profile photo after relaunch")
    }
    @MainActor func testProfileIconTabsDatesAndScrollableDiary() throws {
        continueAfterFailure = false
        let bundle = Bundle(for: Self.self)
        let selected = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_DIARY_SELECTED_POST") as? String)
        let selectedID = try XCTUnwrap(UUID(uuidString: selected)).uuidString
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["profile.diaryTab"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["profile.collectionsTab"].exists)
        XCTAssertFalse(app.staticTexts["PHOTO DIARY"].exists)
        XCTAssertFalse(app.buttons["Saved Places"].exists)
        app.buttons["profile.collectionsTab"].tap()
        XCTAssertTrue(app.buttons["Saved Places"].waitForExistence(timeout: 8))
        app.buttons["profile.diaryTab"].tap()
        let thumbnail = app.buttons["profile.post." + selectedID]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 10), app.debugDescription); thumbnail.tap()
        XCTAssertTrue(app.staticTexts["Diary QA entry 31"].waitForExistence(timeout: 10), app.debugDescription)
        attach(app, name: "Diary initial tapped position")
        XCTAssertTrue(app.staticTexts["Diary QA entry 31"].isHittable, "The tapped post should be the initial visible post: \(app.debugDescription)")
        let date = app.staticTexts["post.date." + selectedID]
        XCTAssertTrue(date.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(date.label.contains("2020"), date.label)
        XCTAssertFalse(date.label.contains("Visited"), date.label)
        attach(app, name: "Selected diary post uses visit date as post date")
        let newer = app.staticTexts["Diary QA entry 32"]
        for _ in 0..<6 { if newer.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(newer.isHittable, "Scroll up should reveal a newer post")
        let oldest = app.staticTexts["Diary QA entry 01"]
        for _ in 0..<60 { if oldest.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(oldest.isHittable, "Scrolling should load beyond the first 30 posts")
        attach(app, name: "Diary pagination reaches older posts")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        try signOutFromProfile(app)
        app.buttons["Already have an account? Sign in"].tap()
        let email = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_SECOND_EMAIL") as? String)
        let password = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_PASSWORD") as? String)
        app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(email)
        app.secureTextFields["auth.password"].tap(); app.secureTextFields["auth.password"].typeText(password)
        app.buttons["auth.submit"].tap()
        if app.buttons["Not Now"].waitForExistence(timeout: 3) { app.buttons["Not Now"].tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 0).tap()
        let owner = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_OWNER_NAME") as? String)
        let ownerLink = app.buttons["@" + owner].firstMatch
        XCTAssertTrue(ownerLink.waitForExistence(timeout: 15), app.debugDescription); ownerLink.tap()
        XCTAssertTrue(app.buttons["profile.diaryTab"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profile.settings"].exists)
        let otherThumbnail = app.buttons["profile.post." + selectedID]
        XCTAssertTrue(otherThumbnail.waitForExistence(timeout: 10)); otherThumbnail.tap()
        XCTAssertTrue(app.staticTexts["Diary QA entry 31"].waitForExistence(timeout: 10))
        let next = app.staticTexts["Diary QA entry 30"]
        for _ in 0..<5 { if next.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(next.isHittable, "Approved viewers can scroll another user's diary")
        attach(app, name: "Approved follower scrolls another profile diary")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        try signOutFromProfile(app)
    }
    @MainActor func testMessagesPicturesAndChronologicalRows() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let newest = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "PLUM_QA_FRIEND_NAME") as? String)
        let older = newest.replacingOccurrences(of: "_c_", with: "_b_")
        let unmessaged = newest.replacingOccurrences(of: "_c_", with: "_d_")
        let first = app.staticTexts[newest].firstMatch
        let second = app.staticTexts[older].firstMatch
        let third = app.staticTexts[unmessaged].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 12), app.debugDescription)
        XCTAssertTrue(second.exists); XCTAssertTrue(third.exists)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        XCTAssertLessThan(second.frame.minY, third.frame.minY)
        attach(app, name: "Friend photos and chronological messages")
    }
    @MainActor func testZSignOutLeavesWelcomeReady() throws {
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        try signOutFromProfile(app)
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
        app.tabBars.buttons.element(boundBy: 4).tap()
        if app.buttons["profile.settings"].waitForExistence(timeout: 8) { app.buttons["profile.settings"].tap() }
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
