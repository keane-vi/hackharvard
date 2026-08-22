import SwiftUI

struct HeartRateThresholds {
    var displayedMinimum: Double = 40
    var lowUpperBound: Double = 60
    var typicalUpperBound: Double = 100
    var displayedMaximum: Double = 160

    var typicalRange: ClosedRange<Double> { lowUpperBound...typicalUpperBound }
}

struct VitalsResultView: View {
    let result: VitalsResponse
    var thresholds = HeartRateThresholds()
    var onScanAgain: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    private var bpm: Double { result.hr_bpm ?? 0 }
    private var hrvMs: Double? { result.prv_sdnn_ms }

    private var status: HeartRateStatus {
        if bpm < thresholds.typicalRange.lowerBound { return .below }
        if bpm > thresholds.typicalRange.upperBound { return .above }
        return .within
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 28)
                measurement.padding(.bottom, 16)
                hrvMeasurement.padding(.bottom, 28)
                spectrum.padding(.bottom, 24)
                statusPanel.padding(.bottom, 28)
                actions.padding(.bottom, 18)

                Text(result.meta.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(VantaTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(VantaTheme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(VantaTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(VantaTheme.textPrimary)
                        .background(VantaTheme.surface, in: Circle())
                        .overlay(Circle().stroke(VantaTheme.border, lineWidth: 1))
                }
                .accessibilityLabel("Close scan result")
            }
        }
        .toolbarBackground(VantaTheme.background, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(VantaTheme.accent)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(VantaTheme.accent, lineWidth: 1.5))
                .accessibilityLabel("Scan successful")

            Text("Scan complete")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(VantaTheme.textPrimary)
            Text(hrvMs == nil ? "Here’s your heart rate." : "Here’s your heart rate and HRV.")
                .font(.title3)
                .foregroundStyle(VantaTheme.textMuted)
        }
    }

    private var measurement: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bpm.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(VantaTheme.textPrimary)
                Text("BPM")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VantaTheme.textMuted)
            }
            Text("Heart rate")
                .font(.subheadline)
                .foregroundStyle(VantaTheme.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate, \(bpm.formatted(.number.precision(.fractionLength(0)))) beats per minute")
    }

    private var hrvMeasurement: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let hrvMs {
                    Text(hrvMs.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(VantaTheme.textPrimary)
                    Text("ms")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(VantaTheme.textMuted)
                } else {
                    Text("Unavailable")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(VantaTheme.textMuted)
                }
            }
            Text("HRV (SDNN)")
                .font(.subheadline)
                .foregroundStyle(VantaTheme.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            hrvMs.map { "HRV SDNN, \($0.formatted(.number.precision(.fractionLength(0...1)))) milliseconds" }
                ?? "HRV SDNN unavailable"
        )
    }

    private var spectrum: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let position = indicatorPosition(in: width)
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        VantaTheme.gaugeGradientStart.opacity(0.55).frame(width: width * lowFraction)
                        LinearGradient(colors: [VantaTheme.gaugeGradientStart, VantaTheme.gaugeGradientEnd], startPoint: .leading, endPoint: .trailing)
                            .frame(width: width * typicalFraction)
                        VantaTheme.highlight.opacity(0.85)
                    }
                    .clipShape(Capsule())
                    .frame(height: 14)

                    VStack(spacing: 4) {
                        Circle()
                            .fill(VantaTheme.background)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(VantaTheme.textPrimary, lineWidth: 2))
                            .overlay {
                                Text(bpm.formatted(.number.precision(.fractionLength(0))))
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundStyle(VantaTheme.textPrimary)
                            }
                        Rectangle().fill(VantaTheme.textPrimary).frame(width: 2, height: 26)
                    }
                    .frame(width: 24)
                    .offset(x: max(0, min(width - 24, position - 12)))
                    .accessibilityHidden(true)
                }
            }
            .frame(height: 52)

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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate spectrum. Low, typical, and high ranges. Current value \(bpm.formatted(.number.precision(.fractionLength(0)))) BPM.")
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(status.title).font(.headline).foregroundStyle(status.color)
            Text(status.message)
                .font(.subheadline)
                .foregroundStyle(VantaTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VantaTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VantaTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title). \(status.message)")
        .accessibilityAddTraits(.isStaticText)
    }

    private var actions: some View {
        Button("Done") {
            if let onScanAgain { onScanAgain() } else { dismiss() }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(VantaTheme.background)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(VantaTheme.accent, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHint("Dismisses the scan result")
    }

    private var lowFraction: CGFloat { fraction(from: thresholds.displayedMinimum, to: thresholds.lowUpperBound) }
    private var typicalFraction: CGFloat { fraction(from: thresholds.lowUpperBound, to: thresholds.typicalUpperBound) }

    private func fraction(from start: Double, to end: Double) -> CGFloat {
        guard thresholds.displayedMaximum > thresholds.displayedMinimum else { return 0 }
        return CGFloat(max(0, (end - start) / (thresholds.displayedMaximum - thresholds.displayedMinimum)))
    }

    private func indicatorPosition(in width: CGFloat) -> CGFloat {
        let span = thresholds.displayedMaximum - thresholds.displayedMinimum
        guard span > 0 else { return width / 2 }
        return CGFloat(max(0, min(1, (bpm - thresholds.displayedMinimum) / span))) * width
    }
}

private enum HeartRateStatus {
    case below, within, above

    var title: String {
        switch self {
        case .below: "Below your typical range"
        case .within: "Within your typical range"
        case .above: "Above your typical range"
        }
    }

    var message: String {
        switch self {
        case .below, .above: "Consider resting for a few minutes and checking again."
        case .within: "Your heart rate appears to be within the expected range."
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

struct VitalsResultView_Previews: PreviewProvider {
    static var previews: some View {
        VitalsResultView(result: VitalsResponse(
            hr_bpm: 118,
            prv_sdnn_ms: 38.0,
            prv_rmssd_ms: nil,
            rr_brpm: nil,
            spo2_pct: nil,
            quality: VitalsQuality(hr: "ok", prv: "ok", rr: "unavailable", spo2: "unavailable"),
            meta: VitalsMeta(duration_s: 40, fs: 30, disclaimer: "This is not a medical diagnosis."),
            error: nil
        ))
    }
}
