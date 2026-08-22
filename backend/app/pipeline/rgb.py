import urllib.request
from pathlib import Path

import av
import cv2
import mediapipe as mp
import numpy as np
from scipy.signal import detrend

# 468-point Face Mesh topology (same IDs on solutions FaceMesh and Tasks Face Landmarker).
FOREHEAD = (10, 67, 69, 108, 151, 337, 299)
LEFT_CHEEK = (50, 101, 118, 205)
RIGHT_CHEEK = (280, 330, 347, 425)

SKIN_LOWER = np.array([0, 133, 77], dtype=np.uint8)
SKIN_UPPER = np.array([255, 173, 127], dtype=np.uint8)
BOX_HALF = 18
MAX_SIDE = 480

# Illumination-jump rejection: a sudden global brightness/white-balance change
# (auto-exposure hunting, a light flicking on) moves R, G, and B together by an
# amount far larger than any real cardiac-driven fluctuation. Flag samples that
# jump too far from a short rolling robust baseline and treat them like a
# dropped frame (reuse the last good sample) instead of letting them dominate
# the POS pulse.
ARTIFACT_HISTORY = 90
ARTIFACT_MIN_HISTORY = 10
ARTIFACT_Z = 6.0
ARTIFACT_MAD_FLOOR = 1.0
ARTIFACT_MIN_ABS_DELTA = 8.0
# A rejection streak longer than this (~3s at 30fps) means the "artifact" is
# actually a sustained lighting change, not a transient - stop rejecting and
# resync the baseline instead of discarding the rest of the clip.
ARTIFACT_MAX_STREAK = 90


def _downscale(bgr: np.ndarray) -> np.ndarray:
    h, w = bgr.shape[:2]
    long_side = max(h, w)
    if long_side <= MAX_SIDE:
        return bgr
    scale = MAX_SIDE / long_side
    new_w = max(1, int(round(w * scale)))
    new_h = max(1, int(round(h * scale)))
    return cv2.resize(bgr, (new_w, new_h), interpolation=cv2.INTER_AREA)

MODEL_PATH = Path(__file__).resolve().parent / "face_landmarker.task"
MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "face_landmarker/face_landmarker/float16/1/face_landmarker.task"
)


def _ensure_model() -> str:
    if not MODEL_PATH.exists() or MODEL_PATH.stat().st_size < 1000:
        urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
    return str(MODEL_PATH)


def _has_legacy_face_mesh() -> bool:
    solutions = getattr(mp, "solutions", None)
    return solutions is not None and hasattr(solutions, "face_mesh")


class _FaceTracker:
    """0.10.21 uses Face Mesh; 0.10.30+/1.0 on Py3.14 only expose Face Landmarker."""

    def __init__(self):
        self._mesh = None
        self._landmarker = None
        self._last_ts = -1
        if _has_legacy_face_mesh():
            face_mesh = getattr(mp, "solutions").face_mesh
            self._mesh = face_mesh.FaceMesh(
                static_image_mode=False,
                max_num_faces=1,
                refine_landmarks=False,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5,
            )
            return
        options = mp.tasks.vision.FaceLandmarkerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=_ensure_model()),
            running_mode=mp.tasks.vision.RunningMode.VIDEO,
            num_faces=1,
            min_face_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self._landmarker = mp.tasks.vision.FaceLandmarker.create_from_options(options)

    def landmarks(self, rgb_img, t: float):
        if self._mesh is not None:
            result = self._mesh.process(rgb_img)
            if not result.multi_face_landmarks:
                return None
            return result.multi_face_landmarks[0].landmark

        timestamp_ms = int(round(t * 1000))
        if timestamp_ms <= self._last_ts:
            timestamp_ms = self._last_ts + 1
        self._last_ts = timestamp_ms
        mp_image = mp.Image(
            image_format=mp.ImageFormat.SRGB,
            data=np.ascontiguousarray(rgb_img),
        )
        if self._landmarker is None:
            return None
        result = self._landmarker.detect_for_video(mp_image, timestamp_ms)
        if not result.face_landmarks:
            return None
        return result.face_landmarks[0]

    def close(self):
        if self._mesh is not None:
            self._mesh.close()
        if self._landmarker is not None:
            self._landmarker.close()


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


