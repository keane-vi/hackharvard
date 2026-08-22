import Foundation
import SwiftData

@Model
final class ScanRecord {
    var date: Date
    var hrBpm: Double?
    var prvSdnnMs: Double?
    var prvRmssdMs: Double?
    var rrBrpm: Double?
    var spo2Pct: Double?
    var hrQuality: String
    var prvQuality: String
    var rrQuality: String
    var spo2Quality: String

    init(date: Date = .now, from result: VitalsResponse) {
        self.date = date
        self.hrBpm = result.hr_bpm
        self.prvSdnnMs = result.prv_sdnn_ms
        self.prvRmssdMs = result.prv_rmssd_ms
        self.rrBrpm = result.rr_brpm
        self.spo2Pct = result.spo2_pct
        self.hrQuality = result.quality.hr
        self.prvQuality = result.quality.prv
        self.rrQuality = result.quality.rr
        self.spo2Quality = result.quality.spo2
    }

    init(
        date: Date = .now,
        hrBpm: Double?,
        prvSdnnMs: Double?,
        prvRmssdMs: Double?,
        rrBrpm: Double?,
        spo2Pct: Double?,
        hrQuality: String,
        prvQuality: String,
        rrQuality: String,
        spo2Quality: String
    ) {
        self.date = date
        self.hrBpm = hrBpm
        self.prvSdnnMs = prvSdnnMs
        self.prvRmssdMs = prvRmssdMs
        self.rrBrpm = rrBrpm
        self.spo2Pct = spo2Pct
        self.hrQuality = hrQuality
        self.prvQuality = prvQuality
        self.rrQuality = rrQuality
        self.spo2Quality = spo2Quality
    }
}
