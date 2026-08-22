import SwiftUI
import SwiftData

struct InsightDetailView: View {
    let metric: InsightMetric
    let allScans: [ScanRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var timeframe: InsightTimeframe = .week

    private var points: [InsightDataPoint] {
        InsightMath.points(from: allScans, metric: metric, timeframe: timeframe)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                TimeframePicker(selection: $timeframe)

                if points.count >= 2 {
                    InteractiveTrendChart(metric: metric, points: points)
                        .frame(height: 240)
                    InsightSummary(metric: metric, points: points)
                    suggestion
                } else {
                    emptyState
                }

                Text("Contactless estimates for wellness, not a clinical diagnosis.")
                    .font(.caption2)
                    .foregroundStyle(VantaTheme.textMuted)
            }
            .padding(20)
        }
        .background(VantaTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(VantaTheme.textPrimary)
                }
            }
        }
    }

    private var header: some View {
        Text(metric.title)
            .font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(VantaTheme.textPrimary)
    }

    private var suggestion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this pattern suggests")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VantaTheme.textPrimary)
            Text("Your \(metric.title.lowercased()) has stayed close to your usual range this \(timeframe == .year ? "year" : "period").")
                .font(.footnote)
                .foregroundStyle(VantaTheme.textMuted)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.largeTitle)
                .foregroundStyle(VantaTheme.textMuted)
            Text("Not enough scans yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VantaTheme.textPrimary)
            Text("Complete a few more scans to see this trend.")
                .font(.footnote)
                .foregroundStyle(VantaTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview("Populated") {
    NavigationStack {
        InsightDetailView(
            metric: .pulse,
            allScans: (0..<10).map { i in
                ScanRecord(date: Date().addingTimeInterval(Double(i) * -3600 * 12), from: .mock(hr: Double.random(in: 62...82)))
            }
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        InsightDetailView(metric: .breathing, allScans: [])
    }
}

private extension VitalsResponse {
    static func mock(hr: Double) -> VitalsResponse {
        let json = """
        {"hr_bpm": \(hr), "prv_sdnn_ms": 40, "prv_rmssd_ms": 35, "rr_brpm": 14, "spo2_pct": 98, "quality": {"hr": "good", "prv": "good", "rr": "good", "spo2": "good"}, "meta": {"duration_s": 30, "fs": 30, "disclaimer": ""}, "error": null}
        """
        return try! JSONDecoder().decode(VitalsResponse.self, from: Data(json.utf8))
    }
}
