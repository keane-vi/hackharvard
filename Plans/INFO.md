# Contactless Vital Signs Scanner — MVP Definition

## One-sentence MVP

A person records a short video of their face and receives contactless estimates of pulse, pulse-rate variability, and respiration rate without touching a sensor or wearing a device. SpO₂ remains part of the product vision as a stretch feature.

## Problem

People who need a quick pulse check may not have a wearable or medical sensor available, and contact-based measurements can be inconvenient or difficult to share in some settings.

This is a product in development, intended to provide convenient, non-contact vital-sign estimates. The MVP must validate its accuracy, communicate measurement quality, and avoid presenting estimates as a clinical diagnosis until the appropriate regulatory and clinical requirements are met.

## Target user

Primary user: a hackathon judge or demo participant using a phone in a reasonably well-lit, stationary setting.

Potential future users include caregivers, community health workers, and people who want a convenient preliminary wellness check.

## Solution statement

We help a person obtain convenient contactless estimates of pulse, pulse-rate variability, breathing rate, and blood oxygen saturation by analysing subtle color changes in a short video of their face.

## Core user journey

1. The user opens the mobile app.
2. The app explains how to position the face and record for approximately 30–60 seconds, which supports the variability measurement as well as the other vitals.
3. The user records a clip while remaining still and looking at the camera. Where the platform allows it, the app locks auto exposure and white balance for the recording.
4. The app uploads the clip to the FastAPI backend.
5. The backend validates the clip, extracts forehead/cheek skin RGB, and runs the POS pipeline below.
6. The backend derives HR, PRV, and respiration rate from branched estimators that share the unfiltered POS pulse.
7. If the SpO₂ stretch feature is complete, the backend also runs its trained RGB calibration model.
8. The app displays the available estimates, measurement quality, and a non-diagnostic limitation message.

## System definition

### Input

- A face video, approximately 30–60 seconds. Prefer about 60 seconds when PRV will be shown.
- Target capture: around 30 fps, visible face, stable lighting, limited movement.
- Frame timestamps must be available after decode. Do not assume a constant 30 fps.
- Auto exposure and white-balance lock apply at capture on the phone. They cannot be applied later to UBFC, COHFACE, or already-recorded uploads.

### Process

These steps are MUST requirements. Do not collapse them into a single “run POS” step.

**Shared front end (once per clip)**

1. Decode the uploaded video and read per-frame timestamps.
2. Detect a face and landmarks on every frame. Landmark a forehead ROI and cheek ROIs. If the forehead is occluded (hair, bangs, failed landmarks), fall back to cheeks. Apply a skin mask inside the boxes. If a frame’s mask is empty, skip that frame or reuse the last valid ROI; do not average background pixels.
3. Spatially average the masked skin pixels per frame and stream those RGB triples. Do not keep every decoded frame in memory.
4. Interpolate the RGB traces onto a uniform time grid from the timestamps. Set `fs` from that grid. Measuring mean fps and treating jittered frames as uniform is not sufficient.
5. Detrend each RGB channel over the clip. Do not apply the 0.7–4 Hz cardiac bandpass before POS.

**POS (shared pulse source)**

6. Run POS on overlapping windows of duration 1.6 seconds: `L = round(1.6 * fs)` frames (48 frames at 30 fps, 32 frames at 20 fps). Hop one frame. Inside each window, temporally normalize RGB by that window’s mean, project onto the plane orthogonal to skin tone, and overlap-add the window pulse onto the shared trace. Global detrend in step 5 does not replace per-window normalization. Keep the unfiltered overlap-added pulse as the shared source for all vitals. CHROM may be added later as a comparison method; it is not the primary path.

**Branch A — heart rate**

7. Bandpass the shared pulse at approximately 0.7–4 Hz. Apply a Hamming or Hann window. Zero-pad the FFT so the bin resolution is at most 0.5 bpm. Take the dominant peak in that band and convert to beats per minute. Welch overlapping windows are optional, not a substitute for padding.

**Branch B — PRV**

8. Start from the same 0.7–4 Hz pulse as Branch A. Cubic-spline upsample to 250 Hz (100 Hz is the floor, not the target). Detect peaks, remove implausible intervals, and compute short-window PRV. The primary reported metric is SDNN. Report RMSSD only when interval-consistency quality passes. A 30–60 second clip is a short-window PRV estimate, not a clinical HRV interpretation.

