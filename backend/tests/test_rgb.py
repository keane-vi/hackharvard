from pathlib import Path

import av
import cv2
import numpy as np
import pytest

from app.pipeline.rgb import ARTIFACT_MAX_STREAK, _downscale, extract_rgb_trace

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


def _clip_with_illumination_burst(
    path: Path, n_frames: int = 120, fps: int = 30,
    burst_start: int = 60, burst_len: int = 6, burst_delta: int = 90,
) -> None:
    bgr = cv2.imread(str(FIXTURE))
    assert bgr is not None
    burst_bgr = np.clip(bgr.astype(np.int16) + burst_delta, 0, 255).astype(np.uint8)
    container = av.open(str(path), mode="w")
    stream = container.add_stream("mpeg4", rate=fps)
    stream.width = bgr.shape[1]
    stream.height = bgr.shape[0]
    stream.pix_fmt = "yuv420p"
    for i in range(n_frames):
        frame_img = burst_bgr if burst_start <= i < burst_start + burst_len else bgr
        vf = av.VideoFrame.from_ndarray(frame_img, format="bgr24")
        for packet in stream.encode(vf):
            container.mux(packet)
    for packet in stream.encode():
        container.mux(packet)
    container.close()


def test_extract_rgb_trace_rejects_illumination_burst(tmp_path):
    clip = tmp_path / "burst.mp4"
    _clip_with_illumination_burst(clip)
    result = extract_rgb_trace(str(clip))
    assert result["n_artifact"] > 0
    # the rejected burst samples should be replaced with the last good value,
    # not the brightened one, so the trace stays essentially flat throughout
    assert result["rgb"].std(axis=0).max() < 5.0


def test_extract_rgb_trace_reports_zero_artifacts_on_stable_clip(tmp_path):
    clip = tmp_path / "face.mp4"
    _still_clip(clip)
    result = extract_rgb_trace(str(clip))
    assert result["n_artifact"] == 0


def _clip_with_permanent_shift(
    path: Path, n_frames: int = 250, fps: int = 30,
    shift_start: int = 60, shift_delta: int = 90,
) -> None:
    bgr = cv2.imread(str(FIXTURE))
    assert bgr is not None
    shifted_bgr = np.clip(bgr.astype(np.int16) + shift_delta, 0, 255).astype(np.uint8)
    container = av.open(str(path), mode="w")
    stream = container.add_stream("mpeg4", rate=fps)
    stream.width = bgr.shape[1]
    stream.height = bgr.shape[0]
    stream.pix_fmt = "yuv420p"
    for i in range(n_frames):
        frame_img = shifted_bgr if i >= shift_start else bgr
        vf = av.VideoFrame.from_ndarray(frame_img, format="bgr24")
        for packet in stream.encode(vf):
            container.mux(packet)
    for packet in stream.encode():
        container.mux(packet)
    container.close()


def test_extract_rgb_trace_resyncs_after_sustained_shift(tmp_path):
    clip = tmp_path / "shift.mp4"
    _clip_with_permanent_shift(clip)
    result = extract_rgb_trace(str(clip))
    # A permanent brightness step should only cost the initial rejection
    # streak, not every frame after the shift - the detector must resync to
    # the new baseline rather than discarding the rest of the clip.
    assert 0 < result["n_artifact"] <= ARTIFACT_MAX_STREAK + 5


def test_downscale_caps_long_side():
    big = np.zeros((1920, 1080, 3), dtype=np.uint8)
    out = _downscale(big)
    assert max(out.shape[0], out.shape[1]) == 480
    assert out.shape[2] == 3
