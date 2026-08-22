import numpy as np
import pytest
from scipy.signal import find_peaks

from app.pipeline.prv import TARGET_FS, estimate_prv, upsample_pulse

CAMERA_FS = 30.0
TRUE_BPM = 72.0
MEAN_IBI_S = 60.0 / TRUE_BPM


def _peak_times(duration_s: float = 40.0, jitter_s: float = 0.04) -> np.ndarray:
    times = []
    t = 0.55
    k = 0
    while t < duration_s - 0.8:
        times.append(t)
        # Off the 30 Hz grid: 0.55 + k*0.833... is not k/30.
        t += MEAN_IBI_S + jitter_s * np.sin(2.0 * np.pi * k / 11.0)
        k += 1
    return np.asarray(times, dtype=np.float64)


def _gaussian_pulse(t: np.ndarray, peak_times: np.ndarray, width_s: float = 0.08) -> np.ndarray:
    pulse = np.zeros_like(t, dtype=np.float64)
    for pt in peak_times:
        pulse += np.exp(-0.5 * ((t - pt) / width_s) ** 2)
    return pulse


def _camera_pulse(peak_times: np.ndarray, duration_s: float = 40.0):
    n = int(round(duration_s * CAMERA_FS))
    t = np.arange(n, dtype=np.float64) / CAMERA_FS
    return t, _gaussian_pulse(t, peak_times)


def test_prv_upsample_is_250_hz_not_camera_rate():
    duration_s = 4.0
    t = np.arange(int(duration_s * CAMERA_FS), dtype=np.float64) / CAMERA_FS
    pulse = np.sin(2 * np.pi * (TRUE_BPM / 60.0) * t)
    t_up, pulse_up = upsample_pulse(pulse, CAMERA_FS)
    duration = float(t[-1] - t[0])
    fs_up = (len(pulse_up) - 1) / duration
    assert fs_up == pytest.approx(TARGET_FS, abs=1.0)
    assert len(pulse_up) > len(pulse) * 7


def _median_match_err(found: np.ndarray, true: np.ndarray) -> float:
    interior = true[2:-2]
    return float(np.median([np.min(np.abs(found - pt)) for pt in interior]))


def test_prv_does_not_peak_pick_on_30hz_series():
    peak_times = _peak_times()
    t, pulse = _camera_pulse(peak_times)
    result = estimate_prv(pulse, CAMERA_FS)
    assert result["ok"] is True

    min_dist_30 = max(1, int(round(0.3 * CAMERA_FS)))
    peaks_30, _ = find_peaks(pulse, distance=min_dist_30)
    times_30 = t[peaks_30]
    recovered = result["peak_times_s"]
    err_ours = _median_match_err(recovered, peak_times)
    err_30 = _median_match_err(times_30, peak_times)
    assert err_ours < err_30
    assert err_ours < (0.5 / CAMERA_FS)


def test_prv_recovers_known_sdnn_from_30hz_pulse():
    peak_times = _peak_times()
    ibis_ms = np.diff(peak_times) * 1000.0
    true_sdnn = float(np.std(ibis_ms, ddof=1))
    _, pulse = _camera_pulse(peak_times)
    result = estimate_prv(pulse, CAMERA_FS)
    assert result["ok"] is True
    assert result["sdnn_ms"] == pytest.approx(true_sdnn, rel=0.25, abs=8.0)
    assert result["rmssd_ms"] is not None


def test_prv_unavailable_when_clip_too_short():
    t = np.arange(int(8.0 * CAMERA_FS), dtype=np.float64) / CAMERA_FS
    pulse = np.sin(2 * np.pi * (TRUE_BPM / 60.0) * t)
    result = estimate_prv(pulse, CAMERA_FS)
    assert result["ok"] is False
    assert result["sdnn_ms"] is None
    assert result["rmssd_ms"] is None


def test_prv_returns_sdnn_on_12s_phone_clip():
    """Typical judge/demo recordings are ~10–15 s, not 30–60 s."""
    peak_times = _peak_times(duration_s=12.0)
    _, pulse = _camera_pulse(peak_times, duration_s=12.0)
    result = estimate_prv(pulse, CAMERA_FS)
    assert result["ok"] is True
    assert result["sdnn_ms"] is not None
    assert result["sdnn_ms"] > 0


def test_prv_returns_sdnn_on_pos_like_sine():
    t = np.arange(int(12.0 * CAMERA_FS), dtype=np.float64) / CAMERA_FS
    pulse = np.sin(2 * np.pi * (TRUE_BPM / 60.0) * t)
    pulse += 0.15 * np.random.default_rng(0).normal(size=pulse.size)
    result = estimate_prv(pulse, CAMERA_FS)
    assert result["ok"] is True
    assert result["sdnn_ms"] is not None


def test_rmssd_omitted_when_interval_gate_fails(monkeypatch):
    peak_times = _peak_times()
    _, pulse = _camera_pulse(peak_times)
    monkeypatch.setattr("app.pipeline.prv.interval_consistency_ok", lambda _ibis: False)
    result = estimate_prv(pulse, CAMERA_FS)
    assert result["ok"] is True
    assert result["sdnn_ms"] is not None
    assert result["rmssd_ms"] is None