**Branch C — respiration**

9. Do not estimate respiration from the 0.7–4 Hz cardiac signal. Prefer the amplitude envelope of the cardiac pulse. If that is weak, bandpass the unfiltered POS pulse at 0.1–0.5 Hz (6–30 breaths per minute). Apply a Hamming or Hann window and a zero-padded FFT, then convert the dominant peak to breaths per minute.

**Quality gate**

10. Score SNR of the pulse spectrum, landmark motion, and interval consistency. Return unavailable per vital if that vital is below threshold. A clip may yield HR and still mark PRV or respiration unavailable.
11. If the SpO₂ stretch feature is enabled, extract RGB optical features from the same ROI stream and run the trained calibration model only when SpO₂-specific quality checks pass.

**Build order**

POS plus the quality gate first, validate HR on UBFC, then PRV and respiration, SpO₂ last.

### Output

- Estimated heart rate in beats per minute.
- Estimated PRV: SDNN in milliseconds as the primary metric; RMSSD only when interval quality passes.
- Estimated respiration rate in breaths per minute.
- Optional estimated SpO₂ percentage with measurement-quality information, only if the stretch feature passes validation.
- Signal-quality status or confidence indicator.
- A short explanation that the result is a product estimate, not a clinical diagnosis or replacement for a medical device.
- A useful error message when the clip cannot be measured.

### Value

The product provides a low-friction, contactless way to estimate multiple vital signs using a camera as the sensor, while making its evidence, accuracy, and limitations visible.

## MVP acceptance criteria

The MVP is complete when:

- A phone can record and upload a clip through the main user flow.
- The backend exposes a working video-processing endpoint and a health-check endpoint.
- The same POS core can process uploaded clips and offline validation videos.
- The core system returns HR, SDNN PRV, and respiration-rate results for a good-quality clip, or an explicit unavailable/low-quality status for an individual vital.
- If SpO₂ is implemented, it returns an estimate only for clips that pass the SpO₂ quality and validation thresholds.
- The system handles invalid files, missing faces, excessive motion, clips that are too short, and processing errors without crashing.
- The result screen clearly distinguishes an estimate from a clinical measurement.
- The pipeline can be run against each selected validation dataset through a dataset-specific loader.
- Validation reports include MAE, RMSE, and Pearson correlation against ground truth for every vital where ground truth exists.
- The validation report identifies the ground-truth dataset used for each vital and does not imply that UBFC alone validates all four.
- The complete flow can be demonstrated from a deployed or otherwise presentation-ready environment.

## Feature priority and implementation certainty

The product vision includes all four vital signs. The hackathon MVP must deliver HR, PRV/short-window HRV, and respiration rate. SpO₂ is a stretch feature and should be implemented only after the core flow, testing, and demo are reliable.

### Definitely implementable in the core MVP

- Video recording and upload, with AE/AWB lock at capture where the platform allows it.
- Per-frame face landmarks, forehead/cheek ROI, cheek fallback, and skin-masked RGB traces resampled onto a uniform time grid.
- POS on overlapping 1.6 s windows with per-window temporal normalization and overlap-add.
- Heart-rate estimation from the 0.7–4 Hz pulse using a Hamming/Hann window and a zero-padded FFT.
- Peak detection on the 250 Hz upsampled pulse, interval cleaning, and SDNN as the PRV metric.
- Respiration-rate estimation from the pulse envelope, or from a separate 0.1–0.5 Hz band on the unfiltered POS pulse.
- Per-vital quality checks, unavailable states, API responses, validation loaders, and metric reports.

### High validation risk, but still part of the product

- **PRV/HRV:** technically derivable from the recovered pulse waveform, but sensitive to motion, frame timing, peak detection, and recording length. A camera measures pulse intervals, so PRV is the more precise term unless ECG ground truth is used. Upsampling and interval cleaning are required; SDNN is the primary short-window metric. A 30–60-second clip supports a short-window variability estimate, not every standard clinical HRV interpretation.
- **Respiration rate:** implementable from the pulse envelope or a separate 0.1–0.5 Hz band, but more vulnerable than HR to movement, facial expression, speaking, and weak modulation. It must not be taken from the cardiac bandpass. It requires dedicated respiration ground truth such as COHFACE.
- **SpO₂:** implementable as a trained RGB-camera calibration feature, but the most difficult to validate. It depends strongly on illumination, camera characteristics, skin region, skin tone, calibration, and reference measurements. It requires a dedicated SpO₂ dataset and careful product-quality thresholds, so it is a stretch feature for the hackathon.

