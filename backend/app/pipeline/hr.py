import numpy as np
from scipy.signal import butter, find_peaks, sosfiltfilt

HR_BAND_HZ = (0.7, 4.0)
MAX_BIN_BPM = 0.5
HARMONIC_RATIO = 0.35
PEAK_AGREE_BPM = 12.0
REFRACTORY_S = 0.3
MIN_PEAK_IBIS = 7
_EPS = 1e-12


def fft_length(n: int, fs: float) -> int:
    min_nfft = int(np.ceil(60.0 * fs / MAX_BIN_BPM))
    nfft = max(int(n), min_nfft)
    return 1 << int(np.ceil(np.log2(nfft)))


def bandpass_cardiac(pulse: np.ndarray, fs: float) -> np.ndarray:
    pulse = np.asarray(pulse, dtype=np.float64)
    nyquist = 0.5 * fs
    low = HR_BAND_HZ[0] / nyquist
    high = min(HR_BAND_HZ[1] / nyquist, 0.99)
    sos = butter(3, [low, high], btype="band", output="sos")
    return sosfiltfilt(sos, pulse)


def _power_near(freqs: np.ndarray, mag: np.ndarray, target_hz: float, half_width_hz: float = 0.05) -> float:
    nearby = np.abs(freqs - target_hz) <= half_width_hz
    if not np.any(nearby):
        return 0.0
    return float(np.max(mag[nearby]))


def _peak_interval_bpm(filtered: np.ndarray, fs: float) -> float | None:
    """Median beat rate from peaks. Tie-breaker only; not used as the HR estimate."""
    distance = max(1, int(round(REFRACTORY_S * fs)))
    prominence = 0.1 * float(np.std(filtered))
    peaks, _ = find_peaks(filtered, distance=distance, prominence=max(prominence, _EPS))
    if peaks.size < MIN_PEAK_IBIS + 1:
        return None
    ibis_s = np.diff(peaks.astype(np.float64)) / float(fs)
    ibis_s = ibis_s[(ibis_s >= 0.3) & (ibis_s <= 1.5)]
    if ibis_s.size < MIN_PEAK_IBIS:
        return None
    return 60.0 / float(np.median(ibis_s))


def heart_rate_bpm(pulse: np.ndarray, fs: float) -> float:
    filtered = bandpass_cardiac(pulse, fs)
    windowed = filtered * np.hanning(len(filtered))
    nfft = fft_length(len(windowed), fs)
    spectrum = np.fft.rfft(windowed, n=nfft)
    mag = np.abs(spectrum)
    freqs = np.fft.rfftfreq(nfft, d=1.0 / fs)
    band = (freqs >= HR_BAND_HZ[0]) & (freqs <= HR_BAND_HZ[1])
    if not np.any(band):
        raise ValueError("hr_band_empty")
    band_freqs = freqs[band]
    band_mag = mag[band]
    peak_i = int(np.argmax(band_mag))
    raw_hz = float(band_freqs[peak_i])
    peak_mag = float(band_mag[peak_i])
    half_hz = raw_hz / 2.0
    would_fold = (
        half_hz >= HR_BAND_HZ[0]
        and _power_near(band_freqs, band_mag, half_hz) >= HARMONIC_RATIO * peak_mag
    )
    if would_fold:
        peak_hr = _peak_interval_bpm(filtered, fs)
        raw_bpm = raw_hz * 60.0
        # Exercise: beats match the high FFT peak, leftover f/2 is not the pulse.
        if peak_hr is not None and abs(peak_hr - raw_bpm) <= PEAK_AGREE_BPM:
            return raw_bpm
        raw_hz = half_hz
    return raw_hz * 60.0
