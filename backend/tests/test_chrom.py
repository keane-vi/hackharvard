import numpy as np
import pytest

from app.pipeline.chrom import chrom
from app.pipeline.hr import heart_rate_bpm
from app.pipeline.pos import pos


def test_chrom_pulse_has_one_sample_per_frame():
    fs = 30.0
    n = 120
    rgb = np.ones((n, 3), dtype=np.float64) * 100.0
    rgb[:, 1] += 2.0 * np.sin(2 * np.pi * 1.2 * np.arange(n) / fs)
    pulse = chrom(rgb, fs)
    assert pulse.shape == (n,)
    assert np.isfinite(pulse).all()
    assert float(np.std(pulse)) > 0.0


def test_chrom_rejects_clip_shorter_than_one_window():
    fs = 30.0
    rgb = np.ones((10, 3), dtype=np.float64)
    with pytest.raises(ValueError, match="too_short"):
        chrom(rgb, fs)


def test_chrom_and_pos_agree_on_known_pulse():
    fs = 30.0
    n = int(20 * fs)
    t = np.arange(n, dtype=np.float64) / fs
    rgb = np.ones((n, 3), dtype=np.float64) * 100.0
    rgb[:, 1] += 3.0 * np.sin(2 * np.pi * 1.2 * t)
    rgb[:, 0] += 1.0 * np.sin(2 * np.pi * 1.2 * t)
    pos_bpm = heart_rate_bpm(pos(rgb, fs), fs)
    chrom_bpm = heart_rate_bpm(chrom(rgb, fs), fs)
    assert chrom_bpm == pytest.approx(pos_bpm, abs=5.0)
    assert chrom_bpm == pytest.approx(72.0, abs=5.0)
