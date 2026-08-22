import SwiftUI

/// Semicircular heart-rate spectrum gauge. `meanBPM` is nil until daily-mean
/// aggregation exists (see plan reminder), in which case the gauge renders an
/// empty/placeholder state. Reuses `HeartRateThresholds` from VitalsResultView.swift.
struct HealthScoreGaugeView: View {
    var meanBPM: Double?
    var thresholds = HeartRateThresholds()

    private var status: GaugeStatus? {
        guard let meanBPM else { return nil }
        if meanBPM < thresholds.typicalRange.lowerBound { return .below }
        if meanBPM > thresholds.typicalRange.upperBound { return .above }
        return .within
    }

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geometry in
                let size = geometry.size
                ZStack {
                    arc(fraction: 1, in: size)
                        .stroke(VantaTheme.surface, style: StrokeStyle(lineWidth: 18, lineCap: .round))

                    arc(fraction: lowFraction, in: size)
                        .stroke(VantaTheme.gaugeGradientStart.opacity(0.55), style: StrokeStyle(lineWidth: 18, lineCap: .round))

                    arcSegment(fromFraction: lowFraction, toFraction: lowFraction + typicalFraction, in: size)
                        .stroke(
                            LinearGradient(
                                colors: [VantaTheme.gaugeGradientStart, VantaTheme.gaugeGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )

                    arcSegment(fromFraction: lowFraction + typicalFraction, toFraction: 1, in: size)
                        .stroke(VantaTheme.highlight.opacity(0.85), style: StrokeStyle(lineWidth: 18, lineCap: .round))

                    if let meanBPM {
                        indicator(for: meanBPM, in: size)
                    }
                }
            }
            .frame(height: 190)
            .padding(.horizontal, 8)

            HStack {
                Text("\(Int(thresholds.displayedMinimum))")
                Spacer()
                Text("\(Int(thresholds.lowUpperBound))")
                Spacer()
                Text("\(Int(thresholds.typicalUpperBound))")
                Spacer()
                Text("\(Int(thresholds.displayedMaximum))")
            }
            .font(.caption)
            .foregroundStyle(VantaTheme.textMuted)
            .padding(.horizontal, 8)

            VStack(spacing: 6) {
                if let meanBPM {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(meanBPM.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(VantaTheme.textPrimary)
                        Text("BPM")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(VantaTheme.textMuted)
                    }
                    Text(status?.title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(status?.color ?? VantaTheme.accent)
                } else {
                    Text("--")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(VantaTheme.textMuted)
                    Text("No scans yet today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VantaTheme.textMuted)
                }
            }
        }
    }

    // Upward-opening semicircle anchored to the bottom-center of the actual
    // GeometryReader size, so the arc always fits its frame exactly.
    private func arc(fraction: CGFloat, in size: CGSize) -> Path {
        arcSegment(fromFraction: 0, toFraction: fraction, in: size)
    }

    private func arcSegment(fromFraction: CGFloat, toFraction: CGFloat, in size: CGSize) -> Path {
        Path { path in
            let lineWidth: CGFloat = 18
            let radius = min(size.width / 2, size.height) - lineWidth / 2
            let center = CGPoint(x: size.width / 2, y: size.height)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(180 + 180 * Double(fromFraction)),
                endAngle: .degrees(180 + 180 * Double(toFraction)),
                clockwise: false
            )
        }
    }

    // Mirrors VitalsResultView's low/typical/high spectrum split so the
    // dashboard gauge reads consistently with the scan-complete sheet.
    private var lowFraction: CGFloat { fraction(from: thresholds.displayedMinimum, to: thresholds.lowUpperBound) }
    private var typicalFraction: CGFloat { fraction(from: thresholds.lowUpperBound, to: thresholds.typicalUpperBound) }

    private func fraction(from start: Double, to end: Double) -> CGFloat {
        guard thresholds.displayedMaximum > thresholds.displayedMinimum else { return 0 }
        return CGFloat(max(0, (end - start) / (thresholds.displayedMaximum - thresholds.displayedMinimum)))
    }

    private func indicator(for bpm: Double, in size: CGSize) -> some View {
        let lineWidth: CGFloat = 18
        let radius = min(size.width / 2, size.height) - lineWidth / 2
        let center = CGPoint(x: size.width / 2, y: size.height)
        let span = thresholds.displayedMaximum - thresholds.displayedMinimum
        let fraction = span > 0 ? max(0, min(1, (bpm - thresholds.displayedMinimum) / span)) : 0
        let angle = Angle.degrees(180 + 180 * fraction)
        let x = center.x + radius * CGFloat(cos(angle.radians))
        let y = center.y + radius * CGFloat(sin(angle.radians))

        return Circle()
            .fill(VantaTheme.background)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(VantaTheme.textPrimary, lineWidth: 2))
            .position(x: x, y: y)
    }
}

private enum GaugeStatus {
    case below, within, above

    var title: String {
        switch self {
        case .below: "Below range"
        case .within: "Within range"
        case .above: "Needs attention"
        }
    }

    var color: Color {
        switch self {
        case .below: VantaTheme.gaugeGradientStart
        case .within: VantaTheme.accent
        case .above: VantaTheme.highlight
        }
    }
}

#Preview {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        HealthScoreGaugeView(meanBPM: 74)
            .padding()
    }
}
