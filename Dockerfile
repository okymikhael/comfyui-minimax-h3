FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
# Disable git SSL verification for transient CI failures
ENV GIT_TERMINAL_PROMPT=0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    ca-certificates \
    python3-pip \
    python3-dev \
    libgl1-mesa-glx \
    libglib2.0-0 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Clone ComfyUI
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git
WORKDIR /workspace/ComfyUI

# Install Python deps (torch pinned to cu121 for CUDA 12.1)
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --no-cache-dir -r requirements.txt

# === Custom nodes ===
# Install all 3 in one RUN to share layer cache + reduce network issues.
# Use --depth=1 for shallow clones. Retry 3x with backoff on transient failure.
WORKDIR /workspace/ComfyUI/custom_nodes
RUN set -eux; \
    for i in 1 2 3; do \
      git clone --depth=1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && break || sleep 5; \
    done; \
    for i in 1 2 3; do \
      git clone --depth=1 https://github.com/kijai/ComfyUI-KJNodes.git && break || sleep 5; \
    done; \
    for i in 1 2 3; do \
      git clone --depth=1 https://github.com/rgthree/ComfyUI-rgthree.git && break || sleep 5; \
    done; \
    pip3 install --no-cache-dir -r ComfyUI-VideoHelperSuite/requirements.txt || true; \
    pip3 install --no-cache-dir -r ComfyUI-KJNodes/requirements.txt || true; \
    pip3 install --no-cache-dir -r ComfyUI-rgthree/requirements.txt || true

# Download all required MiniMax H3 model files
WORKDIR /workspace/ComfyUI/models

# 1. Diffusion model (34GB) — main singularity weight, used by DualSampling workflow
RUN mkdir -p diffusion_models && cd diffusion_models && \
    wget -q -O Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors \
    "https://huggingface.co/WarmBloodAban/Minimax-h3_Singularity/resolve/main/Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors"

# 2. Text encoder (Qwen3-VL)
RUN mkdir -p text_encoders && cd text_encoders && \
    wget -q -O qwen3vl_32b_minimax_h3_int8_convrot.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"

# 3. VAEs (video + audio)
RUN mkdir -p vae && cd vae && \
    wget -q -O minimax_h3_video_vae_fp16.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors" && \
    wget -q -O minimax_h3_audio_vae_fp32.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"

# 4. LoRAs (turbo + LMS + realism)
RUN mkdir -p loras && cd loras && \
    wget -q -O minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors" && \
    wget -q -O minimax_h3_lms_v1.0_r64.safetensors \
    "https://huggingface.co/Alissonerdx/Minimax-H3-ComfyUI/resolve/main/loras/minimax_h3_lms_v1.0_r64.safetensors" && \
    wget -q -O h3-realism-people-t2v-i2v-r2v.safetensors \
    "https://huggingface.co/fal/Minimax-H3-Realism-People-LoRA/resolve/main/h3-realism-people-t2v-i2v-r2v.safetensors"

# Drop the pre-built workflow so it auto-imports on container start
WORKDIR /workspace/ComfyUI
COPY workflow.json /workspace/workflow.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Verify all model files are present and non-empty
RUN echo "=== model inventory ===" && \
    ls -lah /workspace/ComfyUI/models/diffusion_models/ && \
    ls -lah /workspace/ComfyUI/models/text_encoders/ && \
    ls -lah /workspace/ComfyUI/models/vae/ && \
    ls -lah /workspace/ComfyUI/models/loras/ && \
    echo "=== sanity check: no empty .safetensors files ===" && \
    find /workspace/ComfyUI/models -name "*.safetensors" -size 0 -print

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:8188/ >/dev/null || exit 1

EXPOSE 8188
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
