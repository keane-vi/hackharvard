import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]
    @State private var timeframe: InsightTimeframe = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    TimeframePicker(selection: $timeframe)
                    patterns
                    Text("Contactless estimates for wellness, not a clinical diagnosis.")
                        .font(.caption2)
                        .foregroundStyle(VantaTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(VantaTheme.background.ignoresSafeArea())
            .scrollBounceBehavior(.basedOnSize)
            .navigationDestination(for: InsightMetric.self) { metric in
                InsightDetailView(metric: metric, allScans: scans)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Text("VANTA")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .tracking(2)
                    .foregroundStyle(VantaTheme.textPrimary)

                HStack {
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(VantaTheme.textPrimary)
                        .accessibilityLabel("Filter insights")
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text("INSIGHTS")
                    .font(.footnote.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(VantaTheme.accent)
                Text("Understand your patterns")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(VantaTheme.textPrimary)
                Text("Your signals over time")
                    .font(.subheadline)
                    .foregroundStyle(VantaTheme.textMuted)
            }
        }
    }

    private var patterns: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Patterns")
                .font(.headline)
                .foregroundStyle(VantaTheme.textPrimary)

            NavigationLink(value: InsightMetric.pulse) {
                PatternCard(
                    metric: .pulse,
                    points: InsightMath.points(from: scans, metric: .pulse, timeframe: timeframe),
                    insight: "Stable across the week"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: InsightMetric.breathing) {
                PatternCard(
                    metric: .breathing,
                    points: InsightMath.points(from: scans, metric: .breathing, timeframe: timeframe),
                    insight: "Lowest after your evening scan"
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
