import numpy as np

from app.pipeline.quality import (
    MOTION_MAX,
    SNR_MIN,
    hr_quality_ok,
    motion_score,
    pulse_snr,
)


def _sine_pulse(bpm: float = 72.0, fs: float = 30.0, duration_s: float = 20.0):
    t = np.arange(int(duration_s * fs), dtype=np.float64) / fs
    return np.sin(2 * np.pi * (bpm / 60.0) * t), fs


def test_clean_pulse_passes_snr_gate():
    pulse, fs = _sine_pulse()
    snr = pulse_snr(pulse, fs)
    assert snr >= SNR_MIN
    assert hr_quality_ok(snr, motion=0.0)


def test_noise_fails_snr_gate():
    fs = 30.0
    noise = np.random.default_rng(0).normal(size=int(20 * fs))
    snr = pulse_snr(noise, fs)
    assert snr < SNR_MIN
    assert not hr_quality_ok(snr, motion=0.0)


def test_many_reused_frames_fails_motion_gate():
    motion = motion_score(n_reused=80, n_frames=100)
    assert motion > MOTION_MAX
    assert not hr_quality_ok(snr=100.0, motion=motion)
