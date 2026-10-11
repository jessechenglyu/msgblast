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
    func testPokeBusinessFixtureIsMatchedWithoutAChooserAndNotSelectedForSending() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo", "--onboarding-preview", "--business-messages-preview"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Connect your agents"].waitForExistence(timeout: 5))
        choose("Messages", in: app)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Deselect Poke 🌴"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Business conversation found · sending unavailable"].exists)
        XCTAssertFalse(app.buttons["Choose conversation"].exists)
        app.buttons["Continue setup"].click()
        XCTAssertTrue(app.buttons["Start chatting"].waitForExistence(timeout: 5))
        app.buttons["Start chatting"].click()
        XCTAssertTrue(app.buttons["Poke 🌴"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Poke 🌴"].value as? String, "Business conversation found · sending unavailable")
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
