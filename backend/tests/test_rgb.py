from pathlib import Path

import av
import cv2
import numpy as np
import pytest

from app.pipeline.rgb import _downscale, extract_rgb_trace

FIXTURE = Path(__file__).parent / "fixtures" / "face.jpg"


def _still_clip(path: Path, n_frames: int = 45, fps: int = 30) -> None:
    bgr = cv2.imread(str(FIXTURE))
    assert bgr is not None
    container = av.open(str(path), mode="w")
    stream = container.add_stream("mpeg4", rate=fps)
    stream.width = bgr.shape[1]
    stream.height = bgr.shape[0]
    stream.pix_fmt = "yuv420p"
    for _ in range(n_frames):
        vf = av.VideoFrame.from_ndarray(bgr, format="bgr24")
        for packet in stream.encode(vf):
            container.mux(packet)
    for packet in stream.encode():
        container.mux(packet)
    container.close()


def test_extract_rgb_trace_on_known_face_clip(tmp_path):
    clip = tmp_path / "face.mp4"
    _still_clip(clip)
    result = extract_rgb_trace(str(clip))
    assert result["n_face"] >= 30
    assert result["n_samples"] >= 30
    assert 15.0 <= result["fs"] <= 45.0
    assert result["duration_s"] > 0
    assert len(result["rgb_head"]) == 5
    assert len(result["rgb_head"][0]) == 3


def test_extract_rgb_trace_returns_arrays_for_pos(tmp_path):
    clip = tmp_path / "face.mp4"
    _still_clip(clip)
    result = extract_rgb_trace(str(clip))
    rgb = result["rgb"]
    t = result["t"]
    assert isinstance(rgb, np.ndarray)
    assert rgb.ndim == 2
    assert rgb.shape == (result["n_samples"], 3)
    assert isinstance(t, np.ndarray)
    assert t.shape == (result["n_samples"],)
    assert float(t[0]) == 0.0
    assert result["fs"] == pytest.approx((len(t) - 1) / float(t[-1]))
    assert len(result["rgb_regions"]) == 3
    for region in result["rgb_regions"]:
        assert region.shape == rgb.shape


def test_downscale_caps_long_side():
    big = np.zeros((1920, 1080, 3), dtype=np.uint8)
    out = _downscale(big)
    assert max(out.shape[0], out.shape[1]) == 480
    assert out.shape[2] == 3
