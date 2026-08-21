# PLAN.md

Phased build plan for the Contactless Vital Signs Scanner MVP. See `Plans/INFO.md` for the full spec and binding algorithmic constraints (also summarized in `CLAUDE.md`). This plan is organized as **vertical slices**, not layers: every phase adds one thing to a client → backend → result flow that already runs, so the team always has a demoable app, never just a finished internal component waiting on the rest.

Event: HackHarvard China 2026, Hangzhou — kickoff Friday, build Saturday, demo Sunday (36 hours total). Do not start a phase until the previous phase's app is running end-to-end (client hits backend, backend returns something, client displays it) — if a phase leaves the app broken or non-demoable, that phase isn't done.

## Phase 0 — Walking skeleton (deploy first, build second)

Whole team.

- Confirm roles: signal-processing owner, backend/validation owner, mobile owner, evidence/presentation owner, final integrator (per `Plans/INFO.md` § Suggested ownership).
- Set up accounts, API keys, deployment target, and local dev environment for everyone — nothing later should block on missing access.
- FastAPI skeleton with `/health`, and a trivial mock video-processing endpoint that accepts an upload and returns hardcoded placeholder values (fake HR/PRV/respiration numbers) — no real signal processing yet.
- Minimal mobile/web client: a record-or-pick-video screen, an upload action, and a result screen that displays whatever the backend returns.
- Deploy both ends immediately, even with fake data.

**Done when:** anyone can open the deployed client, upload any clip, and see a (fake) result screen. This is the shape every later phase fills in — never rebuild this scaffolding.

## Phase 1 — Real RGB extraction feeding the same skeleton

Backend/signal-processing owner. Client and API contract from Phase 0 stay unchanged.

- Decode video, read real per-frame timestamps (no assumed constant fps).
- Face detection + landmarks per frame; forehead ROI with cheek fallback; skin mask; skip-or-reuse-last-ROI on empty mask.
- Spatially average masked pixels per frame into an RGB trace, streamed (not buffering every raw frame).
- Interpolate onto a uniform time grid to set `fs`; detrend each channel (no cardiac bandpass yet).
- Swap the mock endpoint's fake numbers for real ones only once HR is real in Phase 2 — for now, log/inspect the extracted RGB trace out-of-band (e.g. a debug endpoint or notebook) without breaking the deployed client's fake-but-working response.

**Done when:** the deployed app still works exactly as in Phase 0 from the user's view, and the RGB trace is verified correct against a known-good clip.

## Phase 2 — Real heart rate replaces the fake number

Signal-processing owner.

- Implement POS on overlapping 1.6 s windows (`L = round(1.6 * fs)`, hop 1 frame, per-window temporal normalization, overlap-add). Keep the unfiltered shared pulse.
- Branch A (HR): 0.7–4 Hz bandpass, Hamming/Hann window, zero-padded FFT (≤0.5 bpm bins), dominant peak.
- Basic quality gate: SNR of the pulse spectrum and motion score; return "unavailable" below threshold.
- Replace the mock HR value in the API response with the real one; PRV/respiration stay mocked for now.
- Validate against a handful of UBFC-rPPG subjects (full run happens in Phase 5).

**Done when:** the deployed app returns a real, plausible HR (directionally correct against a UBFC clip) end-to-end from the client, with PRV/respiration still mocked but not broken.

## Phase 3 — Real PRV and respiration replace the remaining mocks

Signal-processing owner.

- Branch B (PRV): cubic-spline upsample the same filtered pulse to 250 Hz, peak detection, interval cleaning, SDNN (primary); RMSSD only when interval-consistency quality passes.
- Branch C (respiration): pulse envelope first; fallback to 0.1–0.5 Hz bandpass on the *unfiltered* POS pulse. Never derive from the cardiac bandpass.
- Extend the quality gate to score interval consistency (PRV) and respiration-band SNR independently — a clip can return HR while PRV/respiration are "unavailable".
- Replace the remaining mocked fields (PRV, respiration) in the API response with real values.

**Done when:** the deployed app returns real HR + SDNN + respiration rate (or per-vital "unavailable") end-to-end, with no mocked fields left, matching the MUST-requirements test list in `Plans/INFO.md` (1.6 s POS windows, upsample-before-peaks, zero-padded HR FFT).

## Phase 4 — Client hardening

Mobile owner + final integrator.

- Recording screen: explain positioning, record 30–60 s, lock AE/AWB at capture where the platform allows it.
- Proper loading state during upload/processing (Phase 0's client likely had a crude one).
- Result screen: HR, PRV, respiration, per-vital quality/unavailable states, and the non-diagnostic limitation message.
- Error states: invalid file, no face detected, excessive motion, clip too short, processing error — must not crash.

**Done when:** the deployed app survives a real phone recording and every error case above without crashing, still end-to-end.

## Phase 5 — Validation & evidence

Evidence/presentation owner + backend/validation owner. Runs alongside Phase 4; does not change the running app's behavior, only proves it.

- Dataset-specific loaders so the same POS core runs against UBFC-rPPG and offline clips.
- Full UBFC-rPPG run for HR (and PRV/pulse-waveform ground truth where supported).
- COHFACE run for respiration.
- MAE, RMSE, Pearson correlation reports per vital, each labeled with the dataset used — never imply UBFC alone validates all vitals.
- Feed real numbers into the pitch/demo story; prepare Q&A on methodology and limitations.

**Done when:** the deployed app is unaffected and a validation report exists per core vital with the correct dataset attribution.

## Phase 6 — Polish, redeploy, demo prep

Whole team, final integrator leads.

- Redeploy the hardened backend and client from Phases 4–5 — a localhost-only demo is not acceptable.
- Record a backup demo video in case live recording, network, or the deployed site fails at demo time.
- Full team test pass: main user journey end-to-end, error/edge cases, on the actual demo devices.
- Rehearse the Problem → Action → Outcome → Impact pitch structure; make sure every team member can explain the problem, POS method (plain language), and limitations.

**Done when:** the deployed app demonstrably runs the full journey, a backup video exists, and every teammate can explain the approach.

## Phase 7 — Stretch: SpO₂ (only if Phases 0–6 are done and stable)

- Extract RGB optical calibration features from the same ROI stream.
- Train/apply the offline SpO₂ calibration model; add SpO₂-specific quality gate.
- Add SpO₂ as one more field in the same API response — mocked/omitted first, then real, following the same replace-the-mock pattern as Phases 1–3.
- Validate on unseen subjects against a dedicated SpO₂ dataset; report limitations honestly.
- Only add to the demo if validation evidence is credible, and only if it doesn't put the already-working Phase 6 app at risk — do not ship it half-validated.

**Done when:** the deployed app returns SpO₂ end-to-end without regressing HR/PRV/respiration, or SpO₂ is left out of the demo entirely.

## Explicitly out of scope (do not build)

Live streaming measurement, on-device processing, diagnosis/treatment claims, login/accounts, history/charts/sharing — per `Plans/INFO.md` § NOT NOW and § COULD. Revisit only after the core MVP (Phases 0–6) is complete and demo-ready.
