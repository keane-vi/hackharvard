# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This repo is pre-implementation: no source code, package manifest, build system, or tests exist yet. Only `README.md` and `Plans/INFO.md` are present. Do not assume any language, framework, or directory layout — establish it when implementation actually starts, and update this file once real build/test/lint commands exist.

## Source of truth

`Plans/INFO.md` is the MVP spec for a **Contactless Vital Signs Scanner**: a mobile app records a 30–60s face video, a FastAPI backend runs remote photoplethysmography (rPPG) to estimate heart rate, pulse-rate variability (PRV), and respiration rate; SpO₂ is a stretch goal. Read it in full before implementing any part of the pipeline — it is intentionally prescriptive and its MUST-requirements below are binding, not suggestions.

## Non-negotiable pipeline constraints (from Plans/INFO.md)

- Do not apply the 0.7–4 Hz cardiac bandpass before running POS. Detrend first, filter per-branch after.
- Resample RGB traces onto a uniform time grid derived from actual frame timestamps, not an assumed/measured mean fps.
- Run POS on overlapping 1.6s windows (`L = round(1.6 * fs)`), hop one frame, per-window temporal normalization, overlap-add. Keep the unfiltered overlap-added pulse as the shared source for every branch.
- HR: bandpass shared pulse 0.7–4 Hz, Hamming/Hann window, zero-padded FFT (≤0.5 bpm bin resolution), dominant peak.
- PRV: start from the same filtered pulse as HR, cubic-spline upsample to 250 Hz (100 Hz floor), peak detection, interval cleaning. SDNN is the primary metric; report RMSSD only when interval-consistency quality passes.
- Respiration: never derive from the cardiac bandpass. Prefer the cardiac pulse envelope; otherwise bandpass the unfiltered POS pulse at 0.1–0.5 Hz.
- Apply a quality gate (SNR, motion, interval consistency) per vital; return "unavailable" per vital below threshold rather than a bad estimate.
- Build order: POS + quality gate first, validate HR on UBFC-rPPG, then PRV and respiration, SpO₂ last.
- Out of scope for now: live streaming, on-device processing, diagnosis/medical claims, login/accounts, history/charts.

## Working here

- Before writing pipeline code, check whether the step you're implementing is already specified in `Plans/INFO.md` — follow it exactly rather than choosing a different signal-processing approach.
- Once a real stack (backend, mobile client, validation tooling) is scaffolded, update this file with actual build/test/lint commands and directory structure.
