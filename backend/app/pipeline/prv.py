import numpy as np
from scipy.interpolate import CubicSpline
from scipy.signal import find_peaks

from .hr import bandpass_cardiac
from .quality import interval_consistency_ok

TARGET_FS = 250.0
MIN_DURATION_S = 10.0
MIN_IBIS = 8
REFRACTORY_S = 0.3
IBI_MIN_MS = 300.0
IBI_MAX_MS = 1500.0
MEDIAN_DEV = 0.35


def upsample_pulse(pulse: np.ndarray, fs: float, target_fs: float = TARGET_FS):
    pulse = np.asarray(pulse, dtype=np.float64)
    n = pulse.shape[0]
    if n < 4:
        raise ValueError("too_short")
    duration = (n - 1) / float(fs)
    t = np.linspace(0.0, duration, n)
    n_up = int(round(duration * target_fs)) + 1
    t_up = np.linspace(0.0, duration, n_up)
    spline = CubicSpline(t, pulse)
    return t_up, spline(t_up)


def _clean_ibis_ms(ibis_ms: np.ndarray) -> np.ndarray:
    ibis = np.asarray(ibis_ms, dtype=np.float64)
    ibis = ibis[(ibis >= IBI_MIN_MS) & (ibis <= IBI_MAX_MS)]
    if ibis.size < 2:
        return ibis
    med = float(np.median(ibis))
    if med <= 0:
        return ibis[:0]
    return ibis[np.abs(ibis - med) <= MEDIAN_DEV * med]


def _empty_prv(peak_times: np.ndarray | None = None) -> dict:
    return {
        "sdnn_ms": None,
        "rmssd_ms": None,
        "ok": False,
        "peak_times_s": np.asarray([] if peak_times is None else peak_times, dtype=np.float64),
    }


def estimate_prv(pulse: np.ndarray, fs: float) -> dict:
    pulse = np.asarray(pulse, dtype=np.float64)
    n = pulse.shape[0]
    duration = (n - 1) / float(fs) if n > 1 else 0.0
    if duration < MIN_DURATION_S:
        return _empty_prv()

    filtered = bandpass_cardiac(pulse, fs)
    t_up, pulse_up = upsample_pulse(filtered, fs, TARGET_FS)
    fs_up = (len(pulse_up) - 1) / float(t_up[-1] - t_up[0]) if t_up[-1] > t_up[0] else TARGET_FS
    distance = max(1, int(round(REFRACTORY_S * fs_up)))
    prominence = 0.1 * float(np.std(pulse_up))
    peaks, _ = find_peaks(pulse_up, distance=distance, prominence=max(prominence, 1e-9))
    peak_times = t_up[peaks]
    if peak_times.size < MIN_IBIS + 1:
        return _empty_prv(peak_times)

    ibis_ms = _clean_ibis_ms(np.diff(peak_times) * 1000.0)
    if ibis_ms.size < MIN_IBIS:
        return _empty_prv(peak_times)

    sdnn = float(np.std(ibis_ms, ddof=1))
    rmssd = None
    if interval_consistency_ok(ibis_ms):
        diffs = np.diff(ibis_ms)
        rmssd = float(np.sqrt(np.mean(diffs * diffs)))
    return {
        "sdnn_ms": sdnn,
        "rmssd_ms": rmssd,
        "ok": True,
        "peak_times_s": peak_times,
    }
