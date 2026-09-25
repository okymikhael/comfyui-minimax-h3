FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV GIT_TERMINAL_PROMPT=0

# Install system dependencies (ca-certificates needed for HF downloads)
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

# Clone ComfyUI (shallow clone, fast)
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git
WORKDIR /workspace/ComfyUI

# Install Python deps (torch pinned to cu121 for CUDA 12.1)
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --no-cache-dir -r requirements.txt

# === Patch comfy_kitchen (transitive dep of ComfyUI) ===========================
# comfy-kitchen==0.2.35 uses PEP585 builtin generics like `list[int]` in
# `backends/eager/conv3d.py`, which `torch.library.infer_schema` does not accept
# on torch 2.x stable (cu121). Replace with `typing.List[int]` at the install
# site. Idempotent — no-op if already fixed by a future upstream release.
# See /tmp/comfyui-push/comfy_kitchen.patch for the record diff.
RUN CK_PATH="$(python3 -c 'import comfy_kitchen, os; print(os.path.join(os.path.dirname(comfy_kitchen.__file__), "backends", "eager", "conv3d.py"))')" && \
    echo "[patch] comfy_kitchen file: $CK_PATH" && \
    python3 - <<'PY'
import os, re, sys
import comfy_kitchen
p = os.path.join(os.path.dirname(comfy_kitchen.__file__), "backends", "eager", "conv3d.py")
src = open(p).read()
orig = src
# 1) Ensure `from typing import List` is present
if "from typing import List" not in src:
    if "import torch\n" in src:
        src = src.replace("import torch\n", "from typing import List\nimport torch\n", 1)
    else:
        src = "from typing import List\n" + src
# 2) Replace PEP585 `list[int]` / `list[bool]` / `list[str]` with `List[...]`
src = re.sub(r"\blist\[(int|bool|str|float)\]", r"List[\1]", src)
if src != orig:
    open(p, "w").write(src)
    print(f"[patch] patched: {p}")
else:
    print(f"[patch] no change needed: {p}")
PY

# === Custom nodes ===
# Install all 3 in one RUN to share layer cache + reduce network issues.
# Use --depth 1 for shallow clone. Retry 3x with backoff on transient failure.
WORKDIR /workspace/ComfyUI/custom_nodes
RUN set -eux; \
    for repo in \
        https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
        https://github.com/kijai/ComfyUI-KJNodes.git \
        https://github.com/rgthree/ComfyUI-rgthree.git; do \
        for i in 1 2 3; do \
            git clone --depth=1 "$repo" && break || sleep 5; \
        done; \
    done; \
    pip3 install --no-cache-dir -r ComfyUI-VideoHelperSuite/requirements.txt || true; \
    pip3 install --no-cache-dir -r ComfyUI-KJNodes/requirements.txt || true; \
    pip3 install --no-cache-dir -r ComfyUI-rgthree/requirements.txt || true

# Create model directories (empty — filled by entrypoint.sh on first run)
WORKDIR /workspace/ComfyUI
RUN mkdir -p models/diffusion_models models/text_encoders models/vae models/loras models/workflows

# Bundled: download script + entrypoint + workflow.json
COPY download-models.sh /usr/local/bin/download-models.sh
COPY entrypoint.sh /entrypoint.sh
COPY workflow.json /workspace/workflow.json

RUN chmod +x /usr/local/bin/download-models.sh /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:8188/ >/dev/null || exit 1

EXPOSE 8188
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
