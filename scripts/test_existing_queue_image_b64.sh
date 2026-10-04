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
  KEY="$(systemctl show batta-market.service -p Environment --value \
    | tr " " "\n" \
    | sed -n "s/^RUNPOD_API_KEY=//p" \
    | head -1)"
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
        "image_b64": raw,
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
  echo "$R"
  STATUS="$(python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("status",""))
except Exception:
    print("")' <<<"$R")"
  case "$STATUS" in
    COMPLETED|FAILED|CANCELLED|TIMED_OUT) break ;;
  esac
  sleep 3
done
