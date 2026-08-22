import numpy as np

from .pos import HOP, pos_window_length

_EPS = 1e-12


def chrom(rgb: np.ndarray, fs: float) -> np.ndarray:
    """De Haan CHROM pulse, same 1.6s overlap-add windows as POS."""
    rgb = np.asarray(rgb, dtype=np.float64)
    if rgb.ndim != 2 or rgb.shape[1] != 3:
        raise ValueError("rgb must have shape (n, 3)")

    n = rgb.shape[0]
    window_len = pos_window_length(fs)
    if n < window_len:
        raise ValueError("too_short")

    pulse = np.zeros(n, dtype=np.float64)
    for start in range(0, n - window_len + 1, HOP):
        window = rgb[start : start + window_len]
        means = window.mean(axis=0)
        means = np.where(np.abs(means) < _EPS, 1.0, means)
        xn = window / means
        xs = 3.0 * xn[:, 0] - 2.0 * xn[:, 1]
        ys = 1.5 * xn[:, 0] + xn[:, 1] - 1.5 * xn[:, 2]
        std_x = float(np.std(xs))
        std_y = float(np.std(ys))
        if std_y < _EPS:
            window_pulse = xs
        else:
            window_pulse = xs - (std_x / std_y) * ys
        window_pulse = window_pulse - window_pulse.mean()
        pulse[start : start + window_len] += window_pulse

    return pulse
