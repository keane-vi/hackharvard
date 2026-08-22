import Foundation
import SwiftData

/// Loads developer-only scan history when the ignored local fixture is present.
/// Real uploads continue to be persisted by CameraView as normal.
enum LocalFixtureLoader {
    private struct Fixture: Decodable {
        let date: Date
        let hrBpm: Double?
        let prvSdnnMs: Double?
        let prvRmssdMs: Double?
        let rrBrpm: Double?
        let spo2Pct: Double?
        let hrQuality: String
        let prvQuality: String
        let rrQuality: String
        let spo2Quality: String

        private enum CodingKeys: String, CodingKey {
            case date, hrBpm, prvSdnnMs, prvRmssdMs, rrBrpm, spo2Pct
            case hrQuality, prvQuality, rrQuality, spo2Quality
        }
    }

    static func seedIfAvailable(in modelContext: ModelContext) {
        // Xcode's filesystem-synchronized groups flatten this resource into the
        // bundle root. Keep the subdirectory lookup as a fallback for projects
        // that use an explicit resource reference.
        guard let url = Bundle.main.url(forResource: "scan_records", withExtension: "json")
            ?? Bundle.main.url(forResource: "scan_records", withExtension: "json", subdirectory: "LocalFixtures")
        else {
            return
        }

        guard let existing = try? modelContext.fetch(FetchDescriptor<ScanRecord>()), existing.isEmpty else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fixtures = try decoder.decode([Fixture].self, from: Data(contentsOf: url))
            for fixture in fixtures {
                modelContext.insert(ScanRecord(
                    date: fixture.date,
                    hrBpm: fixture.hrBpm,
                    prvSdnnMs: fixture.prvSdnnMs,
                    prvRmssdMs: fixture.prvRmssdMs,
                    rrBrpm: fixture.rrBrpm,
                    spo2Pct: fixture.spo2Pct,
                    hrQuality: fixture.hrQuality,
                    prvQuality: fixture.prvQuality,
                    rrQuality: fixture.rrQuality,
                    spo2Quality: fixture.spo2Quality
                ))
            }
            try modelContext.save()
        } catch {
            // Local fixtures are optional developer data; a malformed file must not
            // prevent the app from opening or from accepting future uploads.
        }
    }
}
