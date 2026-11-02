# NAZAR interface contract (v2)

Every NAZAR part is built against this file. If two parts disagree, this file wins.
Everything runs on one Mac, offline. No cloud calls anywhere.

```
 ESP32 (nazar-firmware) ──USB serial 115200, JSON lines──▶ NAZAR Console (nazar-console, Mac app)
                         ◀────────── text commands ─────────
 NAZAR Console ──HTTP 127.0.0.1:8765──▶ nazar-vision  (PatchCore washer inspection)
 NAZAR Console ──HTTP 127.0.0.1:8766──▶ nazar-agent   (root-cause statistics + 8D report, local LLM)
```

---

## 1. Serial link: ESP32 → Mac

115200 baud, 8N1, `\n` line ends. **Every line is one JSON object** with a `"t"` (type) field.
The host ignores lines that are not valid JSON (boot ROM noise) and types it does not know.

### 1.1 Telemetry, every 100 ms

```json
{"t":"tel","ms":183402,"v":11.92,"ma":312.4,"vib":0.042,"vpk":0.110,"lux":812.5,"temp":34.6,
 "ir":0,"parts":17,"rej":3,"gate":0,"belt":1,"mode":"RUN"}
```

| Key | Unit | Meaning |
|---|---|---|
| `ms` | ms | `millis()` on the ESP32 |
| `v`, `ma` | V, mA | INA219 bus voltage and current of the belt motor |
| `vib`, `vpk` | g | MPU-6050 at 200 Hz: RMS and peak of (\|a\| − slow average of \|a\|) over the last 100 ms |
| `lux` | lx | BH1750 light level in the tunnel |
| `temp` | °C | DS18B20 on the motor can (read ~1/s, last value repeated) |
| `ir` | 0/1 | FC-51: 1 while a part is in front of it (20 ms debounce) |
| `parts`, `rej` | count | ESP32 counters since boot (they reset when the board reboots; the host keeps its own totals) |
| `gate` | 0/1 | 1 while the reject gate is open |
| `belt` | 0/1 | 1 while the relay lets the belt run |
| `mode` | text | `RUN`, `INSPECT` (part stopped under camera, waiting for a verdict), `HOLD`, `STOP` |

**A sensor that is missing or failing is left out** of the line (no key). The host shows "No signal" for it.

### 1.2 Other messages

| Message | When |
|---|---|
| `{"t":"hello","fw":"2.0.0","sensors":{"ina219":true,"mpu6050":true,"bh1750":false,"ds18b20":true},"cfg":{...}}` | At boot, on `PING`, and whenever a sensor appears or disappears. `cfg` = current timing config (§2.2). |
| `{"t":"part","n":18}` | Part `n` passed the IR sensor. |
| `{"t":"inspect","n":18}` | Part `n` is now **stopped under the camera** (belt off, `mode:"INSPECT"`). Host should take the photo. |
| `{"t":"go","n":18,"res":"pass"}` | Belt restarted after inspection. `res` = `pass`, `reject`, `hold-released`, `timeout` (no verdict in `wait_ms`). |
| `{"t":"gate","n":18}` | Gate fired for part `n`. |
| `{"t":"ack","cmd":"HOLD"}` | A command was accepted. |
| `{"t":"err","msg":"unknown command FOO"}` | A command was refused. |
| `{"t":"pong"}` | Reply to `PING` (always followed by a `hello`). |
| `{"t":"log","msg":"..."}` | Free text for the serial monitor. |

## 2. Serial link: Mac → ESP32

Plain text, one command per line, case-insensitive.

### 2.1 Commands

| Command | Effect |
|---|---|
| `PING` | → `pong` + `hello` |
| `PASS` | Verdict for the part under the camera: belt restarts after `dwell_ms` has passed since the stop. |
| `FAIL` | Verdict REJECT: belt restarts, gate fires after `gate_ms` of belt **running** time. |
| `HOLD` | Line goes `mode:"HOLD"`, belt stays off until `RESUME`. Used for an unsure part or by the operator. |
| `RESUME` | Leave HOLD. If a part was held under the camera it is released as `hold-released` (no gate). |
| `STOP` | Operator stop: `mode:"STOP"`, belt off. Inspection and gate timers freeze. |
| `START` | Leave STOP, continue exactly where it was. |
| `REJECT` | Fire the gate once, now (manual test). |
| `BELT 1` / `BELT 0` | Manual belt on/off, only honoured in `STOP` mode (bring-up). |
| `RESET` | Counters to 0. |
| `SET <key> <int>` | Change timing config (§2.2). → `ack` + `hello` with new `cfg`. |

### 2.2 Timing config (all integers, ms unless noted)

