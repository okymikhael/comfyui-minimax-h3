#!/bin/bash
# ComfyUI entrypoint — auto-imports the bundled workflow on first start.
set -e

WORKFLOW_SRC="/workspace/workflow.json"
COMFY_DIR="/workspace/ComfyUI"

echo "[entrypoint] ComfyUI: $COMFY_DIR"
echo "[entrypoint] Workflow: $WORKFLOW_SRC"

# Show model inventory
echo "[entrypoint] === models ==="
for d in diffusion_models text_encoders vae loras; do
    if [ -d "$COMFY_DIR/models/$d" ]; then
        echo "  $d/:"
        ls -lah "$COMFY_DIR/models/$d" | tail -n +2
    fi
done

# Copy workflow into ComfyUI's workflow dir so it shows up in the Load dropdown
mkdir -p "$COMFY_DIR/workflows"
if [ -f "$WORKFLOW_SRC" ]; then
    cp "$WORKFLOW_SRC" "$COMFY_DIR/workflows/MiniMax_H3_DualSampling.json"
    echo "[entrypoint] workflow copied to $COMFY_DIR/workflows/"
else
    echo "[entrypoint] WARNING: workflow.json not found"
fi

echo "[entrypoint] starting ComfyUI..."
exec "$@"
