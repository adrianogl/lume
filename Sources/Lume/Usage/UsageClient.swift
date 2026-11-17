import Foundation

enum UsageClient {
    private struct Credentials {
        let token: String
        let expiresAt: Date?
        let plan: String?
    }

    private static func credentials(service: String) throws -> Credentials {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { throw UsageError.noCredentials }
        let expiresAt = (oauth["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        return Credentials(token: token, expiresAt: expiresAt, plan: oauth["subscriptionType"] as? String)
    }

    static func fetch(_ account: Account) async throws -> LimitSnapshot {
        let creds = try credentials(service: account.keychainService)
        if let expiresAt = creds.expiresAt, expiresAt < Date() { throw UsageError.expired }

        var request = URLRequest(url: UsageConfig.usageURL)
        request.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
        request.setValue(UsageConfig.oauthBeta, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw UsageError.expired }
        if status == 429 {
            let retryAfter = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw UsageError.rateLimited(retryAfter: retryAfter)
        }
        guard status == 200 else { throw UsageError.http(status) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw UsageError.decode }

        return LimitSnapshot(
            fiveHour: window(json["five_hour"]),
            sevenDay: window(json["seven_day"]),
            plan: creds.plan,
            fetchedAt: Date()
        )
    }

    private static func window(_ value: Any?) -> LimitWindow? {
        guard let dict = value as? [String: Any], let utilization = dict["utilization"] as? Double else { return nil }
        let resetsAt = (dict["resets_at"] as? String).flatMap(DateParsing.iso)
        return LimitWindow(utilization: utilization, resetsAt: resetsAt)
    }
}

enum DateParsing {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plain = ISO8601DateFormatter()

    static func iso(_ string: String) -> Date? {
        fractional.date(from: string) ?? plain.date(from: string)
    }
}
