ARG VLLM_OMNI_VERSION=v0.28.0
FROM vllm/vllm-omni:${VLLM_OMNI_VERSION}

ENV MODEL_NAME="Wan-AI/Wan2.2-I2V-A14B-Diffusers" \
    PORT="8091" \
    HEALTH_CHECK_PATH="/health" \
    VLLM_OMNI_VIDEO_SYNC_TIMEOUT="86400" \
    PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True" \
    HF_HOME="/runpod-volume/huggingface-cache/hub" \
    HUGGINGFACE_HUB_CACHE="/runpod-volume/huggingface-cache/hub"

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8091

ENTRYPOINT []
CMD ["/start.sh"]
