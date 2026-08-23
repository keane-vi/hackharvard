import SwiftUI
import Charts

struct InteractiveTrendChart: View {
    let metric: InsightMetric
    let points: [InsightDataPoint]

    @State private var selected: InsightDataPoint?

    var body: some View {
        Chart {
            RectangleMark(
                yStart: .value("Range low", metric.normalRange.lowerBound),
                yEnd: .value("Range high", metric.normalRange.upperBound)
            )
            .foregroundStyle(VantaTheme.accent.opacity(0.08))

            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(VantaTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(VantaTheme.accent.opacity(point.id == selected?.id ? 1 : 0))
                    .symbolSize(60)
            }

            if let selected {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(VantaTheme.textMuted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, spacing: 4) {
                        tooltip(for: selected)
                    }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(VantaTheme.border)
                AxisValueLabel().foregroundStyle(VantaTheme.textMuted)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(VantaTheme.border)
                AxisValueLabel().foregroundStyle(VantaTheme.textMuted)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame,
                                      let date: Date = proxy.value(atX: value.location.x - geo[plotFrame].origin.x) else { return }
                                selected = points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
                            }
                    )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: points.map(\.id))
    }

    private func tooltip(for point: InsightDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(VantaTheme.textMuted)
            Text("\(point.value.formatted(.number.precision(.fractionLength(0)))) \(metric.unit)")
                .font(.caption.weight(.bold))
                .foregroundStyle(VantaTheme.textPrimary)
        }
        .padding(8)
        .background(VantaTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VantaTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        InteractiveTrendChart(
            metric: .pulse,
            points: (0..<14).map { InsightDataPoint(date: Date().addingTimeInterval(Double($0) * -3600 * 12), value: Double.random(in: 62...82)) }
        )
        .frame(height: 240)
        .padding()
    }
}
