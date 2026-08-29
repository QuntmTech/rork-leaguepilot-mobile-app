import Foundation

/// App-level settings that are safe to keep in source (no secrets here).
enum LeaguePilotConfig {
    /// PocketBase / cloudpod base URL — a public server address, not a secret.
    nonisolated static var baseURL: URL {
        let fromEnv = Config.allValues["EXPO_PUBLIC_CLOUDPOD_URL"] ?? ""
        let raw = fromEnv.isEmpty ? "https://leaguepilot-ai.cloudpod.pro" : fromEnv
        return URL(string: raw) ?? URL(string: "https://leaguepilot-ai.cloudpod.pro")!
    }

    /// PocketBase collections read on Home. Adjust here if your schema names differ.
    static let jobsCollection = "analysis_jobs"
    static let recommendationsCollection = "recommendations"

    static let defaultSeason = "2026"
}
