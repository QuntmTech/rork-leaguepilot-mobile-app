import Foundation

struct PocketBaseRealtimeRecord: Decodable, Equatable {
    let id: String
    let collectionName: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case collectionName = "collectionName"
    }
}

struct PocketBaseRealtimeEvent: Decodable, Equatable {
    let action: String
    let record: PocketBaseRealtimeRecord
}

/// Keeps the low-level PocketBase SSE connection outside SessionStore so it can be replaced by a
/// deterministic stream in tests. Authorization is sent only when subscriptions are registered.
protocol PocketBaseRealtimeServicing: AnyObject {
    func events(token: String, collections: [String]) -> AsyncThrowingStream<PocketBaseRealtimeEvent, Error>
}

final class PocketBaseRealtimeService: PocketBaseRealtimeServicing {
    private let baseURL: URL
    private let session: URLSession
    private let reconnectDelayNanoseconds: UInt64

    init(baseURL: URL = LeaguePilotConfig.baseURL, session: URLSession = .shared, reconnectDelayNanoseconds: UInt64 = 1_000_000_000) {
        self.baseURL = baseURL
        self.session = session
        self.reconnectDelayNanoseconds = reconnectDelayNanoseconds
    }

    func events(token: String, collections: [String]) -> AsyncThrowingStream<PocketBaseRealtimeEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [baseURL, session, reconnectDelayNanoseconds] in
                while !Task.isCancelled {
                    do {
                        try await Self.receiveConnection(
                            baseURL: baseURL,
                            session: session,
                            token: token,
                            collections: collections,
                            continuation: continuation
                        )
                    } catch is CancellationError {
                        break
                    } catch let error as LeaguePilotError where error.isSessionExpired {
                        continuation.finish(throwing: error)
                        return
                    } catch {
                        // PocketBase closes quiet SSE streams and network changes are normal on
                        // mobile. Retry transient failures, but never retry an expired session.
                    }
                    guard !Task.isCancelled else { break }
                    try? await Task.sleep(nanoseconds: reconnectDelayNanoseconds)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func receiveConnection(
        baseURL: URL,
        session: URLSession,
        token: String,
        collections: [String],
        continuation: AsyncThrowingStream<PocketBaseRealtimeEvent, Error>.Continuation
    ) async throws {
        let realtimeURL = try url(baseURL: baseURL)
        var request = URLRequest(url: realtimeURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 360

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LeaguePilotError(status: (response as? HTTPURLResponse)?.statusCode, message: "Couldn’t start live updates.")
        }

        var eventName = ""
        var dataLines: [String] = []
        for try await line in bytes.lines {
            if Task.isCancelled { return }
            if line.isEmpty {
                try await handle(
                    eventName: eventName,
                    dataLines: dataLines,
                    realtimeURL: realtimeURL,
                    session: session,
                    token: token,
                    collections: collections,
                    continuation: continuation
                )
                eventName = ""
                dataLines = []
            } else if line.hasPrefix("event:") {
                eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces))
            }
        }
    }

    private static func handle(
        eventName: String,
        dataLines: [String],
        realtimeURL: URL,
        session: URLSession,
        token: String,
        collections: [String],
        continuation: AsyncThrowingStream<PocketBaseRealtimeEvent, Error>.Continuation
    ) async throws {
        guard !dataLines.isEmpty else { return }
        let data = Data(dataLines.joined(separator: "\n").utf8)
        if eventName == "PB_CONNECT" {
            struct ConnectPayload: Decodable { let clientId: String }
            let connect = try JSONDecoder().decode(ConnectPayload.self, from: data)
            struct SubscriptionRequest: Encodable { let clientId: String; let subscriptions: [String] }
            var request = URLRequest(url: realtimeURL)
            request.httpMethod = "POST"
            request.httpBody = try JSONEncoder().encode(SubscriptionRequest(clientId: connect.clientId, subscriptions: collections.map { "\($0)/*" }))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "Authorization")
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw LeaguePilotError(status: (response as? HTTPURLResponse)?.statusCode, message: "Couldn’t authorize live updates.")
            }
            return
        }

        guard let message = try? JSONDecoder().decode(PocketBaseRealtimeEvent.self, from: data) else { return }
        continuation.yield(message)
    }

    private static func url(baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw LeaguePilotError(status: nil, message: "Invalid server URL.")
        }
        components.path = components.path + "/api/realtime"
        guard let url = components.url else { throw LeaguePilotError(status: nil, message: "Invalid server URL.") }
        return url
    }
}
