# Groundspeed

Precision GNSS ground-speed instrument for iOS & Android. Dark, minimal,
single-purpose: a big, filtered, tabular speed readout driven straight off
satellite fixes — with a live trace, session max, haversine distance and
satellite telemetry (Android GNSS status channel).

**Nothing is built locally.** All builds run on GitHub Actions.

## Build pipeline

| Workflow | Trigger | Output |
| --- | --- | --- |
| `CI` | push to `main`, PRs, manual | analyze + tests + release APK artifact |
| `iOS build` | manual (`workflow_dispatch`) | unsigned `.ipa` (re-sign / sideload yourself) |
| `Release` | push a `v*` tag | version-stamped universal + per-ABI APKs → GitHub Release |

Platform folders (`android/`, `ios/` scaffolding) are generated in CI via
`flutter create`; only hand-written sources live in the repo.
Releases stamp the tag into `versionName` (`v0.2.0` → `0.2.0+<run>`).

## Install on your phone

1. Open **Releases** → latest
2. Sideload the **arm64-v8a** APK (any phone from ~2016 onward), or the
   **universal** APK if unsure
3. Grant precise location, stand under open sky

## Features

- Kalman-filtered speed with innovation-adaptive process noise
- Stationary gate (asymmetric hysteresis) pinning parked readings to 0.0
- Heading ring around the readout while in motion
- Satellite sky-view radar by constellation (GPS/GLONASS/Galileo/BeiDou/…)
- Six session stats: max · distance · moving time · avg moving · elevation · climb rate
- Trip saving as GPX (share into Strava/Komoot/Files), local trip history
- Haptic tick whenever your session top speed climbs
- KM/H · MPH · KN units, persisted; imperial shows ft / fpm

## Precision notes

- Fixes stream at `LocationAccuracy.best`, `distanceFilter: 0`
- Samples with speed accuracy worse than ±6 m/s are rejected outright
- Accepted speeds pass through a scalar Kalman filter
  (process noise from an acceleration model, measurement noise from the
  receiver-reported speed accuracy)
- A stationary gate with asymmetric hysteresis pins the readout to exactly
  0 while parked (receivers never report a clean zero): below ~0.25 m/s it
  sleeps quickly; waking requires ~3 s sustained motion above ~0.55 m/s,
  so single-sample multipath spikes never register
- Distance only accumulates while in motion — parked GPS drift can't fake
  meters
- Process noise adapts to the innovation signal: smooth cruise gets
  smoother, hard acceleration stays responsive
- Distance uses haversine deltas gated by horizontal accuracy (< 50 m) and
  sane time deltas (< 30 s) to kill teleport artifacts
- Digits use tabular figures so the readout never jitters horizontally
