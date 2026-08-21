# PLAN.md

Phased build plan for the Contactless Vital Signs Scanner MVP. See `Plans/INFO.md` for the full spec and binding algorithmic constraints (also summarized in `CLAUDE.md`).

Event: HackHarvard China 2026, Hangzhou — kickoff Friday, build Saturday, demo Sunday (36 hours total).

This plan is **two parallel tracks** (frontend and backend) plus short integration checkpoints. The iOS app and the FastAPI service must stay demoable independently: frontend against the mock API, backend with curl or a throwaway client. Do not serialize the iOS owner behind POS, and do not serialize the signal owner behind UI polish.

## Conflict rule

Merge conflicts stay minimal if nobody crosses directory lines.

- **Frontend-only:** `hackharvard/` and `hackharvard.xcodeproj/`. Use `fe/*` branches.
- **Backend-only:** `backend/` (created in I0). Use `be/*` branches.
- **Shared, write-once:** `contracts/process-api.md` (created in I0) and `Plans/`. Do not edit `Plans/` during coding. Do not change `contracts/` unless both owners sit together (I0-style).
- The JSON request/response is frozen in I0. Every field the demo might show exists on Friday, with `null` / `"unavailable"` until that vital is real. Adding a field later is the main merge-conflict source.
- After I0, the only expected frontend integration change is the backend URL in `hackharvard/APIConfig.swift`.
- Validation notebooks and dataset loaders live under `backend/validation/`, not in the iOS target.

```
iOS record/pick --> POST /v1/process --> POS pipeline --> JSON result screen
                         ^
                         |
              contracts/process-api.md (frozen I0)
```

## Frozen API (the only integration surface)

Write this once in `contracts/process-api.md` during **I0**. Neither track edits it afterward unless both sit together. No extra product APIs are required (no auth, no ML cloud, no streaming). Backend is FastAPI. iOS uses AVFoundation + URLSession only.

- `GET /health` → `{ "status": "ok" }`
- `POST /v1/process` multipart field `video`
- **200 body always includes the same keys** (mocks fill unused vitals with `null` and `"unavailable"`):
  - `hr_bpm`, `prv_sdnn_ms`, `prv_rmssd_ms`, `rr_brpm`, `spo2_pct` (number or null)
  - `quality.hr`, `quality.prv`, `quality.rr`, `quality.spo2`: `"ok"` or `"unavailable"`
  - `meta.duration_s`, `meta.fs`, `meta.disclaimer`
  - `error`: null on success
- **4xx/5xx body:** `{ "error": "invalid_file" | "no_face" | "too_short" | "too_much_motion" | "processing_failed", "message": "..." }`

## Resources to have before I0 (not extra product APIs)

- **Python:** FastAPI, uvicorn, python-multipart, numpy, scipy, opencv, mediapipe, av or ffmpeg.
- **Host:** one public HTTPS backend (Fly, Railway, or Render). A phone cannot call `localhost`.
- **Apple:** camera + photo library permissions; Developer account if installing on a real iPhone.
- **Data:** UBFC-rPPG zip for HR. COHFACE only if the EULA comes through; fallback is method-only respiration evidence — do not block frontend.
- **Backup clip:** one known-good face video bundled in the iOS app.

---

## Integration checkpoints (both people, short)

Frontend done-when does **not** wait on real POS. Backend done-when does **not** wait on polished UI.

### I0 — Friday, about 2 hours

Whole team.

- Create `backend/` skeleton and `contracts/process-api.md` with the frozen schema above.
- Deploy mock `GET /health` and `POST /v1/process`.
- Frontend uploads any file and renders whatever JSON comes back.

**Done when:** anyone can open the iOS client, upload a clip, and see a (fake) result screen from the deployed mock. This scaffolding is never rebuilt.

### I1 — after BE2

No frontend code change expected.

**Done when:** the existing UI shows a real, plausible `hr_bpm` from a UBFC or known-good clip. PRV/respiration may still be null / unavailable.

### I2 — after BE3

No frontend code change expected.

**Done when:** the existing UI shows real SDNN and respiration, or per-vital unavailable, with no mocked fields left except stretch SpO₂.

### I3 — Sunday

- Frontend points `APIConfig` at the final host.
- Confirm backup clip, demo-device pass, and pitch.
- SpO₂ stays null unless BE6 filled it.

**Done when:** the deployed app runs the full journey on demo devices, a backup video exists, and every teammate can explain the problem, POS in plain language, and the limitations.

---

## Backend track (only `backend/`)

Signal-processing owner + backend/validation owner. Algorithm steps in BE1–BE3 are MUST requirements from `Plans/INFO.md` — do not collapse them into “run POS.”

### BE0 — Mock API

- FastAPI `/health` and mock `/v1/process` matching `contracts/process-api.md`.
- Hardcoded placeholder vitals; no signal processing yet.

**Done when:** curl or the I0 iOS client gets a valid contract JSON from the deployed mock.

### BE1 — RGB extraction, response still mocked

