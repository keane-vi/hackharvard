# Process API (frozen I0)

Do not add or rename fields after I0. Fill unused vitals with `null` and `"unavailable"`.

## `GET /health`

```json
{ "status": "ok" }
```

## `POST /v1/process`

- Content-Type: `multipart/form-data`
- Field name: `video` (the file)

### 200

```json
{
  "hr_bpm": 72.0,
  "prv_sdnn_ms": null,
  "prv_rmssd_ms": null,
  "rr_brpm": null,
  "spo2_pct": null,
  "quality": {
    "hr": "ok",
    "prv": "unavailable",
    "rr": "unavailable",
    "spo2": "unavailable"
  },
  "meta": {
    "duration_s": null,
    "fs": null,
    "disclaimer": "This is a product estimate, not a clinical diagnosis or a replacement for a medical device."
  },
  "error": null
}
```

All of `hr_bpm`, `prv_sdnn_ms`, `prv_rmssd_ms`, `rr_brpm`, `spo2_pct` are a number or `null`.

Each `quality.*` value is `"ok"` or `"unavailable"`.

### 4xx / 5xx

```json
{
  "error": "invalid_file",
  "message": "Could not read the uploaded file."
}
```

`error` is one of: `invalid_file`, `no_face`, `too_short`, `too_much_motion`, `processing_failed`.
