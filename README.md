# Groundspeed

Precision GNSS ground-speed instrument for iOS & Android. Dark, minimal,
single-purpose: a big, filtered, tabular speed readout driven straight off
satellite fixes — with a live trace, session max, haversine distance and
satellite telemetry (Android GNSS status channel).

**Nothing is built locally.** All builds run on GitHub Actions.

## Build pipeline

| Workflow | Trigger | Output |
| --- | --- | --- |
| `CI` | push to `main`, PRs, manual | analyze + tests + **release APK** artifact |
| `iOS build` | manual (`workflow_dispatch`) | unsigned `.ipa` (re-sign / sideload yourself) |

Platform folders (`android/`, `ios/` scaffolding) are generated in CI via
`flutter create`; only hand-written sources live in the repo.

## Install on your phone

1. Open the latest green **CI** run → Artifacts → `groundspeed-android`
2. Sideload the APK (or `gh run download -n groundspeed-android`)
3. Grant precise location, stand under open sky

iOS: dispatch the **iOS build** workflow, download `groundspeed-ios-unsigned`,
then sign/sideload (AltStore, Sideloadly, or Xcode).

## Precision notes

- Fixes stream at `LocationAccuracy.best`, `distanceFilter: 0`
- Samples with speed accuracy worse than ±6 m/s are rejected outright
- Accepted speeds pass through a scalar Kalman filter
  (process noise from an acceleration model, measurement noise from the
  receiver-reported speed accuracy)
- Distance uses haversine deltas gated by horizontal accuracy (< 50 m) and
  sane time deltas (< 30 s) to kill teleport artifacts
- Digits use tabular figures so the readout never jitters horizontally
