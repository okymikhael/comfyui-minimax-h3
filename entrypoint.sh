#!/bin/bash
# ComfyUI entrypoint — auto-imports the bundled workflow on first start.
set -e

COMFY_DIR="/workspace/ComfyUI"
WORKFLOW_SRC="/workspace/workflow.json"

echo "[entrypoint] ComfyUI: $COMFY_DIR"
echo "[entrypoint] GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'none')"

# 1. Fetch models only if not already present
if [ ! -f "$COMFY_DIR/models/diffusion_models/Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors" ]; then
    echo "[entrypoint] first boot — fetching model stack (~70GB)..."
    /usr/local/bin/download-models.sh
else
    echo "[entrypoint] models already present, skipping download"
fi

# 2. Copy workflow.json into ComfyUI's workflow dir so it shows in the Load dropdown
mkdir -p "$COMFY_DIR/workflows"
if [ -f "$WORKFLOW_SRC" ]; then
    cp "$WORKFLOW_SRC" "$COMFY_DIR/workflows/MiniMax_H3_DualSampling.json"
    echo "[entrypoint] workflow copied to $COMFY_DIR/workflows/"
fi

# 3. Show final model inventory
echo "[entrypoint] === final model inventory ==="
for d in diffusion_models text_encoders vae loras; do
    if [ -d "$COMFY_DIR/models/$d" ]; then
        echo "  $d/:"
        ls -lah "$COMFY_DIR/models/$d" | tail -n +2 | sed 's/^/    /'
    fi
done

echo "[entrypoint] starting ComfyUI..."
exec "$@"
