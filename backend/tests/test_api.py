from unittest.mock import patch

import numpy as np
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

MOCK_TRACE = {
    "n_frames": 90,
    "n_samples": 90,
    "n_face": 88,
    "n_reused": 2,
    "duration_s": 3.0,
    "fs": 30.0,
    "rgb_mean": [0.0, 0.0, 0.0],
    "rgb_std": [1.0, 1.0, 1.0],
    "rgb_head": [[0.1, 0.2, 0.3]],
}

PROCESS_TRACE = {
    "n_frames": 120,
    "n_samples": 120,
    "n_face": 118,
    "n_reused": 2,
    "duration_s": 4.0,
    "fs": 30.0,
    "rgb": np.ones((120, 3), dtype=np.float64),
}


def _post_video():
    return client.post(
        "/v1/process",
        files={"video": ("clip.mp4", b"fake", "video/mp4")},
    )


def test_process_returns_measured_hr_when_quality_ok():
    with (
        patch("app.pipeline.estimate.extract_rgb_trace", return_value=PROCESS_TRACE),
        patch("app.pipeline.estimate.pos", return_value=np.ones(120)),
        patch("app.pipeline.estimate.pulse_snr", return_value=10.0),
        patch("app.pipeline.estimate.motion_score", return_value=0.01),
        patch("app.pipeline.estimate.hr_quality_ok", return_value=True),
        patch("app.pipeline.estimate.heart_rate_bpm", return_value=81.5),
    ):
        response = _post_video()
    body = response.json()
    assert response.status_code == 200
    assert body["hr_bpm"] == 81.5
    assert body["quality"]["hr"] == "ok"
    assert body["prv_sdnn_ms"] is None
    assert body["rr_brpm"] is None
    assert body["spo2_pct"] is None
    assert body["quality"]["prv"] == "unavailable"
    assert body["meta"]["duration_s"] == 4.0
    assert body["meta"]["fs"] == 30.0
    assert body["error"] is None


def test_process_marks_hr_unavailable_when_quality_fails():
    with (
        patch("app.pipeline.estimate.extract_rgb_trace", return_value=PROCESS_TRACE),
        patch("app.pipeline.estimate.pos", return_value=np.ones(120)),
        patch("app.pipeline.estimate.pulse_snr", return_value=0.1),
        patch("app.pipeline.estimate.motion_score", return_value=0.8),
        patch("app.pipeline.estimate.hr_quality_ok", return_value=False),
        patch("app.pipeline.estimate.heart_rate_bpm", return_value=81.5),
    ):
        response = _post_video()
    body = response.json()
    assert response.status_code == 200
    assert body["hr_bpm"] == 81.5
    assert body["quality"]["hr"] == "unavailable"
    assert body["error"] is None


def test_process_quality_ok_when_windowed_hr_agrees():
    with (
        patch("app.pipeline.estimate.extract_rgb_trace", return_value=PROCESS_TRACE),
        patch("app.pipeline.estimate.pos", return_value=np.ones(120)),
        patch("app.pipeline.estimate.pulse_snr", return_value=0.1),
        patch("app.pipeline.estimate.motion_score", return_value=0.8),
        patch("app.pipeline.estimate.hr_quality_ok", return_value=False),
        patch("app.pipeline.estimate.robust_heart_rate", return_value=73.8),
        patch("app.pipeline.estimate.heart_rate_bpm", return_value=81.5),
    ):
        response = _post_video()
    body = response.json()
    assert response.status_code == 200
    assert body["hr_bpm"] == 73.8
    assert body["quality"]["hr"] == "ok"
    assert body["error"] is None


def test_process_too_few_skin_samples_is_no_face():
    with patch(
        "app.pipeline.estimate.extract_rgb_trace",
        side_effect=ValueError("too_few_skin_samples"),
    ):
        response = _post_video()
    body = response.json()
    assert response.status_code == 400
    assert body["error"] == "no_face"
    assert "message" in body


def test_debug_rgb_route_exists():
    response = client.post(
        "/debug/rgb",
        files={"video": ("clip.mp4", b"fake", "video/mp4")},
    )
    assert response.status_code != 404


def test_debug_rgb_returns_extractor_payload():
    with patch("app.main.extract_rgb_trace", return_value=MOCK_TRACE):
        response = client.post(
            "/debug/rgb",
            files={"video": ("clip.mp4", b"fake", "video/mp4")},
        )
    body = response.json()
    assert response.status_code == 200
    assert body["fs"] == 30.0
    assert body["n_samples"] == 90
    assert body["rgb_head"] == [[0.1, 0.2, 0.3]]
