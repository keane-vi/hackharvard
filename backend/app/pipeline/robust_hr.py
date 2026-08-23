from __future__ import annotations

import numpy as np

from .chrom import chrom
from .hr import heart_rate_bpm
from .pos import pos
from .quality import pulse_snr

WINDOW_S = 10.0
HOP_S = 2.0
AGREE_BPM = 10.0
# POS/CHROM agreeing on a value is not enough on its own: a strong shared
# artifact (motion, a lighting change) can make both methods confidently
# agree on the same wrong frequency, since they run on the same raw input.
# Require each method's own pulse to also look like a real, dominant-peak
# signal (not just mutually consistent noise) before trusting the window.
WINDOW_SNR_MIN = 1.0


def robust_heart_rate(trace: dict) -> float | None:
    fs = float(trace["fs"])
    rgb = np.asarray(trace["rgb"], dtype=np.float64)
    regions = [
        np.asarray(region, dtype=np.float64)
        for region in (trace.get("rgb_regions") or [])
        if np.asarray(region).shape == rgb.shape
    ]
    series = regions if regions else [rgb]
    n = rgb.shape[0]
    win = int(round(WINDOW_S * fs))
    hop = max(1, int(round(HOP_S * fs)))
    if n < win:
        return None

    stable = []
    for start in range(0, n - win + 1, hop):
        chunk_end = start + win
        agreed = []
        for region in series:
            chunk = region[start:chunk_end]
            try:
                pos_pulse = pos(chunk, fs)
                chrom_pulse = chrom(chunk, fs)
                pos_bpm = heart_rate_bpm(pos_pulse, fs)
                chrom_bpm = heart_rate_bpm(chrom_pulse, fs)
                pos_snr = pulse_snr(pos_pulse, fs)
                chrom_snr = pulse_snr(chrom_pulse, fs)
            except ValueError:
                continue
            if (
                abs(pos_bpm - chrom_bpm) <= AGREE_BPM
                and min(pos_snr, chrom_snr) >= WINDOW_SNR_MIN
            ):
                # Regions do not have equal signal quality. A forehead ROI can
                # contain hair/shadow while one cheek remains clean; taking a
                # median across regions lets a coherent low-frequency artifact
                # pull the estimate down. Keep the estimate and its weakest
                # method SNR so the best region can represent this window.
                agreed.append(
                    (
                        0.5 * (pos_bpm + chrom_bpm),
                        min(pos_snr, chrom_snr),
                    )
                )
        if agreed:
            best_bpm, _ = max(agreed, key=lambda candidate: candidate[1])
            stable.append(float(best_bpm))
    if not stable:
        return None
    return float(np.median(stable))