- Decode video, read per-frame timestamps (no assumed constant fps).
- Face detection + landmarks per frame; forehead ROI with cheek fallback; skin mask; skip-or-reuse-last-ROI on empty mask.
- Spatially average masked pixels per frame into an RGB trace, streamed (not buffering every raw frame).
- Interpolate onto a uniform time grid to set `fs`; detrend each channel (no cardiac bandpass yet).
- Log/inspect the RGB trace out-of-band (debug endpoint or notebook). **Do not change the JSON the client already parses.**

**Done when:** the deployed mock response still works, and the RGB trace is verified against a known-good clip.

### BE2 — Real heart rate

- POS on overlapping 1.6 s windows (`L = round(1.6 * fs)`, hop 1 frame, per-window temporal normalization, overlap-add). Keep the unfiltered shared pulse.
- Branch A (HR): 0.7–4 Hz bandpass, Hamming/Hann window, zero-padded FFT (≤0.5 bpm bins), dominant peak.
- Basic quality gate: SNR of the pulse spectrum and motion score; return `"unavailable"` below threshold.
- Replace `hr_bpm` only. PRV, respiration, and SpO₂ stay null / unavailable.
- Spot-check a handful of UBFC-rPPG subjects (full run is BE4).
- Tests: POS uses 1.6 s windows; HR FFT is zero-padded.

**Done when:** I1 can show a real HR. Then go to I1.

### BE3 — Real PRV and respiration

- Branch B (PRV): cubic-spline upsample the same filtered pulse to 250 Hz, peak detection, interval cleaning, SDNN (primary); RMSSD only when interval-consistency quality passes.
- Branch C (respiration): pulse envelope first; fallback to 0.1–0.5 Hz bandpass on the *unfiltered* POS pulse. Never derive from the cardiac bandpass.
- Extend the quality gate independently per vital.
- Replace remaining mocked core fields (`prv_sdnn_ms`, `prv_rmssd_ms`, `rr_brpm`). Do not add JSON keys.
- Tests: upsample-before-peaks; respiration not taken from the cardiac bandpass.

**Done when:** I2 can show real HR + SDNN + respiration (or per-vital unavailable). Then go to I2.

### BE4 — Validation (does not change the API)

- Dataset-specific loaders under `backend/validation/` so the same POS core runs against UBFC-rPPG and offline clips.
- Full UBFC-rPPG run for HR (and PRV/pulse-waveform ground truth where supported).
- COHFACE run for respiration if access exists; otherwise document method-only RR evidence.
- MAE, RMSE, Pearson correlation reports per vital, each labeled with the dataset used — never imply UBFC alone validates all vitals.

**Done when:** a validation report exists per core vital with correct dataset attribution. The running API behavior is unchanged.

### BE5 — Limits and redeploy

- Upload size and processing time limits.
- Redeploy the hardened backend. A localhost-only demo is not acceptable.

**Done when:** a 30–60 s phone clip returns before the demo times out.

### BE6 — Stretch SpO₂ (only if I2 is stable)

- Extract RGB optical calibration features from the same ROI stream.
- Train/apply the offline SpO₂ model; SpO₂-specific quality gate.
- Fill `spo2_pct` and `quality.spo2` only. **Do not add new JSON keys.**
- Validate on unseen subjects against a dedicated SpO₂ dataset; report limitations honestly.
- Only include in the demo if evidence is credible and HR/PRV/respiration do not regress.

**Done when:** the deployed app returns SpO₂ without regressing core vitals, or SpO₂ stays null and out of the demo.

---

## Frontend track (only `hackharvard/` and `hackharvard.xcodeproj/`)

Mobile owner. Can run the whole time against the I0 mock. Do not wait for BE2+.

### FE0 — Upload against the mock

- Record or pick a video, upload multipart field `video`, decode the frozen JSON, show placeholders for every vital field.

**Done when:** I0 round-trip works on a device or simulator.

### FE1 — Main screens

- Instruction copy (positioning, 30–60 s).
- Capture, loading state during upload/processing.
- Result layout: HR, PRV (SDNN), respiration, per-vital unavailable, `meta.disclaimer`.

**Done when:** a judge can understand the three-vital result screen using mock data.

### FE2 — Capture quality and errors

- Camera and photo-library permissions.
- Lock AE/AWB at capture where AVFoundation allows it.
- Map `error` codes to screens: invalid file, no face, too short, too much motion, processing failed — must not crash.

**Done when:** a real phone recording and every error case above survive without crashing, still end-to-end against whatever backend is deployed.

### FE3 — Demo prep

- Bundle the backup clip in the app.
- Demo-device pass of the main journey and error cases.
- Switch `APIConfig` to the I3 host when backend is on the final URL.

**Done when:** I3 can run on the actual demo devices with a backup clip if live recording or network fails.

---

## Explicitly out of scope (do not build)

Live streaming measurement, on-device processing, diagnosis/treatment claims, login/accounts, history/charts/sharing — per `Plans/INFO.md` § NOT NOW and § COULD. Revisit only after I3.

Suggested ownership remains as in `Plans/INFO.md`: signal-processing, backend/validation, mobile, evidence/presentation, final integrator. Final integrator runs I0–I3, deployment, and backup-demo verification.
