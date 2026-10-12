import XCTest

final class OnboardingWorkflowTests: XCTestCase {
    @MainActor
    private func launch(contactsDenied: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo", "--onboarding-preview"]
        if contactsDenied { app.launchArguments.append("--contacts-access-preview") }
        app.launch()
        XCTAssertTrue(app.staticTexts["Connect your agents"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func choose(_ connector: String, in app: XCUIApplication) {
        app.buttons["Connect \(connector)"].click()
        app.buttons["Continue setup"].click()
    }

    @MainActor
    func testConnectorStartHasNoBackAndSeparatesAppsFromCLIs() {
        let app = launch()
        defer { app.terminate() }
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons["Continue setup"].isEnabled)
        choose("Apps", in: app)
        XCTAssertTrue(app.staticTexts["Which apps do you use?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose ChatGPT"].exists)
        XCTAssertTrue(app.buttons["Choose Grok Bot"].exists)
        XCTAssertFalse(app.buttons["Choose Codex CLI"].exists)
        XCTAssertFalse(app.buttons["Choose Fo"].exists)
        app.buttons["Back"].click()
        choose("CLIs", in: app)
        XCTAssertTrue(app.staticTexts["Which CLIs do you use?"].waitForExistence(timeout: 5))
        for name in ["Codex CLI", "Claude Code", "OpenClaw", "Hermes"] {
            XCTAssertTrue(app.buttons["Choose \(name)"].exists)
        }
        XCTAssertFalse(app.buttons["Choose ChatGPT"].exists)
    }

    @MainActor
    func testMessagesChecklistRequiresPermissionsAndSupportsBack() {
        let app = launch(contactsDenied: true)
        defer { app.terminate() }
        choose("Messages", in: app)
        XCTAssertTrue(app.staticTexts["Let’s get your Mac ready"].waitForExistence(timeout: 5))
        for name in ["Messages access", "Contacts", "Sending Messages"] {
            XCTAssertTrue(app.buttons[name].exists)
        }
        XCTAssertFalse(app.buttons["Continue setup"].exists)
        app.buttons["Contacts"].click()
        XCTAssertTrue(app.buttons["Continue setup"].waitForExistence(timeout: 5))
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.staticTexts["Agents we found"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Deselect Fo"].waitForExistence(timeout: 5))
        app.buttons["Back"].click()
        XCTAssertTrue(app.staticTexts["Let’s get your Mac ready"].waitForExistence(timeout: 5))
        app.buttons["Set up Messages later"].click()
        XCTAssertTrue(app.staticTexts["Connect your agents"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDiscoveredMessagesCanBeDeselectedAndContactsSearched() {
        let app = launch()
        defer { app.terminate() }
        choose("Messages", in: app)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Deselect Fo"].waitForExistence(timeout: 5))
        app.buttons["Deselect Fo"].click()
        XCTAssertTrue(app.buttons["Select Fo"].waitForExistence(timeout: 5))
        app.buttons["Select Fo"].click()
        app.buttons["Search for more agents in Messages"].click()
        XCTAssertTrue(app.textFields["Find onboarding contact"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].click()
        app.buttons["Add other agents"].click()
        XCTAssertTrue(app.staticTexts["Connect your agents"].waitForExistence(timeout: 5))
        choose("Apps", in: app)
        app.buttons["Back"].click()
        choose("Messages", in: app)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Deselect Fo"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMessagesContinueGoesToContributionWithoutRepeatedSelection() {
        let app = launch()
        defer { app.terminate() }
        choose("Messages", in: app)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Deselect Fo"].waitForExistence(timeout: 5))
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.staticTexts["Help shape msgblast"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Choose who to connect"].exists)
        XCTAssertTrue(app.buttons["Start chatting"].exists)
    }

    @MainActor
    func testFinishedSetupShowsChosenAgentsWithoutSelectingRecipients() {
        let app = launch()
        defer { app.terminate() }
        choose("Messages", in: app)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Deselect Fo"].waitForExistence(timeout: 5))
        app.buttons["Deselect Fo"].click()
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Start chatting"].waitForExistence(timeout: 5))
        app.buttons["Back"].click()
        XCTAssertTrue(app.staticTexts["Agents we found"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Select Fo"].exists)
        app.buttons["Continue setup"].click()
        app.buttons["Start chatting"].click()
        XCTAssertTrue(app.buttons["Edit agents"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Fo"].exists)
        XCTAssertEqual(app.buttons["Instinct"].value as? String, "Not selected")
        XCTAssertFalse(app.buttons["Add Messages agents"].exists)
        XCTAssertFalse(app.buttons["New Blast"].exists)
        app.buttons["Edit agents"].click()
        XCTAssertFalse(app.buttons["Restore setup agents"].exists)
        app.buttons["Done editing agents"].click()
        app.buttons["Instinct"].click()
        XCTAssertEqual(app.buttons["Instinct"].value as? String, "Selected")
        app.textViews["Shared prompt"].click()
        app.textViews["Shared prompt"].typeText("Local fixture recipient check")
        app.buttons["Send & compare"].click()
        XCTAssertTrue(app.buttons["New Blast"].waitForExistence(timeout: 10))
        app.buttons["New Blast"].click()
        XCTAssertTrue(app.buttons["Edit agents"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["New Blast"].exists)
        XCTAssertFalse(app.buttons["Connect agents"].exists)
    }

    @MainActor
    func testPokeBusinessFixtureMatchesButRequiresExplicitRecipientSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo", "--onboarding-preview", "--business-messages-preview"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Connect your agents"].waitForExistence(timeout: 5))
        choose("Messages", in: app)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Deselect Poke 🌴"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Deselect Poke 🌴"].value as? String, "Connected · Business conversation")
        XCTAssertFalse(app.buttons["Choose conversation"].exists)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Start chatting"].waitForExistence(timeout: 5))
        app.buttons["Start chatting"].click()
        XCTAssertTrue(app.buttons["Poke 🌴"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Poke 🌴"].value as? String, "Not selected")
        app.buttons["Poke 🌴"].click()
        XCTAssertEqual(app.buttons["Poke 🌴"].value as? String, "Selected")
    }

    @MainActor
    func testAppsKeepBrowserImportAndManualConnection() {
        let app = launch()
        defer { app.terminate() }
        choose("Apps", in: app)
        app.buttons["Choose ChatGPT"].click()
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.staticTexts["Use your existing logins"].waitForExistence(timeout: 5))
        app.buttons["Skip for now"].click()
        XCTAssertTrue(app.staticTexts["Let’s connect ChatGPT"].waitForExistence(timeout: 5))
        app.buttons["Back"].click()
        XCTAssertTrue(app.staticTexts["Which apps do you use?"].waitForExistence(timeout: 5))
    }
}
