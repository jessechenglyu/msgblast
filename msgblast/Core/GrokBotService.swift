import Foundation
import CryptoKit
import Security
import LocalAuthentication

public struct GrokBotCredentials: Codable, Sendable {
    public let webhookURL: URL
    let webhookKey: String
    public init(webhookURL: String, webhookKey: String) throws {
        guard let url = URL(string: webhookURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.host?.isEmpty == false, parts.user == nil, parts.password == nil, parts.fragment == nil,
              parts.port == nil || parts.port == 443 else { throw GrokBotServiceError.invalidAddress }
        let key = webhookKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.utf8.count >= 32, key.utf8.count <= 1024, !key.contains(where: { $0.isWhitespace || $0.isNewline }) else { throw GrokBotServiceError.invalidKey }
        self.webhookURL = url; self.webhookKey = key
    }
}

public struct GrokBotReceipt: Codable, Sendable {
    public enum Status: String, Codable, Sendable { case answered, failed }
    public let request_id: UUID
    public let status: Status
    public let answer: String
}

public enum GrokBotConnectionActivity: Sendable {
    case readingKey, savingKey, startingTunnel
    public var title: String {
        switch self {
        case .readingKey: "Reading saved key…"
        case .savingKey: "Saving key…"
        case .startingTunnel: "Starting reply tunnel…"
        }
    }
    public var detail: String {
        switch self {
        case .readingKey, .savingKey: "Checking secure local storage silently. This step waits up to 15 seconds."
        case .startingTunnel: "The temporary reply address can take up to 90 seconds to become reachable."
        }
    }
}

public enum GrokBotService {
    public static let maximumBytes = 128 * 1024
    public static let routineInstructions = """
    Create an enabled webhook-triggered routine named “msgblast” on this Bot.
    On each run, read the webhook JSON body: request_id, comparison_id, message,
    history, callback_url and callback_token. Use message as the request and history
    as that comparison's prior conversation. Keep comparison IDs separate.
    Do not run the same request_id twice.
    When finished, POST JSON to callback_url with Authorization: Bearer <callback_token>:
    {"request_id":"<received request_id>","status":"answered","answer":"<your answer>"}.
    If the task fails, use status “failed” and explain the failure in answer.
    Retry a failed callback with the same request_id and answer without repeating
    the task. Also post the result in this Bot's chat. Never log callback credentials.
    """

    public static func encodeRequest(id: UUID, comparisonID: UUID, message: String, history: [WebPageMessage], callbackURL: URL, callbackToken: String) throws -> Data {
        struct Turn: Encodable { let role: String; let text: String }
        struct Payload: Encodable { let source = "msgblast"; let request_id: String; let comparison_id: String; let message: String; let history: [Turn]; let callback_url: URL; let callback_token: String }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GrokBotServiceError.emptyMessage }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Payload(request_id: id.uuidString.lowercased(), comparison_id: comparisonID.uuidString.lowercased(), message: message, history: history.map { Turn(role: $0.role, text: $0.text) }, callback_url: callbackURL, callback_token: callbackToken))
        guard data.count <= maximumBytes else { throw GrokBotServiceError.tooLarge }
        return data
    }
    public static func decodeReceipt(_ data: Data, id: UUID) throws -> GrokBotReceipt {
        guard data.count <= maximumBytes, let value = try? JSONDecoder().decode(GrokBotReceipt.self, from: data),
              value.request_id == id, !value.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GrokBotServiceError.invalidReply }
        return value
    }
    public static func submit(_ credentials: GrokBotCredentials, body: Data, session suppliedSession: URLSession? = nil) async throws {
        var request = URLRequest(url: credentials.webhookURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.webhookKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body; request.httpShouldHandleCookies = false
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false; configuration.httpCookieStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 30
        let session = suppliedSession ?? URLSession(configuration: configuration)
        defer { if suppliedSession == nil { session.invalidateAndCancel() } }
        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: GrokBotRedirectPolicy())
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse else { throw GrokBotServiceError.unavailable }
            switch response.statusCode {
            case 200: return
            case 401, 403: throw GrokBotServiceError.unauthorized
            default: throw GrokBotServiceError.rejected(response.statusCode)
            }
        } catch let error as GrokBotServiceError { throw error }
        catch { throw GrokBotServiceError.unavailable }
    }
}

public enum GrokBotServiceError: LocalizedError, Equatable {
    case invalidAddress, invalidKey, emptyMessage, tooLarge, invalidReply, unauthorized, unavailable, keychain, keychainWaiting, callbackUnavailable, tunnelHelperMissing
    case rejected(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidAddress: "Enter the routine's HTTPS webhook URL."
        case .invalidKey: "Enter the routine's webhook key, without spaces."
        case .emptyMessage: "Enter a message for Grok Bot."
        case .tooLarge: "This conversation is too large to send. Start a new comparison."
        case .invalidReply: "Grok Bot returned an invalid callback."
        case .unauthorized: "Grok Bot rejected the webhook key. Check the connection in Settings."
        case .rejected(let code): "Grok Bot did not start this request (HTTP \(code)). Check the routine URL, key and paused state."
        case .unavailable: "The webhook result could not be confirmed. This request has not been resent."
        case .keychain: "Grok Bot's saved connection could not be read or written securely. Enter the webhook details again to replace it."
        case .keychainWaiting: "Secure local storage did not respond. Enter the webhook details to connect for this session, or retry loading the saved connection."
        case .callbackUnavailable: "The reply connection is unavailable. Keep msgblast open and reconnect Grok Bot."
        case .tunnelHelperMissing: "The bundled tunnel helper is missing. Reinstall msgblast to connect Grok Bot."
        }
    }
    var definitelyNotSubmitted: Bool {
        if case .rejected = self { return true }
        return self == .unauthorized
    }
}

