# batta-vllm-omni-lb

RunPod Load Balancer endpoint for:

`Wan-AI/Wan2.2-I2V-A14B-Diffusers`

This image starts vLLM-Omni directly on `0.0.0.0:8091`, so native
`/v1/videos` and `/v1/videos/sync` multipart APIs can be called without the
queue-worker JSON wrapper.

## RunPod deployment

Deploy this GitHub repository with **Deploy from a GitHub repository**.

Recommended initial settings:

- Endpoint type: **Load Balancer**
- GPU: **H100 80GB**
- Min workers: `1` while testing
- Max workers: `1` while testing
- Expose HTTP ports: `8091/http`
- `PORT=8091`
- `HEALTH_CHECK_PATH=/health`
- `MODEL_NAME=Wan-AI/Wan2.2-I2V-A14B-Diffusers`
- `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`
- `HF_TOKEN`: set only in RunPod secrets/environment if needed. Never commit it.
- Network Volume is optional. If attached, HF cache defaults to:
  `/runpod-volume/huggingface-cache/hub`

Do not put RunPod API keys or Hugging Face tokens in this repository.

## Important: test the existing Queue endpoint first

The official `runpod-workers/worker-vllm-omni` worker documents base64 uploads
for multipart routes using `<field>_b64`. For image-to-video this means
`image_b64`.

Before creating a new Load Balancer endpoint, try:

```bash
chmod +x scripts/test_existing_queue_image_b64.sh
scripts/test_existing_queue_image_b64.sh /home/ubuntu/test.jpg
```

If this succeeds, you may not need the Load Balancer endpoint.

## Health test for Load Balancer

```bash
export ENDPOINT_ID="YOUR_LOAD_BALANCER_ENDPOINT_ID"
export RUNPOD_API_KEY="YOUR_RUNPOD_API_KEY"

curl -i \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  "https://${ENDPOINT_ID}.api.runpod.ai/health"
```

## I2V sync test for Load Balancer

```bash
chmod +x scripts/test_load_balancer_i2v.sh
ENDPOINT_ID="YOUR_ENDPOINT_ID" RUNPOD_API_KEY="YOUR_KEY" \
  scripts/test_load_balancer_i2v.sh /home/ubuntu/test.jpg
```
