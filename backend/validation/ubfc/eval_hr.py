"""Spot-check UBFC-rPPG DATASET_2 HR against our pipeline.

Official UBFC note: evaluate against HR from the contact PPG (row 1),
not the pulse-oximeter HR row.
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

DATASET = Path(__file__).resolve().parent / "DATASET_2"
SUBJECTS = ("subject1", "subject3", "subject5")


def load_gt(path: Path) -> dict:
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


def main() -> int:
    rows = []
    for name in SUBJECTS:
        folder = DATASET / name
        video = folder / "vid.avi"
        gt_path = folder / "ground_truth.txt"
        if not video.exists() or video.stat().st_size < 1000:
            print(f"SKIP {name}: missing {video}")
            continue
        if not gt_path.exists():
            print(f"SKIP {name}: missing {gt_path}")
            continue
        print(f"RUN {name} ({video.stat().st_size / 1e6:.1f} MB)...")
        gt = load_gt(gt_path)
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
        rows.append(row)
        print(json.dumps(row, indent=2))

    if not rows:
        print("No subjects with vid.avi + ground_truth.txt.")
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