enum GrokBotCredentialStore {
    private static let workers = GrokBotCredentialWorkers()
    static func query(_ storageURL: URL) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.msgblast.grokbot.\(Bundle.main.bundleIdentifier ?? "unknown")",
                kSecAttrAccount as String: SHA256.hash(data: Data(storageURL.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined(),
                kSecUseDataProtectionKeychain as String: true,
                kSecUseAuthenticationContext as String: context,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]
    }
    private static var supportsProtectedStorage: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        for name in ["com.apple.application-identifier", "keychain-access-groups", "com.apple.security.application-groups"] {
            let value = SecTaskCopyValueForEntitlement(task, name as CFString, nil)
            if let value = value as? String, !value.isEmpty { return true }
            if let value = value as? [String], !value.isEmpty { return true }
        }
        return false
    }
    static func read(_ storageURL: URL) async throws -> GrokBotCredentials? {
        try await workers.worker(for: storageURL).perform { try readSynchronously(storageURL) }
    }
    private static func readSynchronously(_ storageURL: URL) throws -> GrokBotCredentials? {
        try readAvailableStorage(storageURL, hardwareAvailable: SecureEnclave.isAvailable) {
            try readProtectedKeychain(storageURL)
        }
    }
    static func readAvailableStorage(_ storageURL: URL, hardwareAvailable: Bool, readKeychain: () throws -> GrokBotCredentials?) throws -> GrokBotCredentials? {
        if hardwareAvailable, let credentials = try GrokBotCredentialVault.read(storageURL) { return credentials }
        return try readKeychain()
    }
    private static func readProtectedKeychain(_ storageURL: URL) throws -> GrokBotCredentials? {
        // Ad-hoc Dev builds cannot claim a provisioned Keychain access group.
        guard supportsProtectedStorage else { return nil }
        var query = query(storageURL); query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if [errSecItemNotFound, errSecMissingEntitlement, errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable].contains(status) { return nil }
        guard status == errSecSuccess, let data = result as? Data, let value = try? JSONDecoder().decode(GrokBotCredentials.self, from: data) else { throw GrokBotServiceError.keychain }
        return try GrokBotCredentials(webhookURL: value.webhookURL.absoluteString, webhookKey: value.webhookKey)
    }
    static func save(_ credentials: GrokBotCredentials, at storageURL: URL) async throws -> Bool {
        try await workers.worker(for: storageURL).perform { try saveSynchronously(credentials, at: storageURL) }
    }
    private static func saveSynchronously(_ credentials: GrokBotCredentials, at storageURL: URL) throws -> Bool {
        if SecureEnclave.isAvailable {
            try GrokBotCredentialVault.save(credentials, at: storageURL)
            return true
        }
        guard supportsProtectedStorage else { return false }
        let query = query(storageURL), data = try JSONEncoder().encode(credentials)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            if [errSecMissingEntitlement, errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable].contains(added) { return false }
            guard added == errSecSuccess else { throw GrokBotServiceError.keychain }
        } else if [errSecMissingEntitlement, errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable].contains(status) { return false }
        else if status != errSecSuccess { throw GrokBotServiceError.keychain }
        return true
    }
}

/// Different bot profiles can restore independently. A pending call still owns
/// its profile's admission slot, including after its caller has timed out.
final class GrokBotCredentialWorkers: @unchecked Sendable {
    private let lock = NSLock()
    private var workers: [String: GrokBotCredentialWorker] = [:]
    func worker(for storageURL: URL) -> GrokBotCredentialWorker {
        let scope = storageURL.standardizedFileURL.path
        return lock.withLock {
            if let worker = workers[scope] { return worker }
            let worker = GrokBotCredentialWorker()
            workers[scope] = worker
            return worker
        }
    }
}

/// Security calls can stall in the system service. Bound the caller's wait without blocking the UI
/// or queuing more credential mutations behind an operation that has not returned yet.
final class GrokBotCredentialWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.msgblast.grokbot.credentials", qos: .userInitiated)
    private let lock = NSLock()
    private var running = false

    func perform<Value: Sendable>(timeout: TimeInterval = 15, _ operation: @escaping @Sendable () throws -> Value) async throws -> Value {
        let admitted = lock.withLock {
            if running { return false }
            running = true
            return true
        }
        guard admitted else { throw GrokBotServiceError.keychainWaiting }
        return try await withCheckedThrowingContinuation { continuation in
            let completion = KeychainCompletion(continuation)
            queue.async { [self] in
                let result = Result(catching: operation)
                lock.withLock { running = false }
                completion.finish(result)
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                completion.finish(.failure(GrokBotServiceError.keychainWaiting))
            }
        }
    }
}

private final class KeychainCompletion<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    init(_ continuation: CheckedContinuation<Value, Error>) { self.continuation = continuation }
    func finish(_ result: Result<Value, Error>) {
        let waiting = lock.withLock {
            let waiting = continuation
            continuation = nil
            return waiting
        }
        waiting?.resume(with: result)
    }
}
private final class GrokBotRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
