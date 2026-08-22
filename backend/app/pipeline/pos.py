import numpy as np

WINDOW_S = 1.6
HOP = 1
_EPS = 1e-12

# Wang et al. POS: project temporally-normalized RGB onto the plane
# orthogonal to the skin-tone direction.
_POS_PROJECT = np.array(
    [
        [0.0, 1.0, -1.0],
        [-2.0, 1.0, 1.0],
    ],
    dtype=np.float64,
)


def pos_window_length(fs: float) -> int:
    return int(round(WINDOW_S * fs))


def pos(rgb: np.ndarray, fs: float) -> np.ndarray:
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
        normalized = window / means
        projected = normalized @ _POS_PROJECT.T
        s1 = projected[:, 0]
        s2 = projected[:, 1]
        std1 = float(np.std(s1))
        std2 = float(np.std(s2))
        if std2 < _EPS:
            window_pulse = s1
        else:
            window_pulse = s1 + (std1 / std2) * s2
        window_pulse = window_pulse - window_pulse.mean()
        pulse[start : start + window_len] += window_pulse

    return pulse
