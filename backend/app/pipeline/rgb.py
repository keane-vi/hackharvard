import urllib.request
from pathlib import Path

import av
import cv2
import mediapipe as mp
import numpy as np
from scipy.signal import detrend

# MediaPipe Face Landmarker still uses the 468-point face mesh topology.
FOREHEAD = (10, 67, 69, 108, 151, 337, 299)
LEFT_CHEEK = (50, 101, 118, 205)
RIGHT_CHEEK = (280, 330, 347, 425)

SKIN_LOWER = np.array([0, 133, 77], dtype=np.uint8)
SKIN_UPPER = np.array([255, 173, 127], dtype=np.uint8)
BOX_HALF = 18

MODEL_PATH = Path(__file__).resolve().parent / "face_landmarker.task"
MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "face_landmarker/face_landmarker/float16/1/face_landmarker.task"
)


def _ensure_model() -> str:
    if not MODEL_PATH.exists() or MODEL_PATH.stat().st_size < 1000:
        urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
    return str(MODEL_PATH)


def _box_from_ids(landmarks, ids, w, h):
    xs = []
    ys = []
    for i in ids:
        lm = landmarks[i]
        xs.append(lm.x * w)
        ys.append(lm.y * h)
    if not xs:
        return None
    cx, cy = float(np.mean(xs)), float(np.mean(ys))
    x1 = int(max(0, cx - BOX_HALF))
    y1 = int(max(0, cy - BOX_HALF))
    x2 = int(min(w, cx + BOX_HALF))
    y2 = int(min(h, cy + BOX_HALF))
    if x2 <= x1 or y2 <= y1:
        return None
    return x1, y1, x2, y2


def _mean_rgb_in_box(bgr, box):
    x1, y1, x2, y2 = box
    patch = bgr[y1:y2, x1:x2]
    if patch.size == 0:
        return None
    ycrcb = cv2.cvtColor(patch, cv2.COLOR_BGR2YCrCb)
    mask = cv2.inRange(ycrcb, SKIN_LOWER, SKIN_UPPER)
    if int(np.count_nonzero(mask)) < 20:
        return None
    rgb = cv2.cvtColor(patch, cv2.COLOR_BGR2RGB)
    pixels = rgb[mask > 0]
    return pixels.mean(axis=0).astype(np.float64)


def extract_rgb_trace(video_path: str) -> dict:
    path = Path(video_path)
    times = []
    rgbs = []
    last_rgb = None
    n_frames = 0
    n_face = 0
    n_reused = 0
    last_ts = -1

    options = mp.tasks.vision.FaceLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=_ensure_model()),
        running_mode=mp.tasks.vision.RunningMode.VIDEO,
        num_faces=1,
        min_face_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    landmarker = mp.tasks.vision.FaceLandmarker.create_from_options(options)
    container = av.open(str(path))
    try:
        for frame in container.decode(video=0):
            n_frames += 1
            t = float(frame.time) if frame.time is not None else n_frames / 30.0
            timestamp_ms = int(round(t * 1000))
            if timestamp_ms <= last_ts:
                timestamp_ms = last_ts + 1
            last_ts = timestamp_ms

            bgr = frame.to_ndarray(format="bgr24")
            h, w = bgr.shape[:2]
            rgb_img = np.ascontiguousarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_img)
            result = landmarker.detect_for_video(mp_image, timestamp_ms)

            sample = None
            if result.face_landmarks:
                n_face += 1
                lms = result.face_landmarks[0]
                forehead = _box_from_ids(lms, FOREHEAD, w, h)
                if forehead is not None:
                    sample = _mean_rgb_in_box(bgr, forehead)
                if sample is None:
                    for ids in (LEFT_CHEEK, RIGHT_CHEEK):
                        cheek = _box_from_ids(lms, ids, w, h)
                        if cheek is None:
                            continue
                        sample = _mean_rgb_in_box(bgr, cheek)
                        if sample is not None:
                            break

            if sample is None:
                if last_rgb is None:
                    continue
                sample = last_rgb
                n_reused += 1

            last_rgb = sample
            times.append(t)
            rgbs.append(sample)
    finally:
        landmarker.close()
        container.close()

    if len(rgbs) < 30:
        raise ValueError("too_few_skin_samples")

    t = np.asarray(times, dtype=np.float64)
    t = t - t[0]
    rgb = np.asarray(rgbs, dtype=np.float64)
    duration = float(t[-1]) if t[-1] > 0 else len(t) / 30.0
    n = len(t)
    fs = (n - 1) / duration if duration > 0 else 30.0
    t_uniform = np.linspace(0.0, duration, n)
    resampled = np.column_stack(
        [np.interp(t_uniform, t, rgb[:, c]) for c in range(3)]
    )
    resampled = detrend(resampled, axis=0)

    return {
        "n_frames": n_frames,
        "n_samples": n,
        "n_face": n_face,
        "n_reused": n_reused,
        "duration_s": duration,
        "fs": fs,
        "t": t_uniform,
        "rgb": resampled,
        "rgb_mean": resampled.mean(axis=0).tolist(),
        "rgb_std": resampled.std(axis=0).tolist(),
        "rgb_head": resampled[:5].tolist(),
    }
