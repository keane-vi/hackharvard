from .hr import heart_rate_bpm
from .pos import pos
from .prv import estimate_prv
from .quality import hr_quality_ok, motion_score, pulse_snr
from .rgb import extract_rgb_trace
from .robust_hr import robust_heart_rate

DISCLAIMER = (
    "This is a product estimate, not a clinical diagnosis "
    "or a replacement for a medical device."
)


class ProcessError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def _unavailable_response(duration_s, fs, hr_ok: bool, hr_bpm, prv=None):
    prv = prv or {"sdnn_ms": None, "rmssd_ms": None, "ok": False}
    return {
        "hr_bpm": hr_bpm,
        "prv_sdnn_ms": prv["sdnn_ms"],
        "prv_rmssd_ms": prv["rmssd_ms"],
        "rr_brpm": None,
        "spo2_pct": None,
        "quality": {
            "hr": "ok" if hr_ok else "unavailable",
            "prv": "ok" if prv["ok"] else "unavailable",
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
        robust = robust_heart_rate(trace)
        hr_bpm = float(robust if robust is not None else heart_rate_bpm(pulse, trace["fs"]))
        hr_ok = robust is not None or hr_quality_ok(snr, motion)
        prv = estimate_prv(pulse, trace["fs"])
        return _unavailable_response(trace["duration_s"], trace["fs"], hr_ok, hr_bpm, prv)
    except ValueError as exc:
        if str(exc) == "too_short":
            raise ProcessError("too_short", "The clip is too short to estimate heart rate.") from exc
        raise ProcessError("processing_failed", str(exc)) from exc
