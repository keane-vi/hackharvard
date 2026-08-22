import numpy as np
import pytest

from app.pipeline.pos import pos, pos_window_length


def test_pos_window_length_is_1_6_seconds():
    assert pos_window_length(30.0) == 48
    assert pos_window_length(20.0) == 32
    assert pos_window_length(25.0) == 40


def test_pos_pulse_has_one_sample_per_frame():
    fs = 30.0
    n = 120
    rgb = np.ones((n, 3), dtype=np.float64) * 100.0
    rgb[:, 1] += 2.0 * np.sin(2 * np.pi * 1.2 * np.arange(n) / fs)
    pulse = pos(rgb, fs)
    assert pulse.shape == (n,)
    assert np.isfinite(pulse).all()
    assert float(np.std(pulse)) > 0.0


def test_pos_rejects_clip_shorter_than_one_window():
    fs = 30.0
    rgb = np.ones((10, 3), dtype=np.float64)
    with pytest.raises(ValueError, match="too_short"):
        pos(rgb, fs)
