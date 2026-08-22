import numpy as np
import pytest

from app.pipeline.robust_hr import robust_heart_rate


def _pulse_trace(duration_s=20.0, fs=30.0, bpm=72.0, n_regions=3):
    n = int(duration_s * fs)
    t = np.arange(n, dtype=np.float64) / fs
    wave = np.sin(2 * np.pi * (bpm / 60.0) * t)
    rgb = np.ones((n, 3), dtype=np.float64) * 100.0
    rgb[:, 1] += 3.0 * wave
    rgb[:, 0] += 1.0 * wave
    regions = [rgb.copy() for _ in range(n_regions)]
    return {
        "rgb": rgb,
        "rgb_regions": regions,
        "fs": fs,
        "duration_s": duration_s,
        "n_frames": n,
        "n_reused": 0,
    }


def test_robust_hr_returns_none_when_clip_shorter_than_one_window():
    trace = _pulse_trace(duration_s=4.0)
    assert robust_heart_rate(trace) is None


def test_robust_hr_median_recovers_known_rate():
    trace = _pulse_trace(duration_s=20.0, bpm=72.0)
    bpm = robust_heart_rate(trace)
    assert bpm is not None
    assert bpm == pytest.approx(72.0, abs=3.0)


def test_robust_hr_median_prefers_stable_rate_over_late_outlier():
    fs = 30.0
    duration_s = 30.0
    n = int(duration_s * fs)
    t = np.arange(n, dtype=np.float64) / fs
    rgb = np.ones((n, 3), dtype=np.float64) * 100.0
    rgb[:, 1] += 3.0 * np.sin(2 * np.pi * 1.2 * t)
    rgb[:, 0] += 1.0 * np.sin(2 * np.pi * 1.2 * t)
    late = t >= 22.0
    rgb[late, 1] = 100.0 + 3.0 * np.sin(2 * np.pi * 2.5 * t[late])
    rgb[late, 0] = 100.0 + 1.0 * np.sin(2 * np.pi * 2.5 * t[late])
    trace = {
        "rgb": rgb,
        "rgb_regions": [rgb.copy() for _ in range(3)],
        "fs": fs,
        "duration_s": duration_s,
        "n_frames": n,
        "n_reused": 0,
    }
    bpm = robust_heart_rate(trace)
    assert bpm is not None
    assert bpm == pytest.approx(72.0, abs=5.0)