### Lowest technical risk

- **Heart rate:** the most established rPPG output and the first signal to use for pipeline debugging and quality gating. POS and CHROM are directly supported as traditional unsupervised methods in the rPPG-Toolbox.

## MVP training strategy

The first MVP does not require a machine-learning model for every vital.

- **HR:** POS, 0.7–4 Hz bandpass, Hamming/Hann, zero-padded FFT, dominant peak.
- **PRV/short-window HRV:** same cardiac pulse, upsample to 250 Hz, peak detection, interval cleaning, SDNN.
- **Respiration rate:** pulse envelope first, otherwise 0.1–0.5 Hz on the unfiltered POS pulse, then dominant frequency.
- **SpO₂:** an offline-trained calibration model that maps RGB optical features to paired reference SpO₂ readings.

The SpO₂ model is trained once on suitable paired data, saved, and used by the FastAPI service for inference if the stretch feature is enabled. The same shared video and ROI pipeline feeds all enabled estimators.

### MUST — first complete multi-vital slice

- FastAPI application.
- Video upload endpoint.
- Video decoding, timestamp-based resampling onto a uniform `fs`, and `L = round(1.6 * fs)` POS windows.
- Per-frame face landmarks, forehead/cheek ROI, cheek fallback, and skin-masked RGB streaming averages.
- POS with per-window temporal normalization, overlap-add, and an unfiltered shared pulse.
- Cardiac 0.7–4 Hz bandpass, Hamming/Hann, zero-padded FFT (≤ 0.5 bpm bins), dominant-frequency HR.
- Upsample that same filtered pulse to 250 Hz, peak detection, interval cleaning, and SDNN PRV.
- Respiration from pulse envelope or a separate 0.1–0.5 Hz band on the unfiltered pulse, never from the cardiac bandpass.
- Per-vital SNR, motion, and interval-consistency gates with unavailable states.
- Mobile recording/upload screen, with AE/AWB lock where the platform allows it.
- Result and error states.
- Minimal automated tests for the signal core and API, including tests that POS uses 1.6 s windows, that PRV upsamples before peaks, and that HR FFT is zero-padded.

### SHOULD — strengthen the evidence and demo

- CHROM comparison baseline.
- Detect-then-track with redetect every 5–10 frames, only if per-frame landmarks are too slow.
- Welch overlapping windows as a robustness check on HR, in addition to the padded FFT.
- UBFC-rPPG evaluation across all 42 subjects for HR and pulse-waveform/PRV-related ground truth where supported.
- COHFACE evaluation for respiration rate.
- MAE, RMSE, and Pearson correlation reports separated by vital and dataset.
- Measurement metadata such as duration, frame rate, and quality status.
- Backup sample clip for reliable demonstration.
- Simple explanation of how rPPG works.

### STRETCH — implement only if the core is complete

- Train an RGB SpO₂ calibration model on suitable paired reference data.
- Add SpO₂ feature extraction, inference, quality rejection, and API output.
- Validate SpO₂ on unseen subjects and report its limitations clearly.
- Include SpO₂ in the demo only if it produces credible validation evidence.

### COULD — add only after the core flow works

- History, charts, accounts, or result sharing.

### NOT NOW

- Live streaming measurement.
- On-device Python or on-device ROI extraction.
- Diagnosis, treatment recommendations, or medical claims.
- Login and account management.
- Production-grade clinical accuracy claims.

## Definition of done for the hackathon core

The team can explain the problem, show one reliable video-to-three-vitals journey, report validation evidence for each core vital, describe the POS method in plain language, and state the limitations honestly. If the stretch work succeeds, the team can add SpO₂ as a fourth output with separate evidence. The core MVP must remain complete even if SpO₂ is not implemented.

## Suggested ownership

- Signal-processing owner: resampling, POS windowing, branched filters, HR/PRV/respiration estimators, quality checks.
- Backend/validation owner: FastAPI, video handling, dataset loaders, metrics.
- Mobile owner: recording, upload, loading/error/result states.
- Evidence/presentation owner: sources, validation methodology, limitations, demo story.
- Final integrator: runs the end-to-end flow, deployment, and backup demo verification.
