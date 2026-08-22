from fastapi import FastAPI, File, UploadFile

DISCLAIMER = (
    "This is a product estimate, not a clinical diagnosis "
    "or a replacement for a medical device."
)

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


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