def _is_illumination_artifact(sample: np.ndarray, history: list) -> bool:
    if len(history) < ARTIFACT_MIN_HISTORY:
        return False
    hist = np.asarray(history, dtype=np.float64)
    med = np.median(hist, axis=0)
    deviation = np.abs(sample - med)
    mad = np.median(np.abs(hist - med), axis=0)
    # Floor MAD at a realistic noise level (RGB units) rather than ~0: near-static
    # footage (or a lossily re-encoded still frame) can have near-zero real
    # variation, and dividing by a near-zero MAD turns trivial codec noise into
    # a huge z-score. A real illumination jump is tens of RGB units, far above
    # this floor either way.
    mad = np.where(mad < ARTIFACT_MAD_FLOOR, ARTIFACT_MAD_FLOOR, mad)
    z = 0.6745 * deviation / mad
    # Require the deviation to also be large in absolute terms so the floor
    # above can't be gamed by z-score alone on a channel that barely moved.
    return bool(np.any((z > ARTIFACT_Z) & (deviation > ARTIFACT_MIN_ABS_DELTA)))


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
    region_lists = [[], [], []]
    last_rgb = None
    last_regions = [None, None, None]
    history = []
    artifact_streak = 0
    n_frames = 0
    n_face = 0
    n_reused = 0
    n_artifact = 0

    tracker = _FaceTracker()
    container = av.open(str(path))
    try:
        for frame in container.decode(video=0):
            n_frames += 1
            t = float(frame.time) if frame.time is not None else n_frames / 30.0
            bgr = _downscale(frame.to_ndarray(format="bgr24"))
            h, w = bgr.shape[:2]
            rgb_img = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            lms = tracker.landmarks(rgb_img, t)

            sample = None
            region_now = [None, None, None]
            if lms is not None:
                n_face += 1
                for i, ids in enumerate((FOREHEAD, LEFT_CHEEK, RIGHT_CHEEK)):
                    box = _box_from_ids(lms, ids, w, h)
                    if box is None:
                        continue
                    value = _mean_rgb_in_box(bgr, box)
                    if value is not None:
                        region_now[i] = value
                present = [value for value in region_now if value is not None]
                if present:
                    sample = np.mean(present, axis=0)

            is_artifact = False
            if sample is not None and _is_illumination_artifact(sample, history):
                if artifact_streak < ARTIFACT_MAX_STREAK:
                    # Brief transient (a flicker, a momentary flare): reject it.
                    is_artifact = True
                    artifact_streak += 1
                    n_artifact += 1
                    sample = None
                    region_now = [None, None, None]
                else:
                    # Rejected for too long in a row: this isn't a transient,
                    # it's a sustained lighting change. Stop fighting it and
                    # resync the baseline to the new normal.
                    history = []
                    artifact_streak = 0
            elif sample is not None:
                artifact_streak = 0

            if sample is None:
                if last_rgb is None:
                    continue
                sample = last_rgb
                if not is_artifact:
                    n_reused += 1
            else:
                history.append(sample)
                if len(history) > ARTIFACT_HISTORY:
                    history.pop(0)

            last_rgb = sample
            for i, value in enumerate(region_now):
                if value is not None:
                    last_regions[i] = value
            times.append(t)
            rgbs.append(sample)
            for i in range(3):
                region_lists[i].append(
                    last_regions[i] if last_regions[i] is not None else sample
                )
    finally:
        tracker.close()
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
    rgb_regions = []
    for region in region_lists:
        arr = np.asarray(region, dtype=np.float64)
        region_rs = np.column_stack(
            [np.interp(t_uniform, t, arr[:, c]) for c in range(3)]
        )
        rgb_regions.append(detrend(region_rs, axis=0))

    return {
        "n_frames": n_frames,
        "n_samples": n,
        "n_face": n_face,
        "n_reused": n_reused,
        "n_artifact": n_artifact,
        "duration_s": duration,
        "fs": fs,
        "t": t_uniform,
        "rgb": resampled,
        "rgb_regions": rgb_regions,
        "rgb_mean": resampled.mean(axis=0).tolist(),
        "rgb_std": resampled.std(axis=0).tolist(),
        "rgb_head": resampled[:5].tolist(),
    }
