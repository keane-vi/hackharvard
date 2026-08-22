import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse

from app.pipeline.estimate import ProcessError, estimate_vitals
from app.pipeline.rgb import extract_rgb_trace

DEBUG_RGB_KEYS = (
    "n_frames",
    "n_samples",
    "n_face",
    "n_reused",
    "duration_s",
    "fs",
    "rgb_mean",
    "rgb_std",
    "rgb_head",
)

app = FastAPI()


async def _save_upload(video: UploadFile) -> str:
    suffix = Path(video.filename or "clip.mp4").suffix or ".mp4"
    contents = await video.read()
    tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    tmp.write(contents)
    tmp.close()
    return tmp.name


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/debug/rgb")
async def debug_rgb(video: UploadFile = File(...)):
    tmp_path = await _save_upload(video)
    try:
        trace = extract_rgb_trace(tmp_path)
        return {key: trace[key] for key in DEBUG_RGB_KEYS}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    finally:
        Path(tmp_path).unlink(missing_ok=True)


@app.post("/v1/process")
async def process_video(video: UploadFile = File(...)):
    tmp_path = await _save_upload(video)
    try:
        # Video decoding and MediaPipe analysis are CPU-heavy synchronous work.
        # Keep them off the event loop so /health and other requests remain responsive.
        return await run_in_threadpool(estimate_vitals, tmp_path)
    except ProcessError as exc:
        return JSONResponse(
            status_code=400,
            content={"error": exc.code, "message": exc.message},
        )
    finally:
        Path(tmp_path).unlink(missing_ok=True)
