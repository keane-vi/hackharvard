import numpy as np

from .chrom import chrom
from .hr import heart_rate_bpm
from .pos import pos

WINDOW_S = 10.0
HOP_S = 2.0
AGREE_BPM = 10.0


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
                pos_bpm = heart_rate_bpm(pos(chunk, fs), fs)
                chrom_bpm = heart_rate_bpm(chrom(chunk, fs), fs)
            except ValueError:
                continue
            if abs(pos_bpm - chrom_bpm) <= AGREE_BPM:
                agreed.append(0.5 * (pos_bpm + chrom_bpm))
        if agreed:
            stable.append(float(np.median(agreed)))
    if not stable:
        return None
    return float(np.median(stable))
