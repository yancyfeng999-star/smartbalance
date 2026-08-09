import Foundation
@testable import Infrastructure

/// Fixed-response `HTTPClient` for provider unit tests.
struct MockHTTPClient: HTTPClient, Sendable {
    let statusCode: Int
    let body: Data
    /// Optional sequence for multi-call flows (e.g. New-API Bearer then bare token).
    let responses: [(statusCode: Int, body: Data)]?
    private let state: MockHTTPClientState

    init(statusCode: Int = 200, body: Data) {
        self.statusCode = statusCode
        self.body = body
        self.responses = nil
        self.state = MockHTTPClientState()
    }

    init(statusCode: Int = 200, json: String) {
        self.init(statusCode: statusCode, body: Data(json.utf8))
    }

    init(responses: [(statusCode: Int, body: Data)]) {
        self.statusCode = responses.first?.statusCode ?? 500
        self.body = responses.first?.body ?? Data()
        self.responses = responses
        self.state = MockHTTPClientState()
    }

    var callCount: Int { state.callCount }

    /// Authorization header values in call order (for Bearer → bare-token assertions).
    var authorizationHeaders: [String] { state.authorizationHeaders }

    /// Other request headers (e.g. `Dmx-Api-User`) in call order.
    var customHeaders: [String: [String]] { state.customHeaders }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let auth = request.value(forHTTPHeaderField: "Authorization")
        var extras: [String: String] = [:]
        if let dmxUser = request.value(forHTTPHeaderField: "Dmx-Api-User") {
            extras["Dmx-Api-User"] = dmxUser
        }
        if let newAPIUser = request.value(forHTTPHeaderField: "New-API-User") {
            extras["New-API-User"] = newAPIUser
        }
        if let cookie = request.value(forHTTPHeaderField: "Cookie") {
            extras["Cookie"] = cookie
        }
        if let groupId = request.value(forHTTPHeaderField: "X-Group-Id") {
            extras["X-Group-Id"] = groupId
        }
        let index = state.recordCall(authorization: auth, customHeaders: extras) - 1
        let code: Int
        let data: Data
        if let responses {
            let item = responses[min(index, responses.count - 1)]
            code = item.statusCode
            data = item.body
        } else {
            code = statusCode
            data = body
        }
        let url = request.url ?? URL(string: "https://example.invalid")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: code,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}

/// Tiny mutex box so `MockHTTPClient` stays a Sendable value type.
private final class MockHTTPClientState: @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private var _authorizationHeaders: [String] = []
    private var _customHeaders: [String: [String]] = [:]

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    var authorizationHeaders: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _authorizationHeaders
    }

    var customHeaders: [String: [String]] {
        lock.lock()
        defer { lock.unlock() }
        return _customHeaders
    }

    @discardableResult
    func recordCall(authorization: String?, customHeaders: [String: String] = [:]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        _callCount += 1
        if let authorization {
            _authorizationHeaders.append(authorization)
        }
        for (key, value) in customHeaders {
            _customHeaders[key, default: []].append(value)
        }
        return _callCount
    }
}
