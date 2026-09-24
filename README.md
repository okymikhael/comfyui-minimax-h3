# MiniMax-H3 ComfyUI Stack (shahzaib632_okymikhael)

ComfyUI + custom nodes + all MiniMax H3 Singularity DualSampling model weights, pre-wired to the official `MiniMax_H3_Singularity_DualSampling_The_AI_Brief_EN` workflow.

## Contents

- `Dockerfile` — base `nvidia/cuda:12.1.0-devel-ubuntu22.04`. Downloads all model weights at build time. Final image ~70-80GB.
- `workflow.json` — the DualSampling workflow (auto-imported on container start).
- `entrypoint.sh` — copies the workflow into ComfyUI's `workflows/` dir so it shows up in the UI's "Load" dropdown.

## What's inside the image

| File | Size | Source |
|---|---|---|
| `Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors` | 34 GB | WarmBloodAban/Minimax-h3_Singularity |
| `qwen3vl_32b_minimax_h3_int8_convrot.safetensors` | (varies) | Comfy-Org/MiniMax-H3 |
| `minimax_h3_video_vae_fp16.safetensors` | (varies) | Comfy-Org/MiniMax-H3 |
| `minimax_h3_audio_vae_fp32.safetensors` | (varies) | Comfy-Org/MiniMax-H3 |
| `minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` | (varies) | Comfy-Org/MiniMax-H3 |
| `minimax_h3_lms_v1.0_r64.safetensors` | (varies) | Alissonerdx/Minimax-H3-ComfyUI |
| `h3-realism-people-t2v-i2v-r2v.safetensors` | (varies) | fal/Minimax-H3-Realism-People-LoRA |

**Custom nodes:** ComfyUI-VideoHelperSuite (Kosinkadink), ComfyUI-KJNodes (kijai), ComfyUI-rgthree (rgthree).

## Build

```bash
docker build -t kymkhl24/comfyui-minimax-h3:latest .
```

Recommended build environment: GPU host (RunPod, Vast.ai, local CUDA machine). Disk needs ~80GB free.

## Run

```bash
docker run --gpus all -p 8188:8188 kymkhl24/comfyui-minimax-h3:latest
```

Open `http://localhost:8188` → workflow loads automatically.

## Notes

- Image is large (~70-80GB) — 34GB diffusion model + ~10GB text encoder + VAEs + LoRAs.
- All model URLs are public HuggingFace repositories (no auth needed).
- Workflow was sourced from the YouTube video linked in the original spec.
- RunPod tip: use a Network Volume for `/workspace/ComfyUI/output` to persist generations across pod restarts.
- shahzaib632_okymikhael
