#!/bin/bash
# ComfyUI entrypoint — auto-imports the bundled workflow on first start,
# downloads model stack from HuggingFace if missing, and patches
# comfy_kitchen's PEP585 list[int] annotations at runtime (workaround
# for https://github.com/comfyanonymous/ComfyUI/issues — comfy_kitchen
# 0.2.35 uses list[int] which torch.library.infer_schema rejects).
set -e

COMFY_DIR="/workspace/ComfyUI"
WORKFLOW_SRC="/workspace/workflow.json"

echo "[entrypoint] ComfyUI: $COMFY_DIR"
echo "[entrypoint] GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'none')"

# 0. Patch comfy_kitchen PEP585 list[int] → typing.List[int] (workaround for torch 2.x)
if python3 -c "import comfy_kitchen" 2>/dev/null; then
    python3 - <<'PY'
import os, re, sys
try:
    import comfy_kitchen
    p = os.path.join(os.path.dirname(comfy_kitchen.__file__), "backends", "eager", "conv3d.py")
    if not os.path.isfile(p):
        print("[patch] comfy_kitchen path not found:", p)
        sys.exit(0)
    src = open(p).read()
    orig = src
    if "from typing import List" not in src and "import torch\n" in src:
        src = src.replace("import torch\n", "from typing import List\nimport torch\n", 1)
    src = re.sub(r"\blist\[(int|bool|str|float)\]", r"List[\1]", src)
    if src != orig:
        open(p, "w").write(src)
        print(f"[patch] patched comfy_kitchen/conv3d.py at {p}")
    else:
        print(f"[patch] comfy_kitchen/conv3d.py already OK (no change)")
except Exception as e:
    print(f"[patch] WARNING: comfy_kitchen patch skipped: {type(e).__name__}: {e}")
PY
else
    echo "[patch] comfy_kitchen not installed; skipping PEP585 patch"
fi

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
