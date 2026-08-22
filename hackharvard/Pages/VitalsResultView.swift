//
//  VitalsResultView.swift
//  hackharvard
//
//  Shows the backend's /v1/process response after a video finishes analyzing.
//

import SwiftUI

struct VitalsResultView: View {
    let result: VitalsResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    vital("Heart Rate", value: result.hr_bpm, unit: "bpm", quality: result.quality.hr)
                    vital("Respiration Rate", value: result.rr_brpm, unit: "br/min", quality: result.quality.rr)
                    vital("SpO2", value: result.spo2_pct, unit: "%", quality: result.quality.spo2)
                    vital("HRV (SDNN)", value: result.prv_sdnn_ms, unit: "ms", quality: result.quality.prv)

                    Text(result.meta.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                .padding(20)
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func vital(_ title: String, value: Double?, unit: String, quality: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let value {
                    Text(value.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 32, weight: .bold))
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unavailable")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VitalsResultView(result: VitalsResponse(
        hr_bpm: 72.3,
        prv_sdnn_ms: nil,
        prv_rmssd_ms: nil,
        rr_brpm: nil,
        spo2_pct: nil,
        quality: VitalsQuality(hr: "ok", prv: "unavailable", rr: "unavailable", spo2: "unavailable"),
        meta: VitalsMeta(duration_s: 12, fs: 30, disclaimer: "This is a product estimate, not a clinical diagnosis or a replacement for a medical device."),
        error: nil
    ))
}
