import numpy as np
import pytest

from app.pipeline.quality import (
    MOTION_MAX,
    SNR_MIN,
    TOO_MUCH_MOTION_MAX,
    hr_quality_ok,
    interval_consistency_ok,
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


def test_motion_score_counts_illumination_artifacts_too():
    without_artifacts = motion_score(n_reused=10, n_frames=100)
    with_artifacts = motion_score(n_reused=10, n_frames=100, n_artifact=15)
    assert without_artifacts == pytest.approx(0.10)
    assert with_artifacts == pytest.approx(0.25)


def test_heavily_corrupted_clip_exceeds_too_much_motion_threshold():
    motion = motion_score(n_reused=10, n_frames=100, n_artifact=45)
    assert motion > TOO_MUCH_MOTION_MAX


def test_interval_consistency_rejects_high_cv():
    even = np.full(20, 833.0)
    jumpy = np.array([700.0, 1050.0] * 12)
    assert interval_consistency_ok(even)
    assert not interval_consistency_ok(jumpy)
