import Foundation

enum InsightTimeframe: String, CaseIterable, Identifiable {
    case week = "7 DAYS"
    case month = "30 DAYS"
    case year = "1 YEAR"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

struct InsightDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct InsightMetric: Hashable {
    let title: String
    let icon: String
    let unit: String
    let normalRange: ClosedRange<Double>
    let valueKeyPath: KeyPath<ScanRecord, Double?>

    // ClosedRange isn't Hashable; identity is unique per static instance, so hash/compare on title alone.
    static func == (lhs: InsightMetric, rhs: InsightMetric) -> Bool { lhs.title == rhs.title }
    func hash(into hasher: inout Hasher) { hasher.combine(title) }

    static let pulse = InsightMetric(
        title: "Pulse trend",
        icon: "heart",
        unit: "BPM",
        normalRange: 60...100,
        valueKeyPath: \ScanRecord.hrBpm
    )

    static let breathing = InsightMetric(
        title: "Breathing pattern",
        icon: "lungs",
        unit: "brpm",
        normalRange: 12...20,
        valueKeyPath: \ScanRecord.rrBrpm
    )
}

enum InsightMath {
    static func points(from scans: [ScanRecord], metric: InsightMetric, timeframe: InsightTimeframe) -> [InsightDataPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeframe.days, to: .now) ?? .distantPast
        return scans
            .filter { $0.date >= cutoff }
            .compactMap { scan in
                guard let value = scan[keyPath: metric.valueKeyPath] else { return nil }
                return InsightDataPoint(date: scan.date, value: value)
            }
            .sorted { $0.date < $1.date }
    }

    static func mean(_ points: [InsightDataPoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        return points.reduce(0) { $0 + $1.value } / Double(points.count)
    }

    static func range(_ points: [InsightDataPoint]) -> ClosedRange<Double>? {
        guard let min = points.map(\.value).min(), let max = points.map(\.value).max() else { return nil }
        return min...max
    }
}
