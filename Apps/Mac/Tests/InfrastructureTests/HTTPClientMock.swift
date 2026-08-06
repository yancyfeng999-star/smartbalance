import Foundation
@testable import Infrastructure

/// Fixed-response `HTTPClient` for provider unit tests.
struct MockHTTPClient: HTTPClient, Sendable {
    let statusCode: Int
    let body: Data
    /// Optional sequence for multi-call flows (e.g. New-API Bearer then bare token).
    let responses: [(statusCode: Int, body: Data)]?
    private let callCountBox: CallCountBox

    init(statusCode: Int = 200, body: Data) {
        self.statusCode = statusCode
        self.body = body
        self.responses = nil
        self.callCountBox = CallCountBox()
    }

    init(statusCode: Int = 200, json: String) {
        self.init(statusCode: statusCode, body: Data(json.utf8))
    }

    init(responses: [(statusCode: Int, body: Data)]) {
        self.statusCode = responses.first?.statusCode ?? 500
        self.body = responses.first?.body ?? Data()
        self.responses = responses
        self.callCountBox = CallCountBox()
    }

    var callCount: Int { callCountBox.value }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = callCountBox.increment() - 1
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
private final class CallCountBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
        return _value
    }
}
