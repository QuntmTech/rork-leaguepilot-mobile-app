import Foundation

/// Public app configuration. The CloudPod origin is not a credential and can be overridden through
/// the generated Info.plist `LEAGUEPILOT_CLOUDPOD_URL` build setting.
enum LeaguePilotConfig {
    static let fallbackCloudPodURL = URL(string: "https://leaguepilot-ai.cloudpod.pro")!
    static let connectionsCollection = "espn_connections"
    static let jobsCollection = "job_runs"
    static let recommendationsCollection = "recommendations"
    static let snapshotsCollection = "league_snapshots"
    static let defaultSeason = "2026"

    static var baseURL: URL {
        baseURL(from: Bundle.main.object(forInfoDictionaryKey: "LEAGUEPILOT_CLOUDPOD_URL") as? String)
    }

    static func baseURL(from rawValue: String?) -> URL {
        guard let rawValue,
              !rawValue.isEmpty,
              !rawValue.contains("$("),
              let components = URLComponents(string: rawValue),
              components.scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              (components.path.isEmpty || components.path == "/"),
              let url = components.url else {
            return fallbackCloudPodURL
        }
        return url
    }
}
