import SwiftUI

struct TimeframePicker: View {
    @Binding var selection: InsightTimeframe

    var body: some View {
        HStack(spacing: 4) {
            ForEach(InsightTimeframe.allCases) { timeframe in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = timeframe }
                } label: {
                    Text(timeframe.rawValue)
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(selection == timeframe ? VantaTheme.background : VantaTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selection == timeframe ? VantaTheme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(VantaTheme.surface)
        .overlay(Capsule().stroke(VantaTheme.border, lineWidth: 1))
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        VantaTheme.background.ignoresSafeArea()
        TimeframePicker(selection: .constant(.week))
            .padding()
    }
}
