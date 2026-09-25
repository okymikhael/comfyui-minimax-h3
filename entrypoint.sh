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

# 0. Patch comfy_kitchen PEP585 list[int] → typing.List[int] (workaround for torch 2.x).
# We do NOT pre-check `import comfy_kitchen` because it may fail mid-import (e.g. when torch
# is present but cuda backend can't init in CPU context). We just attempt the file patch
# directly — the script is a no-op if the package or file isn't there.
python3 - <<'PY'
import os, re, sys
try:
    import comfy_kitchen
except Exception as e:
    print(f"[patch] comfy_kitchen import failed ({type(e).__name__}: {e}) — attempting location-based patch")
    import importlib.util
    spec = importlib.util.find_spec("comfy_kitchen")
    if spec is None or spec.origin is None:
        print("[patch] comfy_kitchen not installed; nothing to patch")
        sys.exit(0)
    pkg_dir = os.path.dirname(spec.origin)
else:
    pkg_dir = os.path.dirname(comfy_kitchen.__file__)

candidates = [
    os.path.join(pkg_dir, "backends", "eager", "conv3d.py"),
    os.path.join(pkg_dir, "backends", "cuda", "conv3d.py"),
    os.path.join(pkg_dir, "backends", "eager", "group_norm_pad3d.py"),
    os.path.join(pkg_dir, "backends", "eager", "na.py"),
    os.path.join(pkg_dir, "backends", "eager", "sol_attn.py"),
]
patched = 0
for p in candidates:
    if not os.path.isfile(p):
        continue
    src = open(p).read()
    orig = src
    if "from typing import List" not in src and "import torch\n" in src:
        src = src.replace("import torch\n", "from typing import List\nimport torch\n", 1)
    new_src = re.sub(r"\blist\[(int|bool|str|float)\]", r"List[\1]", src)
    if new_src != orig:
        open(p, "w").write(new_src)
        print(f"[patch] patched: {p}")
        patched += 1
    else:
        print(f"[patch] no change: {p}")
if patched == 0:
    print("[patch] comfy_kitchen PEP585 list[T] → typing.List[T] not needed (already fixed or absent)")
PY

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
