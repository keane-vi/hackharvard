import SwiftUI

struct InsightSummary: View {
    let metric: InsightMetric
    let points: [InsightDataPoint]

    var body: some View {
        HStack(spacing: 0) {
            stat("Average", InsightMath.mean(points).map(formatted))
            divider
            stat("Range", InsightMath.range(points).map { "\(formatted($0.lowerBound))–\(formatted($0.upperBound))" })
            divider
            stat("Scans", "\(points.count)")
        }
        .padding(16)
        .background(VantaTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VantaTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var divider: some View {
        Rectangle().fill(VantaTheme.border).frame(width: 1).padding(.vertical, 4)
    }

    private func stat(_ label: String, _ value: String?) -> some View {
        VStack(spacing: 4) {
            Text(value ?? "--")
                .font(.headline.weight(.bold))
                .foregroundStyle(VantaTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(VantaTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

#Preview {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        InsightSummary(
            metric: .pulse,
            points: (0..<10).map { InsightDataPoint(date: Date().addingTimeInterval(Double($0) * -3600), value: Double.random(in: 62...82)) }
        )
        .padding()
    }
}
