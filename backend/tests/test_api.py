from unittest.mock import patch

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


def test_process_stays_mocked():
    response = client.post(
        "/v1/process",
        files={"video": ("clip.mp4", b"fake", "video/mp4")},
    )
    body = response.json()
    assert response.status_code == 200
    assert body["hr_bpm"] == 72.0
    assert body["prv_sdnn_ms"] is None
    assert body["quality"]["hr"] == "ok"
    assert body["quality"]["prv"] == "unavailable"
    assert body["meta"]["duration_s"] is None
    assert body["meta"]["fs"] is None
    assert body["error"] is None


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
