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
    fs = 30.0
    duration_s = 20.0
    true_bpm = 72.0
    t = np.arange(int(duration_s * fs), dtype=np.float64) / fs
    fundamental = np.sin(2 * np.pi * (true_bpm / 60.0) * t)
    harmonic = 1.8 * np.sin(2 * np.pi * (2.0 * true_bpm / 60.0) * t)
    bpm = heart_rate_bpm(fundamental + harmonic, fs)
    assert bpm == pytest.approx(true_bpm, abs=2.0)


def test_heart_rate_keeps_high_rate_when_no_fundamental():
    fs = 30.0
    duration_s = 20.0
    true_bpm = 144.0
    t = np.arange(int(duration_s * fs), dtype=np.float64) / fs
    pulse = np.sin(2 * np.pi * (true_bpm / 60.0) * t)
    bpm = heart_rate_bpm(pulse, fs)
    assert bpm == pytest.approx(true_bpm, abs=1.0)
