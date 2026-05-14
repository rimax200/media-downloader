import Foundation

enum URLValidator {
    static func looksLikeWebURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        guard let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        return components.host?.isEmpty == false
    }

    static func unsupportedPlatformMessage(for value: String) -> String? {
        guard let host = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines))?.host?.lowercased() else {
            return nil
        }

        if host == "www.threads.net" || host == "threads.net" {
            return "Threads videos can't be downloaded — Meta blocks third-party access."
        }

        return nil
    }
}
