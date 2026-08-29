import Foundation

public final class BatteryStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = applicationSupport
                .appendingPathComponent("BatteryIndicator", isDirectory: true)
                .appendingPathComponent("history.json")
        }
    }

    public func load() -> BatteryHistory {
        guard let data = try? Data(contentsOf: fileURL) else { return BatteryHistory() }
        return (try? decoder.decode(BatteryHistory.self, from: data)) ?? BatteryHistory()
    }

    public func save(_ history: BatteryHistory) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(history)
        try data.write(to: fileURL, options: .atomic)
    }
}
