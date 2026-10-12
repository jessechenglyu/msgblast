import XCTest
import Foundation
@testable import msgblastCore

@MainActor final class BenchmarkAccountTests: XCTestCase {
    private func configuration(profile: String = "demo") throws -> BenchmarkAccountConfiguration {
        try BenchmarkAccountConfiguration(serviceURL: URL(string: "http://127.0.0.1:8787")!, issuer: URL(string: "https://tenant.example/")!, clientID: "fixture-native", audience: "benchmarks", callbackURL: URL(string: "com.example.demo:/account")!, bundleIdentifier: "com.example.demo", profile: profile, demoFixture: true)
    }
    func testRealCodeExchangeVerifiesAPIBearerBeforeSaving() async throws {
        let config = try configuration(), browser = FixtureBrowser(), http = FixtureHTTP(), store = FixtureStore()
        http.responses = [tokenResponse(), accountResponse("opaque-A")]
        let session = BenchmarkAccountSession(configuration: config, browser: browser, transport: http, tokenStore: store)
        await session.signIn()
        XCTAssertEqual(session.account?.accountID, "opaque-A")
        XCTAssertEqual(store.items[config.tokenScope]?.accountID, "opaque-A")
        XCTAssertEqual(http.requests.count, 2)
        XCTAssertEqual(http.requests[0].url, URL(string: "https://tenant.example/oauth/token"))
        let body = String(decoding: try XCTUnwrap(http.requests[0].httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("code_verifier=")); XCTAssertTrue(body.contains("grant_type=authorization_code"))
        XCTAssertFalse(body.contains("client_secret"))
        XCTAssertEqual(http.requests[1].url?.path, "/api/v1/account")
        XCTAssertEqual(http.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer fixture-access")
        let items = URLComponents(url: try XCTUnwrap(browser.openedURL), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first(where: { $0.name == "code_challenge_method" })?.value, "S256")
        XCTAssertTrue(items?.first(where: { $0.name == "scope" })?.value?.contains("benchmarks:write") == true)
        // Merely signing in sends no session data and opts into no sync.
        XCTAssertEqual(http.requests.map { $0.httpMethod ?? "GET" }, ["POST", "GET"])
    }
    func testWrongCallbackNeverExchangesOrStoresCredentials() async throws {
        let browser = FixtureBrowser(); browser.wrongState = true
        let http = FixtureHTTP(), store = FixtureStore()
        let session = BenchmarkAccountSession(configuration: try configuration(), browser: browser, transport: http, tokenStore: store)
        await session.signIn()
        XCTAssertNil(session.account); XCTAssertNotNil(session.errorMessage)
        XCTAssertTrue(http.requests.isEmpty); XCTAssertTrue(store.items.isEmpty)
    }
    func testSignOutRejectsLateBrowserCompletion() async throws {
        let browser = FixtureBrowser(); browser.hold = true
        let http = FixtureHTTP(), store = FixtureStore()
        let session = BenchmarkAccountSession(configuration: try configuration(), browser: browser, transport: http, tokenStore: store)
        let task = Task { await session.signIn() }
        while browser.pending == nil { await Task.yield() }
        session.signOut()
        browser.complete()
        await task.value
        XCTAssertNil(session.account); XCTAssertTrue(store.items.isEmpty); XCTAssertTrue(http.requests.isEmpty)
    }
    func testKeychainFailureIsVisibleAndDoesNotActivateAccount() async throws {
        let store = FixtureStore(); store.failSave = true
        let http = FixtureHTTP(); http.responses = [tokenResponse(), accountResponse("opaque-A")]
        let session = BenchmarkAccountSession(configuration: try configuration(), browser: FixtureBrowser(), transport: http, tokenStore: store)
        await session.signIn()
        XCTAssertNil(session.account); XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(session.errorMessage, "Benchmark credentials could not be accessed in Keychain.")
    }
    func testExpiredRestoreRefreshesAndRejectsChangedVerifiedAccount() async throws {
        let config = try configuration(), http = FixtureHTTP(), store = FixtureStore()
        store.items[config.tokenScope] = BenchmarkAccountTokens(accessToken: "expired", refreshToken: "refresh+A", expiresAt: .distantPast, accountID: "opaque-A")
        http.responses = [tokenResponse(), accountResponse("opaque-B")]
        let session = BenchmarkAccountSession(configuration: config, browser: FixtureBrowser(), transport: http, tokenStore: store)
        await session.restore()
        XCTAssertNil(session.account)
        XCTAssertEqual(store.items[config.tokenScope]?.accountID, "opaque-A")
        let body = String(decoding: try XCTUnwrap(http.requests.first?.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("grant_type=refresh_token")); XCTAssertTrue(body.contains("refresh_token=refresh%2BA"))
        XCTAssertEqual(session.errorMessage, "The verified benchmark account changed. Sign in again.")
    }
    func testRestoreAndCloudRequestAreAccountBoundAndLateResponseIsRejected() async throws {
        let config = try configuration(), http = FixtureHTTP(), store = FixtureStore()
        store.items[config.tokenScope] = BenchmarkAccountTokens(accessToken: "saved", refreshToken: nil, expiresAt: .distantFuture, accountID: "opaque-A")
        http.responses = [accountResponse("opaque-A")]
        let session = BenchmarkAccountSession(configuration: config, browser: FixtureBrowser(), transport: http, tokenStore: store)
        await session.restore()
        XCTAssertEqual(session.account?.accountID, "opaque-A")
        do { _ = try await session.request(path: "/api/v1/sessions", accountID: "opaque-B"); XCTFail("Wrong account cannot transmit") } catch {}
        XCTAssertEqual(http.requests.count, 1)
        http.hold = true
        let task = Task { try await session.request(path: "/api/v1/sessions", method: "POST", body: Data("fixture".utf8), accountID: "opaque-A") }
        while http.pending == nil { await Task.yield() }
        session.signOut(); http.complete()
        do { _ = try await task.value; XCTFail("Late request must remain canceled") } catch {}
        XCTAssertTrue(store.items.isEmpty); XCTAssertNil(session.account)
        XCTAssertEqual(http.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer saved")
    }
    func testTokenScopesSeparateVariantsProfilesAndRealms() throws {
        let first = try configuration(), second = try configuration(profile: "isolated-two")
        XCTAssertNotEqual(first.tokenScope, second.tokenScope)
        let other = try BenchmarkAccountConfiguration(serviceURL: URL(string: "https://other.example")!, issuer: first.issuer, clientID: first.clientID, audience: first.audience, callbackURL: first.callbackURL, bundleIdentifier: "com.example.production", profile: first.profile)
        XCTAssertNotEqual(first.tokenScope, other.tokenScope)
    }
    func testDemoCannotUseLiveBrowserOrNetworkTransport() async throws {
        let config = try configuration(), store = FixtureStore()
        let session = BenchmarkAccountSession(configuration: config, browser: FixtureBrowser(), transport: BenchmarkURLSessionTransport(), tokenStore: store)
        await session.signIn()
        XCTAssertNil(session.account)
        XCTAssertEqual(session.errorMessage, "Benchmark accounts are not configured.")
        XCTAssertTrue(store.items.isEmpty)
    }
    func testSuccessfulRefreshPersistsRotatedTokenAndRestoresVerifiedIdentity() async throws {
        let config = try configuration(), http = FixtureHTTP(), store = FixtureStore()
        store.items[config.tokenScope] = BenchmarkAccountTokens(accessToken: "expired", refreshToken: "old-refresh", expiresAt: .distantPast, accountID: "opaque-A")
        http.responses = [tokenResponse(), accountResponse("opaque-A"), accountResponse("opaque-A")]
        let session = BenchmarkAccountSession(configuration: config, browser: FixtureBrowser(), transport: http, tokenStore: store)
        await session.restore()
        XCTAssertEqual(session.account?.accountID, "opaque-A")
        XCTAssertEqual(store.items[config.tokenScope]?.refreshToken, "fixture-refresh")
        let token = try await session.accessToken(accountID: "opaque-A")
        XCTAssertEqual(token, "fixture-access")
        XCTAssertEqual(http.requests.count, 3)
    }
    private func tokenResponse() -> Data { Data(#"{"access_token":"fixture-access","refresh_token":"fixture-refresh","expires_in":3600,"token_type":"Bearer","id_token":"untrusted-and-unused"}"#.utf8) }
    private func accountResponse(_ id: String) -> Data { Data("{\"accountID\":\"\(id)\",\"identity\":\"Fixture user\"}".utf8) }
}

@MainActor private final class FixtureBrowser: BenchmarkOAuthBrowser {
    var openedURL: URL?
    var wrongState = false
    var hold = false
    var pending: CheckedContinuation<URL, Error>?
    private var callback: URL?
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        openedURL = url
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let redirect = items.first(where: { $0.name == "redirect_uri" })!.value!
        let state = wrongState ? "wrong" : items.first(where: { $0.name == "state" })!.value!
        callback = URL(string: "\(redirect)?state=\(state)&code=fixture-code")!
        if hold { return try await withCheckedThrowingContinuation { pending = $0 } }
        return callback!
    }
    func cancel() {} // Deliberately ignores cancellation to prove generation guard.
    func complete() { let old = pending; pending = nil; old?.resume(returning: callback!) }
}
@MainActor private final class FixtureHTTP: BenchmarkHTTPTransport {
    var requests: [URLRequest] = []
    var responses: [Data] = []
    var hold = false
    var pending: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if hold { return try await withCheckedThrowingContinuation { pending = $0 } }
        guard !responses.isEmpty else { throw BenchmarkAccountError.invalidResponse }
        return (responses.removeFirst(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func cancelAll() {} // Simulates a transport completion racing cancellation.
    func complete() { let old = pending; pending = nil; old?.resume(returning: (Data(), HTTPURLResponse(url: requests.last!.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)) }
}
@MainActor private final class FixtureStore: BenchmarkTokenStore {
    var items: [String: BenchmarkAccountTokens] = [:]
    var failSave = false
    func read(scope: String) throws -> BenchmarkAccountTokens? { items[scope] }
    func save(_ tokens: BenchmarkAccountTokens, scope: String) throws {
        if failSave { throw BenchmarkAccountError.secureStorage(-25308) }
        items[scope] = tokens
    }
    func delete(scope: String) throws { items.removeValue(forKey: scope) }
}