| Key | Default | Meaning |
|---|---|---|
| `stop_ms` | 150 | After the IR edge, belt runs this long so the washer is centred under the camera, then stops. |
| `dwell_ms` | 1200 | Minimum stop time under the camera. |
| `wait_ms` | 5000 | No verdict by then → `go` with `res:"timeout"`, part passes. The line never waits forever on the AI. |
| `gate_ms` | 800 | Belt running time from restart until the gate fires for a FAIL. |
| `gate_open_ms` | 600 | How long the gate stays open. |
| `stops` | 1 | 1 = stop-and-inspect, 0 = belt never stops for inspection (continuous). |

The host sends its saved values with `SET` after every connect.

## 3. Hardware pin map (wiring v5 + relay)

| Signal | ESP32 GPIO |
|---|---|
| I²C SDA / SCL | 21 / 22 — INA219 0x40, MPU-6050 0x68, BH1750 0x23 |
| FC-51 OUT (LOW = part present) | 18 |
| DS18B20 DQ (4.7 kΩ pull-up to 3V3) | 4 |
| MG996R signal (via 330 Ω) | 13 |
| Belt relay IN (active LOW: LOW = run, released/INPUT = stop) | 26 |

## 4. Vision service — `127.0.0.1:8765`

Python standard library HTTP server. Every response is JSON with `Access-Control-Allow-Origin: *`; `OPTIONS` is answered (the console page has origin `null`). The service never crashes on a bad request; errors are `{"ok":false,"error":"..."}` with HTTP 200.

| Endpoint | Body | Returns |
|---|---|---|
| `GET /health` | — | `{"ok":true,"model":"patchcore-wrn50","hold":0.33,"reject":0.44,"bank":4096,"version":"2.0.0"}` |
| `POST /inspect` (optional `?hold=&reject=` overrides) | JPEG or PNG bytes | `{"ok":true,"verdict":"PASS"\|"HOLD"\|"REJECT"\|"NO_PART","score":0.37,"hold":0.33,"reject":0.44,"ms":52,"crop":"<base64 PNG>","heatmap":"<base64 PNG>","box":[x,y,w,h]}` |
| `POST /capture?label=good\|defect&kind=scratch` | JPEG or PNG bytes | Saves to `data/capture/<label>/…`; `{"ok":true,"saved":"data/capture/good/…jpg"}` |

`NO_PART` means no washer was found; it is **never** treated as a defect.

## 5. Agent service — `127.0.0.1:8766`

Same rules as §4 (CORS, never crash, errors as `{"ok":false}`).

| Endpoint | Body | Returns |
|---|---|---|
| `GET /health` | — | `{"ok":true,"llm":"installed"\|"loaded"\|"missing","busy":false,"version":"2.0.0"}` |
| `POST /report` | JSON below | Statistics + 8D report |

Request:

```json
{"lang":"en","use_llm":true,"source":"live",
 "limits":{"vib":{"amber":0.08,"red":0.15},"lux":{"amber":300,"red":120},"temp":{"amber":45,"red":60},"ma":{"amber":700,"red":1000}},
 "fix_at":1762070400000, "fix_note":"tightened motor mount",
 "inspections":[{"at":1762069800123,"n":17,"verdict":"REJECT","score":0.52,"vib":0.11,"vpk":0.31,"lux":805,"temp":36.1,"ma":330,"v":11.9}]}
```

(`at` and `fix_at` are Unix ms. `lang` is `en` or `hi`. `fix_at`/`fix_note` optional.)

Response:

```json
{"ok":true,"enough":true,"writer":"llm"|"template","ms":15800,
 "stats":{"n":120,"bad":14,"rate":0.117,
          "pchart":[{"from":..,"to":..,"n":20,"bad":3,"p":0.15,"ucl":0.33,"lcl":0}],
          "strata":[{"factor":"vib","label":"Motor shaking","high_n":30,"high_bad":10,"low_n":90,"low_bad":4,"ratio":7.5,"p_value":0.0004}],
          "cause":"vib",
          "before_after":{"before_n":80,"before_bad":12,"after_n":40,"after_bad":2,"cause_before":0.4,"cause_after":0.05}},
 "report":{"title":"Rejects rise when the motor shakes","summary":"...",
           "sections":[{"id":"D1","title":"Team","body":"..."}, … "D8"]}}
```

`enough:false` (fewer than 20 inspections) returns `stats` plus a `"message"` and no report.

## 6. Inspection log the console keeps

One row per inspected part (also exported as CSV, same field names):
`at, n, verdict, score, ms, v, ma, vib, vpk, lux, temp` — the sensor values are the latest telemetry at the moment of the photo.
