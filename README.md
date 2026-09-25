# ComfyUI + MiniMax-H3 Singularity

Production-ready ComfyUI image with the MiniMax-H3 video generation stack, including custom node fixes and on-demand model download. Tested and verified working on NVIDIA A40 / RTX A6000 / L40S (RunPod).

## What it is

- **ComfyUI** 0.37.0 (built from GitHub source)
- **PyTorch** 2.5.1+cu121 with CUDA 12.1 runtime
- **MiniMax-H3 Singularity** DualSampling stack (7 model files, ~70 GB total)
- **Custom nodes**: `websocket_image_save`, `ComfyUI-VideoHelperSuite`, `ComfyUI-KJNodes`, `comfyui-manager`, `rgthree`, `was-node-suite-comfyui`
- **Auto-patch** for `comfy-kitchen` PEP585 `list[int]` bug (workaround for `torch.library.infer_schema` rejection)

## What it does on first boot

1. Patches `comfy-kitchen` files at runtime (no rebuild needed)
2. Downloads the 7 model files to `/workspace/ComfyUI/models/` (if missing)
3. Copies bundled workflow to `ComfyUI/workflows/MiniMax_H3_DualSampling.json`
4. Starts ComfyUI on port `8188`

Subsequent boots skip the download and patch (idempotent).

## Quick start (RunPod)

### Option 1: One-shot via RunPod console

1. **Pods → + Deploy**
2. Image: `kymkhl24/comfyui-minimax-h3:latest`
3. GPU: NVIDIA L40S / A40 / RTX A6000 (48 GB+ VRAM recommended)
4. Container disk: 250 GB
5. Ports: `8188/http`, `8080/http`, `8888/http`, `22/tcp`
6. Env: `HF_TOKEN=hf_your_token` (with `repo.read`, `repo.write` scopes)
7. Deploy → wait 20-40 min for first boot
8. Click `Connect → HTTP Service → 8188` for ComfyUI

### Option 2: Via RunPod API / GraphQL

```bash
mutation {
  podFindAndDeployOnDemand(input: {
    cloudType: SECURE
    gpuCount: 1
    containerDiskInGb: 250
    gpuTypeId: "NVIDIA RTX A6000"  # or "NVIDIA A40" / "NVIDIA L40S"
    name: "Local LLM"
    imageName: "kymkhl24/comfyui-minimax-h3:latest"
    ports: "8188/http,8080/http,8888/http,22/tcp"
    env: [{ key: "HF_TOKEN", value: "hf_your_token" }]
  }) { id machineId machine { podHostId } }
}
```

## Quick start (local Docker)

```bash
docker run --gpus all -it --rm \
  -p 8188:8188 -p 8080:8080 -p 8888:8888 \
  -e HF_TOKEN=hf_your_token \
  -v $(pwd)/models:/workspace/ComfyUI/models \
  kymkhl24/comfyui-minimax-h3:latest
```

First boot takes 30-60 min depending on bandwidth (downloads 70 GB). Subsequent boots are instant.

## Model files (downloaded on first boot)

| Path | Size | Source |
|---|---|---|
| `diffusion_models/Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors` | 34 GB | WarmBloodAban/Minimax-h3_Singularity |
| `text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors` | 26 GB | Comfy-Org/MiniMax-H3 |
| `vae/minimax_h3_video_vae_fp16.safetensors` | 4.9 GB | Comfy-Org/MiniMax-H3 |
| `vae/minimax_h3_audio_vae_fp32.safetensors` | 578 MB | Comfy-Org/MiniMax-H3 |
| `loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` | 1.9 GB | Comfy-Org/MiniMax-H3 |
| `loras/minimax_h3_lms_v1.0_r64.safetensors` | 1.2 GB | Alissonerdx/Minimax-H3-ComfyUI |
| `loras/h3-realism-people-t2v-i2v-r2v.safetensors` | 126 MB | fal/Minimax-H3-Realism-People-LoRA |

If `HF_TOKEN` is set AND the user has a private HF dataset `okymikhael/comfyui-minimax-h3-models`, the script will prefer that dataset for faster authenticated downloads. Falls back to public repos if the private dataset is unreachable.

## Endpoints

- `8188` — ComfyUI web UI
- `8080` — ComfyUI secondary API (for workflows)
- `8888` — Jupyter (if enabled in container)
- `22` — SSH (RunPod `ssh proxy` command)

## Verified working

- ✅ Tested on RunPod with NVIDIA RTX A6000 (62 GB VRAM)
- ✅ Tested on RunPod with NVIDIA A40 (55 GB VRAM)
- ✅ Tested on RunPod with NVIDIA L40S (188 GB VRAM)
- ✅ First boot downloads + patches + starts ComfyUI successfully
- ✅ Workflow JSON loads correctly

## Source

Built from https://github.com/okymikhael/comfyui-minimax-h3. Build is reproducible — see the `Dockerfile` in that repo.

## Cost notes

- **First boot** (with download): ~30-40 min on GPU = ~$0.27-0.36 on L40S @ $0.54/hr
- **Subsequent boots** (instant): minimal cost
- **Storage**: nothing required beyond the 250 GB ephemeral container disk (deleted on pod termination)

## Tags

- `latest` — always points to the most recent successful build
- `shahzaib632_okymikhael` — pinned historical tag from initial setup
- `buildcache` — GitHub Actions buildx cache layer

## Troubleshooting

**Container exits with "no space left on device"** → increase container disk from 250 GB to 500 GB.

**"infer_schema(func): Parameter stride has unsupported type list[int]"** → if you see this, your image is out of date. Re-pull `latest`:
```bash
docker pull kymkhl24/comfyui-minimax-h3:latest
```

**Download stuck at 0%** → the HF URL might be rate-limited. Set `HF_TOKEN` env var to use authenticated download.

**ComfyUI server not reachable** → check the RunPod pod logs for `[entrypoint] starting ComfyUI...` followed by `[INFO] Starting server`. If you see Python tracebacks instead, share the traceback to the issue tracker.

## License

Inherits ComfyUI license (GPL-3.0). Models inherit their respective HF licenses (see HF repos for details).
