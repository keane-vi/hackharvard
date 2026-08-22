import SwiftUI

struct PatternCard: View {
    let metric: InsightMetric
    let points: [InsightDataPoint]
    let insight: String

    private var latestValue: Double? { points.last?.value }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(metric.title, systemImage: metric.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VantaTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VantaTheme.textMuted)
            }

            if points.count >= 2 {
                TrendChart(points: points)
                    .frame(height: 56)

                HStack(alignment: .firstTextBaseline) {
                    if let latestValue {
                        Text(latestValue.formatted(.number.precision(.fractionLength(0))))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(VantaTheme.accent)
                        Text(metric.unit)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VantaTheme.textMuted)
                    }
                    Spacer()
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(VantaTheme.textMuted)
                }
            } else {
                Text("Not enough scans yet")
                    .font(.footnote)
                    .foregroundStyle(VantaTheme.textMuted)
                    .frame(height: 56, alignment: .center)
            }

            Text("View details")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VantaTheme.accent)
        }
        .padding(16)
        .background(VantaTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VantaTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Populated") {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        PatternCard(
            metric: .pulse,
            points: (0..<10).map { InsightDataPoint(date: Date().addingTimeInterval(Double($0) * -3600 * 6), value: Double.random(in: 64...78)) },
            insight: "Stable across the week"
        )
        .padding()
    }
}

#Preview("Empty") {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        PatternCard(metric: .breathing, points: [], insight: "")
            .padding()
    }
}
