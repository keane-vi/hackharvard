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
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground))
        .presentationDetents([.medium, .large], selection: .constant(.large))
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(Color(.label))
                        .background(Color(.systemGray6), in: Circle())
                }
                .accessibilityLabel("Close scan result")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color.blue, lineWidth: 1.5))
                .accessibilityLabel("Scan successful")

            Text("Scan complete")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Color(.label))
            Text(hrvMs == nil ? "Here’s your heart rate." : "Here’s your heart rate and HRV.")
                .font(.title3)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    private var measurement: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bpm.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(.label))
                Text("BPM")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            Text("Heart rate")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
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
                        .foregroundStyle(Color(.label))
                    Text("ms")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                } else {
                    Text("Unavailable")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            Text("HRV (SDNN)")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
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
                        Color.blue.opacity(0.58).frame(width: width * lowFraction)
                        Color.green.opacity(0.58).frame(width: width * typicalFraction)
                        Color.orange.opacity(0.68)
                    }
                    .clipShape(Capsule())
                    .frame(height: 14)

                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color(.label), lineWidth: 2))
                            .overlay {
                                Text(bpm.formatted(.number.precision(.fractionLength(0))))
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(.label))
                            }
                        Rectangle().fill(Color(.label)).frame(width: 2, height: 26)
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
            .foregroundStyle(Color(.secondaryLabel))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate spectrum. Low, typical, and high ranges. Current value \(bpm.formatted(.number.precision(.fractionLength(0)))) BPM.")
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(status.title).font(.headline).foregroundStyle(status.color)
            Text(status.message)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(status.color.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title). \(status.message)")
        .accessibilityAddTraits(.isStaticText)
    }

    private var actions: some View {
        VStack(spacing: 14) {
            Button("Done") { dismiss() }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHint("Dismisses the scan result")

            Button("Scan again") {
                if let onScanAgain { onScanAgain() } else { dismiss() }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.blue)
            .frame(minHeight: 44)
        }
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
        case .below: .blue
        case .within: .green
        case .above: .orange
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
