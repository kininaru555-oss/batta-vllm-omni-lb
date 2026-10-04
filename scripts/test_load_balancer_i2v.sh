#!/usr/bin/env bash
set -euo pipefail

ENDPOINT_ID="${ENDPOINT_ID:?Set ENDPOINT_ID}"
IMAGE="${1:-/home/ubuntu/test.jpg}"
KEY="${RUNPOD_API_KEY:?Set RUNPOD_API_KEY}"

if [[ ! -f "$IMAGE" ]]; then
  echo "Image not found: $IMAGE" >&2
  exit 1
fi

curl -sS \
  -o /tmp/omni_lb_test.mp4 \
  -w "HTTP=%{http_code}\n" \
  -H "Authorization: Bearer $KEY" \
  -H "Accept: video/mp4" \
  "https://${ENDPOINT_ID}.api.runpod.ai/v1/videos/sync" \
  -F "prompt=The person moves naturally, subtle head movement, realistic motion" \
  -F "input_reference=@${IMAGE};type=image/jpeg" \
  -F "width=480" \
  -F "height=480" \
  -F "num_frames=17" \
  -F "fps=8" \
  -F "num_inference_steps=10" \
  -F "seed=42"

file /tmp/omni_lb_test.mp4
ls -lh /tmp/omni_lb_test.mp4
