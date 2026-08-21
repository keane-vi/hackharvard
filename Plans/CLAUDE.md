# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

- **iOS client:** `hackharvard/` and `hackharvard.xcodeproj/` (SwiftUI scaffold).
- **Backend:** `backend/` is created in PLAN.md I0 (FastAPI). Do not put Python under the Xcode target.
- **API contract:** `contracts/process-api.md` is written once in I0 and frozen.
- **Spec:** `Plans/INFO.md` (algorithm). **Build order:** `Plans/PLAN.md` (parallel FE/BE tracks).

Do not assume extra languages or layouts. When real build/test/lint commands exist, add them here.

## Directory ownership (avoid merge conflicts)

- Frontend commits only in `hackharvard/` and `hackharvard.xcodeproj/`. Branches: `fe/*`.
- Backend commits only in `backend/`. Branches: `be/*`.
- Do not change `contracts/` without both owners agreeing (I0-style). Do not edit `Plans/` during feature work.
- After I0, the only expected iOS integration change is the backend URL in `hackharvard/APIConfig.swift`.
- Validation loaders live in `backend/validation/`.

Follow `Plans/PLAN.md` track order: frontend FE0–FE3 against the mock; backend BE0–BE6. Do not serialize one track behind the other except at integration checkpoints I0–I3.

## Source of truth

`Plans/INFO.md` is the MVP spec for a **Contactless Vital Signs Scanner**: a mobile app records a 30–60s face video, a FastAPI backend runs remote photoplethysmography (rPPG) to estimate heart rate, pulse-rate variability (PRV), and respiration rate; SpO₂ is a stretch goal. Read it in full before implementing any part of the pipeline — it is intentionally prescriptive and its MUST-requirements below are binding, not suggestions.

The JSON schema in `contracts/process-api.md` / `Plans/PLAN.md` § Frozen API is also binding. Do not add response keys after I0; fill existing fields (`null` / `"unavailable"` until real).

## Non-negotiable pipeline constraints (from Plans/INFO.md)

- Do not apply the 0.7–4 Hz cardiac bandpass before running POS. Detrend first, filter per-branch after.
- Resample RGB traces onto a uniform time grid derived from actual frame timestamps, not an assumed/measured mean fps.
- Run POS on overlapping 1.6s windows (`L = round(1.6 * fs)`), hop one frame, per-window temporal normalization, overlap-add. Keep the unfiltered overlap-added pulse as the shared source for every branch.
- HR: bandpass shared pulse 0.7–4 Hz, Hamming/Hann window, zero-padded FFT (≤0.5 bpm bin resolution), dominant peak.
- PRV: start from the same filtered pulse as HR, cubic-spline upsample to 250 Hz (100 Hz floor), peak detection, interval cleaning. SDNN is the primary metric; report RMSSD only when interval-consistency quality passes.
- Respiration: never derive from the cardiac bandpass. Prefer the cardiac pulse envelope; otherwise bandpass the unfiltered POS pulse at 0.1–0.5 Hz.
- Apply a quality gate (SNR, motion, interval consistency) per vital; return "unavailable" per vital below threshold rather than a bad estimate.
- Backend build order: POS + quality gate first, validate HR on UBFC-rPPG, then PRV and respiration, SpO₂ last (BE2 → BE3 → BE4 → BE6).
- Out of scope for now: live streaming, on-device processing, diagnosis/medical claims, login/accounts, history/charts.

## Working here

- Before writing pipeline code, check whether the step you're implementing is already specified in `Plans/INFO.md` — follow it exactly rather than choosing a different signal-processing approach.
- Before writing client or API code, follow `Plans/PLAN.md` for the current track (FE vs BE) and do not change the frozen contract.
- Once a real stack is scaffolded, update this file with actual build/test/lint commands.
