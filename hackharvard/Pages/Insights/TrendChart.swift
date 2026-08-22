import SwiftUI
import Charts

/// Compact axis-free sparkline used inside a PatternCard.
struct TrendChart: View {
    let points: [InsightDataPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(VantaTheme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

#Preview {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        TrendChart(points: (0..<12).map {
            InsightDataPoint(date: Date().addingTimeInterval(Double($0) * -3600), value: Double.random(in: 62...78))
        })
        .frame(height: 60)
        .padding()
    }
}
