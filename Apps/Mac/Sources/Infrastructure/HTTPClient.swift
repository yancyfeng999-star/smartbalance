import Foundation

/// Injectable HTTP transport for providers (enables unit tests without network).
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Default production client backed by `URLSession`（带超时，避免单平台挂死整页「查询中」）。
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 12
            config.timeoutIntervalForResource = 20
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var req = request
        if req.timeoutInterval <= 0 || req.timeoutInterval > 20 {
            req.timeoutInterval = 12
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
