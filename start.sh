#!/usr/bin/env bash
set -euo pipefail

MODEL_NAME="${MODEL_NAME:-Wan-AI/Wan2.2-I2V-A14B-Diffusers}"
PORT="${PORT:-8091}"

echo "Starting vLLM-Omni Load Balancer server"
echo "MODEL_NAME=${MODEL_NAME}"
echo "PORT=${PORT}"

args=(
  serve
  "${MODEL_NAME}"
  --omni
  --host 0.0.0.0
  --port "${PORT}"
)

if [[ -n "${OMNI_EXTRA_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra=( ${OMNI_EXTRA_ARGS} )
  args+=( "${extra[@]}" )
fi

exec vllm "${args[@]}"
