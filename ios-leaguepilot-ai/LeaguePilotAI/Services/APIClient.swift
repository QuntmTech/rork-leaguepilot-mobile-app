import Foundation

/// Error surfaced to the UI with a friendly message.
struct LeaguePilotError: LocalizedError {
    let status: Int?
    let message: String

    var errorDescription: String? { message }

    /// Builds an error from a failed HTTP response, preferring the server's message.
    static func from(data: Data, status: Int) -> LeaguePilotError {
        struct ServerError: Decodable { let message: String? }
        let serverMessage = (try? JSONDecoder().decode(ServerError.self, from: data))?.message
        let safeMessage = serverMessage?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return LeaguePilotError(
            status: status,
            message: safeMessage?.isEmpty == false ? String(safeMessage!.prefix(500)) : "Request failed (\(status))."
        )
    }

    /// A 401 confirms the token is no longer valid. A 403 can instead be a collection or
    /// subscription permission problem, so callers must not erase a valid session for it.
    var isSessionExpired: Bool { status == 401 }
    var isPermissionDenied: Bool { status == 403 }
}

/// Minimal JSON client for the cloudpod PocketBase server.
final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    /// Sends a JSON request and returns the raw response data.
    func send(
        _ method: String,
        _ path: String,
        body: Data? = nil,
        query: [String: String]? = nil,
        token: String? = nil
    ) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw LeaguePilotError(status: nil, message: "Invalid server URL.")
        }
        components.path = components.path + path
        if let query, !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw LeaguePilotError(status: nil, message: "Invalid server URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LeaguePilotError(status: nil, message: "Unexpected server response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LeaguePilotError.from(data: data, status: http.statusCode)
        }
        return data
    }

    /// Sends a JSON request and decodes the response into `T`.
    func send<T: Decodable>(
        _ type: T.Type,
        method: String,
        path: String,
        body: Data? = nil,
        query: [String: String]? = nil,
        token: String? = nil
    ) async throws -> T {
        let data = try await send(method, path, body: body, query: query, token: token)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
