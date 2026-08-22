import SwiftUI

struct HomeView: View {
    // Daily-mean values are nil until scan history persistence exists.
    // TODO: wire real daily-mean HR/HRV here once scans are persisted (see plan notes).
    private var meanBPM: Double? { nil }
    private var meanHRV: Double? { nil }

    @State private var showProfile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                dateSelector
                HealthScoreGaugeView(meanBPM: meanBPM)
                    .padding(.horizontal, 8)
                metricsRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(VantaTheme.background.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }

    private var header: some View {
        ZStack {
            Text("VANTA")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .tracking(2)
                .foregroundStyle(VantaTheme.textPrimary)

            HStack {
                Button {
                    showProfile = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(VantaTheme.textPrimary)
                }
                .accessibilityLabel("Open profile")
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dateSelector: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VantaTheme.textMuted)
            Text("TODAY")
                .font(.footnote.weight(.bold))
                .tracking(1)
                .foregroundStyle(VantaTheme.accent)
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VantaTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(Capsule().stroke(VantaTheme.border, lineWidth: 1))
    }

    private var metricsRow: some View {
        HStack(spacing: 14) {
            MetricCardView(
                systemImage: "heart",
                value: meanBPM.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "--",
                unit: "BPM",
                label: "Heart rate"
            )
            MetricCardView(
                systemImage: "waveform.path.ecg",
                value: meanHRV.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "--",
                unit: "ms",
                label: "HRV / PRV"
            )
        }
    }
}

#Preview {
    HomeView()
}

