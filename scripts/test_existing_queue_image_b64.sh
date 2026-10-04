#!/usr/bin/env bash
set -euo pipefail

ENDPOINT_ID="${ENDPOINT_ID:-kp9vw3otpuxpg5}"
IMAGE="${1:-/home/ubuntu/test.jpg}"

if [[ ! -f "$IMAGE" ]]; then
  echo "Image not found: $IMAGE" >&2
  exit 1
fi

KEY="${RUNPOD_API_KEY:-}"
if [[ -z "$KEY" ]]; then
  PID="$(systemctl show batta-market.service -p MainPID --value)"
  if [[ -n "$PID" && "$PID" != "0" ]]; then
    KEY="$(sudo sh -c 'tr "\0" "\n" < /proc/'"$PID"'/environ' \
      | sed -n "s/^RUNPOD_API_KEY=//p" \
      | head -1)"
  fi
fi

if [[ -z "$KEY" ]]; then
  echo "RUNPOD_API_KEY not found." >&2
  exit 1
fi

TMP_PAYLOAD="$(mktemp)"
TMP_SUBMIT="$(mktemp)"
trap 'rm -f "$TMP_PAYLOAD" "$TMP_SUBMIT"' EXIT

python3 - "$IMAGE" >"$TMP_PAYLOAD" <<'PY'
import base64, json, pathlib, sys
p = pathlib.Path(sys.argv[1])
raw = base64.b64encode(p.read_bytes()).decode("ascii")
print(json.dumps({
    "input": {
        "task": "video",
        "prompt": "The person moves naturally, subtle head movement, realistic motion",
        "negative_prompt": "blurry, distorted, low quality",
        "input_reference_b64": raw,
        "size": "480x480",
        "num_frames": 17,
        "fps": 8,
        "num_inference_steps": 10,
        "seed": 42
    }
}))
PY

curl -sS \
  -o "$TMP_SUBMIT" \
  -w "HTTP=%{http_code}\n" \
  -X POST \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  "https://api.runpod.ai/v2/${ENDPOINT_ID}/run" \
  --data-binary @"$TMP_PAYLOAD"

echo "=== submit ==="
cat "$TMP_SUBMIT"
echo

JOB_ID="$(python3 - "$TMP_SUBMIT" <<'PY'
import json, pathlib, sys
try:
    d=json.loads(pathlib.Path(sys.argv[1]).read_text())
    print(d.get("id",""))
except Exception:
    print("")
PY
)"

if [[ -z "$JOB_ID" ]]; then
  echo "No job id returned."
  exit 1
fi

for i in $(seq 1 120); do
  echo "=== poll $i ==="
  R="$(curl -sS \
    -H "Authorization: Bearer $KEY" \
    "https://api.runpod.ai/v2/${ENDPOINT_ID}/status/${JOB_ID}")"
  STATUS="$(python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("status",""))
except Exception:
    print("")' <<<"$R")"

  echo "status=$STATUS"

  if [[ "$STATUS" == "COMPLETED" ]]; then
    printf '%s' "$R" > /tmp/omni_last_result.json

    python3 - <<'PY2'
import base64
import json
from pathlib import Path

result = json.loads(Path("/tmp/omni_last_result.json").read_text())

output = result.get("output") or {}
data_b64 = output.get("data_b64")

if not data_b64:
    print("COMPLETED but data_b64 not found")
    print(json.dumps(output, ensure_ascii=False, indent=2)[:4000])
    raise SystemExit(1)

out = Path("/home/ubuntu/omni_test.mp4")
out.write_bytes(base64.b64decode(data_b64))

print(f"SAVED: {out}")
print(f"SIZE: {out.stat().st_size:,} bytes")
print(f"CONTENT_TYPE: {output.get('content_type')}")
PY2

    file /home/ubuntu/omni_test.mp4
    ls -lh /home/ubuntu/omni_test.mp4
    break
  fi

  case "$STATUS" in
    FAILED|CANCELLED|TIMED_OUT)
      echo "$R"
      break
      ;;
  esac
  sleep 3
done
