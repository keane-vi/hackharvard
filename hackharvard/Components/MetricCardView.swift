import SwiftUI

/// Reusable dashboard metric card: outlined icon, value, and label.
struct MetricCardView: View {
    let systemImage: String
    let value: String
    let unit: String?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(VantaTheme.accent)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(VantaTheme.accent)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VantaTheme.textMuted)
                }
            }

            Text(label)
                .font(.subheadline)
                .foregroundStyle(VantaTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VantaTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VantaTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)\(unit.map { " \($0)" } ?? "")")
    }
}

#Preview {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        HStack(spacing: 14) {
            MetricCardView(systemImage: "heart", value: "--", unit: "BPM", label: "Heart rate")
            MetricCardView(systemImage: "waveform.path.ecg", value: "--", unit: "ms", label: "HRV / PRV")
        }
        .padding()
    }
}
