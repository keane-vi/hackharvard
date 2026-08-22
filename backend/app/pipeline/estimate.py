from .hr import heart_rate_bpm
from .pos import pos
from .quality import hr_quality_ok, motion_score, pulse_snr
from .rgb import extract_rgb_trace

DISCLAIMER = (
    "This is a product estimate, not a clinical diagnosis "
    "or a replacement for a medical device."
)


class ProcessError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def _unavailable_response(duration_s, fs, hr_ok: bool, hr_bpm):
    return {
        "hr_bpm": hr_bpm,
        "prv_sdnn_ms": None,
        "prv_rmssd_ms": None,
        "rr_brpm": None,
        "spo2_pct": None,
        "quality": {
            "hr": "ok" if hr_ok else "unavailable",
            "prv": "unavailable",
            "rr": "unavailable",
            "spo2": "unavailable",
        },
        "meta": {
            "duration_s": duration_s,
            "fs": fs,
            "disclaimer": DISCLAIMER,
        },
        "error": None,
    }


def estimate_vitals(video_path: str) -> dict:
    try:
        trace = extract_rgb_trace(video_path)
    except ValueError as exc:
        code = str(exc)
        if code == "too_few_skin_samples":
            raise ProcessError("no_face", "Could not find enough face skin in the clip.") from exc
        if code == "too_short":
            raise ProcessError("too_short", "The clip is too short to estimate heart rate.") from exc
        raise ProcessError("processing_failed", str(exc)) from exc
    except Exception as exc:
        raise ProcessError("invalid_file", "Could not read the uploaded file.") from exc

    try:
        pulse = pos(trace["rgb"], trace["fs"])
        snr = pulse_snr(pulse, trace["fs"])
        motion = motion_score(trace["n_reused"], trace["n_frames"])
        if not hr_quality_ok(snr, motion):
            return _unavailable_response(trace["duration_s"], trace["fs"], False, None)
        hr_bpm = float(heart_rate_bpm(pulse, trace["fs"]))
        return _unavailable_response(trace["duration_s"], trace["fs"], True, hr_bpm)
    except ValueError as exc:
        if str(exc) == "too_short":
            raise ProcessError("too_short", "The clip is too short to estimate heart rate.") from exc
        raise ProcessError("processing_failed", str(exc)) from exc
