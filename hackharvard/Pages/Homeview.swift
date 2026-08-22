import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]
    @State private var selectedDate = Date()
    @State private var isShowingDatePicker = false

    private var selectedDayScans: [ScanRecord] {
        scans.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var meanBPM: Double? { mean(selectedDayScans.compactMap(\.hrBpm)) }
    private var meanHRV: Double? { mean(selectedDayScans.compactMap(\.prvSdnnMs)) }

    private var selectedDateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "TODAY"
        }
        return selectedDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

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
    }

    private var header: some View {
        Text("VANTA")
            .font(.system(.title2, design: .rounded).weight(.bold))
            .tracking(2)
            .foregroundStyle(VantaTheme.textPrimary)
            .frame(maxWidth: .infinity)
    }

    private var dateSelector: some View {
        Button {
            isShowingDatePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VantaTheme.textMuted)
                Text(selectedDateLabel)
                    .font(.footnote.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(VantaTheme.accent)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VantaTheme.textMuted)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(Capsule().stroke(VantaTheme.border, lineWidth: 1))
        .accessibilityLabel("Select date")
        .accessibilityValue(selectedDate.formatted(date: .complete, time: .omitted))
        .sheet(isPresented: $isShowingDatePicker) {
            NavigationStack {
                VStack(spacing: 24) {
                    DatePicker(
                        "Select a date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)

                    Spacer()
                }
                .padding(20)
                .navigationTitle("Choose date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
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
