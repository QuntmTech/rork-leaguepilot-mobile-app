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

    init(baseURL: URL = LeaguePilotConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func events(token: String, collections: [String]) -> AsyncThrowingStream<PocketBaseRealtimeEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [baseURL, session] in
                var backoff = RealtimeReconnectBackoff()
                while !Task.isCancelled {
                    do {
                        let connectionWasHealthy = try await Self.receiveConnection(
                            baseURL: baseURL,
                            session: session,
                            token: token,
                            collections: collections,
                            continuation: continuation
                        )
                        try await Task.sleep(nanoseconds: backoff.nextDelayNanoseconds(afterHealthyConnection: connectionWasHealthy))
                    } catch is CancellationError {
                        break
                    } catch {
                        let failure = error as? RealtimeConnectionFailure
                        let cause = failure?.underlying ?? error
                        if let leaguePilotError = cause as? LeaguePilotError {
                            if leaguePilotError.isSessionExpired || leaguePilotError.isPermissionDenied {
                                continuation.finish(throwing: leaguePilotError)
                                return
                            }
                        }
                        // PocketBase can close a quiet SSE stream and mobile networks can change
                        // underneath it. Retry those transient failures with capped exponential
                        // backoff and jitter; a subscription that became healthy resets the delay.
                        try? await Task.sleep(nanoseconds: backoff.nextDelayNanoseconds(afterHealthyConnection: failure?.wasHealthy ?? false))
                    }
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
    ) async throws -> Bool {
        var connectionWasHealthy = false
        do {
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
                if Task.isCancelled { throw CancellationError() }
                if line.isEmpty {
                    if try await handle(
                        eventName: eventName,
                        dataLines: dataLines,
                        realtimeURL: realtimeURL,
                        session: session,
                        token: token,
                        collections: collections,
                        continuation: continuation
                    ) {
                        connectionWasHealthy = true
                    }
                    eventName = ""
                    dataLines = []
                } else if line.hasPrefix("event:") {
                    eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    dataLines.append(line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces))
                }
            }
            return connectionWasHealthy
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RealtimeConnectionFailure(underlying: error, wasHealthy: connectionWasHealthy)
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
    ) async throws -> Bool {
        guard !dataLines.isEmpty else { return false }
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
            return true
        }

        guard let message = try? JSONDecoder().decode(PocketBaseRealtimeEvent.self, from: data) else { return false }
        continuation.yield(message)
        return false
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

/// Small deterministic policy kept separate from URLSession work so retry behavior can be tested
/// without a live server. The random factor produces 50–100% of the capped exponential delay.
struct RealtimeReconnectBackoff: Equatable {
    static let initialDelayNanoseconds: UInt64 = 1_000_000_000
    static let maximumDelayNanoseconds: UInt64 = 30_000_000_000

    private(set) var consecutiveFailures = 0

    mutating func nextDelayNanoseconds(afterHealthyConnection: Bool, randomUnit: Double = Double.random(in: 0...1)) -> UInt64 {
        if afterHealthyConnection { reset() }
        consecutiveFailures = min(consecutiveFailures + 1, 63)
        let exponent = min(consecutiveFailures - 1, 5)
        let cappedBase = min(Self.initialDelayNanoseconds << UInt64(exponent), Self.maximumDelayNanoseconds)
        let normalizedRandom = min(max(randomUnit, 0), 1)
        return UInt64(Double(cappedBase) * (0.5 + (normalizedRandom * 0.5)))
    }

    mutating func reset() {
        consecutiveFailures = 0
    }
}

private struct RealtimeConnectionFailure: Error {
    let underlying: Error
    let wasHealthy: Bool
}
