import Foundation
import RokuKit

/// Channel icon cache (Phase 2 task 7): memory → disk → network.
/// Networking still goes through RokuKit's ECPClient — this only caches bytes.
actor IconCache {
    private var memory: [String: Data] = [:]
    private let directory: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("ChannelIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func icon(appID: String, ip: String, client: ECPClient) async -> Data? {
        if let cached = memory[appID] {
            return cached
        }
        let fileURL = directory.appendingPathComponent("\(appID).png")
        if let disk = try? Data(contentsOf: fileURL), !disk.isEmpty {
            memory[appID] = disk
            return disk
        }
        guard let fetched = try? await client.icon(appID: appID, ip: ip),
              !fetched.isEmpty else {
            return nil
        }
        memory[appID] = fetched
        try? fetched.write(to: fileURL)
        return fetched
    }
}
