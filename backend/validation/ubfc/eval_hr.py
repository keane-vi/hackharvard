"""Spot-check UBFC-rPPG HR against our pipeline.

Supports two dataset layouts:
- DATASET_2: subject folders under DATASET_2/, each with vid.avi +
  ground_truth.txt (3 rows: PPG signal, sensor HR, timestamps in seconds).
- DATASET_1: a single vid.avi + gtdump.xmp placed directly in this folder
  (4 comma-separated columns: timestamp ms, HR, SpO2, PPG signal).

Official UBFC note: evaluate against HR derived from the contact PPG signal,
not the pulse-oximeter HR column.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from app.pipeline.estimate import ProcessError, estimate_vitals
from app.pipeline.hr import heart_rate_bpm

HERE = Path(__file__).resolve().parent
DATASET_2_DIR = HERE / "DATASET_2"
DATASET_2_SUBJECTS = ("subject1", "subject3", "subject5")


def load_gt_dataset2(path: Path) -> dict:
    data = np.loadtxt(path)
    ppg = np.asarray(data[0], dtype=np.float64)
    sensor_hr = np.asarray(data[1], dtype=np.float64)
    t = np.asarray(data[2], dtype=np.float64)
    duration = float(t[-1] - t[0]) if t.size > 1 else 0.0
    fs = (len(t) - 1) / duration if duration > 0 else 30.0
    ppg = ppg - ppg.mean()
    return {
        "ppg_hr_bpm": float(heart_rate_bpm(ppg, fs)),
        "sensor_hr_mean": float(np.mean(sensor_hr)),
        "duration_s": duration,
        "fs": fs,
    }


def load_gt_dataset1(path: Path) -> dict:
    data = np.loadtxt(path, delimiter=",")
    t_ms = np.asarray(data[:, 0], dtype=np.float64)
    sensor_hr = np.asarray(data[:, 1], dtype=np.float64)
    ppg = np.asarray(data[:, 3], dtype=np.float64)
    t = t_ms / 1000.0
    duration = float(t[-1] - t[0]) if t.size > 1 else 0.0
    fs = (len(t) - 1) / duration if duration > 0 else 30.0
    ppg = ppg - ppg.mean()
    return {
        "ppg_hr_bpm": float(heart_rate_bpm(ppg, fs)),
        "sensor_hr_mean": float(np.mean(sensor_hr)),
        "duration_s": duration,
        "fs": fs,
    }


def _evaluate(name: str, video: Path, gt: dict) -> dict:
    print(f"RUN {name} ({video.stat().st_size / 1e6:.1f} MB)...")
    try:
        result = estimate_vitals(str(video))
        pred = result["hr_bpm"]
        quality = result["quality"]["hr"]
        err = None
    except ProcessError as exc:
        pred = None
        quality = "error"
        err = f"{exc.code}: {exc.message}"
    row = {
        "subject": name,
        "pred_hr_bpm": pred,
        "quality": quality,
        "gt_ppg_hr_bpm": gt["ppg_hr_bpm"],
        "gt_sensor_hr_mean": gt["sensor_hr_mean"],
        "abs_err_vs_ppg": None if pred is None else abs(pred - gt["ppg_hr_bpm"]),
        "abs_err_vs_sensor": None if pred is None else abs(pred - gt["sensor_hr_mean"]),
        "error": err,
    }
    print(json.dumps(row, indent=2))
    return row


def _collect_dataset2(rows: list) -> None:
    for name in DATASET_2_SUBJECTS:
        folder = DATASET_2_DIR / name
        video = folder / "vid.avi"
        gt_path = folder / "ground_truth.txt"
        if not video.exists() or video.stat().st_size < 1000:
            print(f"SKIP {name}: missing {video}")
            continue
        if not gt_path.exists():
            print(f"SKIP {name}: missing {gt_path}")
            continue
        rows.append(_evaluate(name, video, load_gt_dataset2(gt_path)))


def _collect_dataset1_flat(rows: list) -> None:
    """A single vid.avi + gtdump.xmp dropped directly in this folder."""
    video = HERE / "vid.avi"
    gt_path = HERE / "gtdump.xmp"
    if not video.exists() or not gt_path.exists():
        return
    rows.append(_evaluate("dataset1_flat", video, load_gt_dataset1(gt_path)))


def _collect_dataset2_flat(rows: list) -> None:
    """A single vid2.avi + ground_truth.txt dropped directly in this folder."""
    video = HERE / "vid2.avi"
    gt_path = HERE / "ground_truth.txt"
    if not video.exists() or not gt_path.exists():
        return
    rows.append(_evaluate("dataset2_flat", video, load_gt_dataset2(gt_path)))


def main() -> int:
    rows: list[dict] = []
    _collect_dataset2(rows)
    _collect_dataset1_flat(rows)
    _collect_dataset2_flat(rows)

    if not rows:
        print("No subjects with a video + matching ground truth found.")
        return 1

    ppg_errs = [r["abs_err_vs_ppg"] for r in rows if r["abs_err_vs_ppg"] is not None]
    sensor_errs = [r["abs_err_vs_sensor"] for r in rows if r["abs_err_vs_sensor"] is not None]
    summary = {
        "n_subjects": len(rows),
        "n_ok": len(ppg_errs),
        "mae_vs_contact_ppg_hr": float(np.mean(ppg_errs)) if ppg_errs else None,
        "mae_vs_sensor_hr": float(np.mean(sensor_errs)) if sensor_errs else None,
        "rmse_vs_contact_ppg_hr": float(np.sqrt(np.mean(np.square(ppg_errs)))) if ppg_errs else None,
        "subjects": rows,
    }
    print("SUMMARY")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
