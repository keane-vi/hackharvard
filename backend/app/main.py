import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile

from app.pipeline import extract_rgb_trace

DISCLAIMER = (
    "This is a product estimate, not a clinical diagnosis "
    "or a replacement for a medical device."
)

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/debug/rgb")
async def debug_rgb(video: UploadFile = File(...)):
    suffix = Path(video.filename or "clip.mp4").suffix or ".mp4"
    contents = await video.read()
    tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    try:
        tmp.write(contents)
        tmp.close()
        return extract_rgb_trace(tmp.name)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    finally:
        Path(tmp.name).unlink(missing_ok=True)


@app.post("/v1/process")
async def process_video(video: UploadFile = File(...)):
    _ = await video.read()
    return {
        "hr_bpm": 72.0,
        "prv_sdnn_ms": None,
        "prv_rmssd_ms": None,
        "rr_brpm": None,
        "spo2_pct": None,
        "quality": {
            "hr": "ok",
            "prv": "unavailable",
            "rr": "unavailable",
            "spo2": "unavailable",
        },
        "meta": {
            "duration_s": None,
            "fs": None,
            "disclaimer": DISCLAIMER,
        },
        "error": None,
    }
