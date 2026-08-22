import numpy as np
import pytest

from app.pipeline.hr import fft_length, heart_rate_bpm


def test_hr_fft_is_zero_padded_to_half_bpm_bins():
    n = 300
    fs = 30.0
    nfft = fft_length(n, fs)
    assert nfft > n
    assert 60.0 * fs / nfft <= 0.5


def test_heart_rate_recovers_known_sine():
    fs = 30.0
    duration_s = 20.0
    true_bpm = 72.0
    t = np.arange(int(duration_s * fs), dtype=np.float64) / fs
    pulse = np.sin(2 * np.pi * (true_bpm / 60.0) * t)
    bpm = heart_rate_bpm(pulse, fs)
    assert bpm == pytest.approx(true_bpm, abs=1.0)


def test_heart_rate_prefers_fundamental_over_stronger_harmonic():
    """Rest pulse at 72: FFT peak at 2f still folds back to 72."""
    fs = 30.0
    duration_s = 20.0
    true_bpm = 72.0
    t = np.arange(int(duration_s * fs), dtype=np.float64) / fs
    pulse = _gaussian_pulse_train(true_bpm, fs, duration_s)
    pulse = pulse + 0.6 * np.sin(2 * np.pi * (2.0 * true_bpm / 60.0) * t)
    bpm = heart_rate_bpm(pulse, fs)
    assert bpm == pytest.approx(true_bpm, abs=2.0)


def test_heart_rate_keeps_high_rate_when_no_fundamental():
    fs = 30.0
    duration_s = 20.0
    true_bpm = 144.0
    t = np.arange(int(duration_s * fs), dtype=np.float64) / fs
    pulse = np.sin(2 * np.pi * (true_bpm / 60.0) * t)
    bpm = heart_rate_bpm(pulse, fs)
    assert bpm == pytest.approx(true_bpm, abs=1.0)


def _gaussian_pulse_train(true_bpm: float, fs: float = 30.0, duration_s: float = 20.0) -> np.ndarray:
    n = int(duration_s * fs)
    t = np.arange(n, dtype=np.float64) / fs
    ibi = 60.0 / true_bpm
    pulse = np.zeros(n)
    tt = 0.4
    while tt < duration_s - 0.3:
        pulse += np.exp(-0.5 * ((t - tt) / 0.08) ** 2)
        tt += ibi
    return pulse


def test_heart_rate_keeps_exercise_rate_when_half_has_leftover_energy():
    """True 144 bpm with leftover 72 must not fold to resting 72."""
    fs = 30.0
    duration_s = 20.0
    t = np.arange(int(duration_s * fs), dtype=np.float64) / fs
    pulse = np.sin(2 * np.pi * (144.0 / 60.0) * t)
    pulse = pulse + 0.40 * np.sin(2 * np.pi * (72.0 / 60.0) * t)
    bpm = heart_rate_bpm(pulse, fs)
    assert bpm == pytest.approx(144.0, abs=3.0)


def test_heart_rate_recovers_pulse_train_130_and_160():
    assert heart_rate_bpm(_gaussian_pulse_train(130.0), 30.0) == pytest.approx(130.0, abs=3.0)
    assert heart_rate_bpm(_gaussian_pulse_train(160.0), 30.0) == pytest.approx(160.0, abs=3.0)
