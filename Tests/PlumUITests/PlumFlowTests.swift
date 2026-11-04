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
        let comment = app.textFields.matching(identifier: "post.comment").firstMatch
        XCTAssertTrue(comment.waitForExistence(timeout: 5), app.debugDescription)
        comment.tap(); comment.typeText("Simulator audit comment")
        app.buttons.matching(identifier: "post.sendComment").firstMatch.tap()
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
    @MainActor func testBellUnreadFollowBackAndMessageBubbles() async throws {
        continueAfterFailure = false
        let bundle = Bundle(for: Self.self)
        func value(_ key: String) throws -> String { try XCTUnwrap(bundle.object(forInfoDictionaryKey: key) as? String) }
        let follower = try XCTUnwrap(UUID(uuidString: try value("PLUM_QA_FOLLOWER_ID"))).uuidString
        let post = try value("PLUM_QA_COMMENT_POST")
        let sender = try await qaLogin(email: value("PLUM_QA_SECOND_EMAIL"))
        let newFollower = try await qaLogin(email: value("PLUM_QA_FOLLOWER_EMAIL"))
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 4).tap()
        waitForBell(app, count: 0)
        let meData = try await qaRequest("/auth/v1/user", token: sender, method: "GET")
        let senderID = try XCTUnwrap((try JSONSerialization.jsonObject(with: meData) as? [String: Any])?["id"] as? String)
        let ownerData = try await qaRequest("/auth/v1/token?grant_type=password", body: ["email":value("PLUM_QA_EMAIL"),"password":value("PLUM_QA_PASSWORD")])
        let owner = try XCTUnwrap(try JSONSerialization.jsonObject(with: ownerData) as? [String: Any])
        let ownerID = try XCTUnwrap((owner["user"] as? [String: Any])?["id"] as? String)
        _ = try await qaRequest("/rest/v1/follows", token: newFollower, body: ["follower_id":follower.lowercased(),"following_id":ownerID,"status":"requested"])
        waitForBell(app, count: 1)
        attach(app, name: "One new notification on bell")
        _ = try await qaRequest("/rest/v1/rpc/mark_notifications_viewed", token: sender)
        waitForBell(app, count: 1)
        _ = try await qaRequest("/rest/v1/likes", token: sender, body: ["post_id":post,"user_id":senderID])
        waitForBell(app, count: 2)
        app.buttons["profile.notifications"].tap()
        let confirm = app.buttons["Confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), app.debugDescription); confirm.tap()
        let followBack = app.buttons["notification.followBack." + follower]
        XCTAssertTrue(followBack.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(followBack.label.contains("Follow back")); followBack.tap()
        waitForLabel(followBack, label: "Following")
        attach(app, name: "Follow back inline in notification")
        app.navigationBars.buttons["Profile"].tap()
        waitForBell(app, count: 0)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15)); app.tabBars.buttons.element(boundBy: 4).tap()
        waitForBell(app, count: 0)
        _ = try await qaRequest("/rest/v1/comments", token: sender, body: ["post_id":post,"author_id":senderID,"body":"Badge QA update after checking"])
        waitForBell(app, count: 1)
        app.buttons["profile.notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 10)); app.navigationBars.buttons["Profile"].tap()
        waitForBell(app, count: 0)
        app.tabBars.buttons.element(boundBy: 3).tap()
        let friend = try value("PLUM_QA_CHAT_FRIEND_NAME")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", friend)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12), app.debugDescription); row.tap()
        let sent = app.staticTexts[try value("PLUM_QA_SENT_TEXT")]
        let received = app.staticTexts[try value("PLUM_QA_RECEIVED_TEXT")]
        XCTAssertTrue(sent.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(received.exists)
        XCTAssertGreaterThan(sent.frame.midX, received.frame.midX)
        XCTAssertEqual(sent.value as? String, "Sent"); XCTAssertEqual(received.value as? String, "Received")
        attach(app, name: "Purple outgoing right and gray incoming left")
        app.navigationBars.buttons["Messages"].tap()
        try signOutFromProfile(app)
    }
    @MainActor private func waitForBell(_ app: XCUIApplication, count: Int) {
        let bell = app.buttons["profile.notifications"]
        XCTAssertTrue(bell.waitForExistence(timeout: 12), app.debugDescription)
        expectation(for: NSPredicate(format: "value == %@", "\(count) unread notifications"), evaluatedWith: bell)
        waitForExpectations(timeout: 12)
    }
    @MainActor private func waitForLabel(_ element: XCUIElement, label: String) {
        expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        waitForExpectations(timeout: 12)
    }
    @MainActor private func qaRequest(_ path: String, token: String? = nil, method: String = "POST", body: [String: String] = [:]) async throws -> Data {
        let bundle = Bundle(for: Self.self)
        let base = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_SUPABASE_URL") as? String)
        let key = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_PUBLISHABLE_KEY") as? String)
        var request = URLRequest(url: try XCTUnwrap(URL(string: base + path)))
        request.httpMethod = method; request.setValue(key, forHTTPHeaderField: "apikey"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if method != "GET" { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data,response) = try await URLSession.shared.data(for: request)
        let status = try XCTUnwrap(response as? HTTPURLResponse).statusCode
        guard (200..<300).contains(status) else { throw NSError(domain: "PlumQATest", code: status, userInfo: [NSLocalizedDescriptionKey:"QA request failed: \(path) (\(status))"]) }
        return data
    }
    @MainActor private func qaLogin(email: String) async throws -> String {
        guard email.hasPrefix("plum_"), email.hasSuffix("@example.net") else { throw XCTSkip("Use isolated QA accounts for live mutations") }
        let password = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "PLUM_QA_PASSWORD") as? String)
        let data = try await qaRequest("/auth/v1/token?grant_type=password", body: ["email":email,"password":password])
        return try XCTUnwrap((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["access_token"] as? String)
    }
    @MainActor func testCommentReplyDropdownsAndPersistence() throws {
        continueAfterFailure = false
        let bundle = Bundle(for: Self.self)
        let post = try XCTUnwrap(UUID(uuidString: try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_COMMENT_POST") as? String))).uuidString
        let parent = try XCTUnwrap(UUID(uuidString: try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_COMMENT_ROOT") as? String))).uuidString
        let child = try XCTUnwrap(UUID(uuidString: try XCTUnwrap(bundle.object(forInfoDictionaryKey: "PLUM_QA_COMMENT_CHILD") as? String))).uuidString
        let sentText = "Thread QA sent reply " + UUID().uuidString.prefix(8)
        let app = XCUIApplication(); app.launch(); try signInIfNeeded(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 4).tap()
        let thumbnail = app.buttons["profile.post." + post]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 10), app.debugDescription); thumbnail.tap()
        let rootToggle = app.buttons["comment.replies." + parent]
        XCTAssertTrue(rootToggle.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(rootToggle.label.contains("Show replies"))
        XCTAssertFalse(app.staticTexts["Thread QA first reply"].exists)
        XCTAssertFalse(app.staticTexts["Thread QA second reply"].exists)
        XCTAssertFalse(app.staticTexts["Thread QA nested reply"].exists)
        XCTAssertTrue(app.staticTexts["Thread QA separate comment"].exists)
        for _ in 0..<4 { if rootToggle.isHittable { break }; app.swipeUp() }
        rootToggle.tap()
        XCTAssertTrue(app.staticTexts["Thread QA first reply"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Thread QA second reply"].exists)
        XCTAssertFalse(app.staticTexts["Thread QA nested reply"].exists)
        XCTAssertTrue(rootToggle.label.contains("Hide replies"))
        let childToggle = app.buttons["comment.replies." + child]
        for _ in 0..<4 { if childToggle.isHittable { break }; app.swipeUp() }
        childToggle.tap()
        XCTAssertTrue(app.staticTexts["Thread QA nested reply"].waitForExistence(timeout: 5))
        attach(app, name: "Expanded comment and nested replies")
        for _ in 0..<5 { if rootToggle.isHittable { break }; app.swipeDown() }
        rootToggle.tap()
        XCTAssertFalse(app.staticTexts["Thread QA first reply"].exists)
        XCTAssertFalse(app.staticTexts["Thread QA nested reply"].exists)
        XCTAssertTrue(app.staticTexts["Thread QA separate comment"].exists)
        app.buttons["comment.reply." + parent].tap()
        let field = app.textFields.matching(identifier: "post.comment").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(sentText)
        app.buttons.matching(identifier: "post.sendComment").firstMatch.tap()
        XCTAssertTrue(app.staticTexts[sentText].waitForExistence(timeout: 12), app.debugDescription)
        XCTAssertTrue(rootToggle.label.contains("Hide replies"))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 10)); thumbnail.tap()
        XCTAssertTrue(rootToggle.waitForExistence(timeout: 10))
        XCTAssertTrue(rootToggle.label.contains("Show replies"))
        XCTAssertFalse(app.staticTexts[sentText].exists)
        for _ in 0..<4 { if rootToggle.isHittable { break }; app.swipeUp() }
        rootToggle.tap()
        XCTAssertTrue(app.staticTexts[sentText].waitForExistence(timeout: 6))
        attach(app, name: "Reply persisted beneath parent after relaunch")
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
