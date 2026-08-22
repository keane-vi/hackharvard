import numpy as np
from scipy.signal import butter, sosfiltfilt

HR_BAND_HZ = (0.7, 4.0)
MAX_BIN_BPM = 0.5


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
    peak_hz = float(band_freqs[peak_i])
    peak_mag = float(band_mag[peak_i])
    # rPPG often puts more energy in the 2nd harmonic; prefer f/2 when it is present.
    half_hz = peak_hz / 2.0
    if half_hz >= HR_BAND_HZ[0] and _power_near(band_freqs, band_mag, half_hz) >= 0.35 * peak_mag:
        peak_hz = half_hz
    return peak_hz * 60.0
