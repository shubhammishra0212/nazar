# NAZAR — Next-gen AI for Zero-defect Assurance & Root-cause analysis

**Team Parakh · INDUX 5.0 · PS-04 Edge-AI multi-sensor quality inspection**

*Har part pe nazar, har defect ki wajah.* Every part deserves an eye. Every defect has a reason.

A mini conveyor stops each washer under a camera in a light tunnel. An anomaly model trained only on good washers answers **PASS / HOLD / REJECT**; a servo kicks rejects off the belt. At the same moment an ESP32 logs vibration, motor current, motor temperature and tunnel light — so a local root-cause agent can show **why** defects rise (e.g. a loose motor mount), prove it statistically, and draft an 8D report. Everything runs offline on one Mac.

**Read first:** [`docs/NAZAR-START-HERE-System-Overview.pdf`](docs/NAZAR-START-HERE-System-Overview.pdf)

## Repos

| Repo | What | Explainer |
|---|---|---|
| [nazar-hardware](https://github.com/shubhammishra0212/nazar-hardware) | Power, wiring, sensors, conveyor, bring-up order | NAZAR-00-Hardware-Bringup.pdf |
| [nazar-firmware](https://github.com/shubhammishra0212/nazar-firmware) | ESP32: 10 Hz telemetry, stop-and-inspect state machine, reject gate, per-sensor test sketches | NAZAR-01-Firmware.pdf |
| [nazar-vision](https://github.com/shubhammishra0212/nazar-vision) | OpenCV washer finding + PatchCore on ONNX Runtime, local HTTP service :8765 | NAZAR-02-Vision-AI.pdf |
| [nazar-agent](https://github.com/shubhammishra0212/nazar-agent) | p-chart, stratification, Fisher's exact test, before/after, 8D with Llama 3.1 8B on Apple MLX, :8766 | NAZAR-03-Root-Cause-Agent.pdf |
| [nazar-console](https://github.com/shubhammishra0212/nazar-console) | Operator Mac app (Swift + WebKit): live line, camera, verdicts, alarms, 8D view | NAZAR-04-Console-App.pdf |

How the pieces talk: [`CONTRACT.md`](CONTRACT.md).

## Run

Clone the repos side by side, build the console (`nazar-console/app/build.sh`), put the vision models from the [nazar-vision release](https://github.com/shubhammishra0212/nazar-vision/releases) in `nazar-vision/models/`, then double-click `start-nazar.command`.

## Team

Shubham Mishra (lead) · Roshan Kumar Singh · Purvi
