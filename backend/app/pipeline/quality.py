import numpy as np

from app.pipeline.hr import HR_BAND_HZ, bandpass_cardiac

SNR_MIN = 1.0
MOTION_MAX = 0.25
_PEAK_BINS = 3
_EPS = 1e-12


def pulse_snr(pulse: np.ndarray, fs: float) -> float:
    pulse = np.asarray(pulse, dtype=np.float64)
    filtered = bandpass_cardiac(pulse, fs)
    windowed = filtered * np.hanning(len(filtered))
    power = np.abs(np.fft.rfft(windowed)) ** 2
    freqs = np.fft.rfftfreq(len(windowed), d=1.0 / fs)
    band = (freqs >= HR_BAND_HZ[0]) & (freqs <= HR_BAND_HZ[1])
    band_power = power[band]
    if band_power.size < 8:
        return 0.0

    peak_i = int(np.argmax(band_power))
    lo = max(0, peak_i - _PEAK_BINS)
    hi = min(band_power.size, peak_i + _PEAK_BINS + 1)
    signal = float(np.sum(band_power[lo:hi]))
    noise = float(np.sum(band_power) - signal)
    if noise < _EPS:
        return float("inf") if signal > 0 else 0.0
    return signal / noise


def motion_score(n_reused: int, n_frames: int) -> float:
    if n_frames <= 0:
        return 1.0
    return n_reused / n_frames


def hr_quality_ok(snr: float, motion: float) -> bool:
    return snr >= SNR_MIN and motion <= MOTION_MAX
