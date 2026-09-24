# MiniMax-H3 ComfyUI Stack (shahzaib632_okymikhael)

ComfyUI + custom nodes + the MiniMax H3 Singularity DualSampling workflow. Models are **fetched on first container start** from HuggingFace CDN — keeps the image small (~15 GB) and lets it build on free runners.

## Contents

| File | Purpose |
|---|---|
| `Dockerfile` | `nvidia/cuda:12.1.0-devel-ubuntu22.04` base; installs ComfyUI + 3 custom nodes; ~15 GB final image |
| `download-models.sh` | Runtime script — fetches all 7 model files (~66 GB) from HuggingFace on first boot |
| `entrypoint.sh` | Runs `download-models.sh`, copies `workflow.json` into ComfyUI's workflows dir, starts ComfyUI |
| `workflow.json` | The MiniMax_H3_Singularity_DualSampling_The_AI_Brief_EN workflow (auto-imported) |
| `.github/workflows/docker-publish.yml` | Builds image on every push to `main` + pushes to `kymkhl24/comfyui-minimax-h3` on Docker Hub |
| `CI-NOTES.md` | Notes about the CI build |

## How the image is built

Image is **~15 GB** (small enough for GitHub Actions free runners — no paid compute needed).

Build steps:
1. Pull `nvidia/cuda:12.1.0-devel-ubuntu22.04` (~2.5 GB)
2. `apt-get install` git/wget/curl/etc.
3. `git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git`
4. `pip install torch+torchvision+torchaudio` (PyTorch cu121, ~2.5 GB)
5. `pip install -r requirements.txt` (~500 MB)
6. Clone 3 custom nodes (VideoHelperSuite, KJNodes, rgthree), shallow clones with retry
7. Copy `download-models.sh`, `entrypoint.sh`, `workflow.json` from build context

Total: ~13-15 GB final image. No model weights baked in.

## How models are fetched at runtime

On first container start, `entrypoint.sh` calls `download-models.sh`, which downloads from HuggingFace:

| File | Size | URL |
|---|---|---|
| `Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors` | 34 GB | WarmBloodAban/Minimax-h3_Singularity |
| `qwen3vl_32b_minimax_h3_int8_convrot.safetensors` | 27 GB | Comfy-Org/MiniMax-H3 |
| `minimax_h3_video_vae_fp16.safetensors` | 5 GB | Comfy-Org/MiniMax-H3 |
| `minimax_h3_audio_vae_fp32.safetensors` | 600 MB | Comfy-Org/MiniMax-H3 |
| `minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` | 2 GB | Comfy-Org/MiniMax-H3 |
| `minimax_h3_lms_v1.0_r64.safetensors` | 1.2 GB | Alissonerdx/Minimax-H3-ComfyUI |
| `h3-realism-people-t2v-i2v-r2v.safetensors` | 130 MB | fal/Minimax-H3-Realism-People-LoRA |

**Total download: ~70 GB.** First boot takes 30-60 min depending on bandwidth. Subsequent boots are instant (script skips existing files).

## Use in RunPod

1. Go to https://hub.docker.com/r/kymkhl24/comfyui-minimax-h3 — wait for the build to complete (latest commit on `main` triggers a build, ~30 min on free runner).
2. In RunPod, configure a new pod:
   - **Container image:** `kymkhl24/comfyui-minimax-h3:latest`
   - **Container disk:** 250 GB (or more — needs room for the model downloads)
   - **Network volume mount:** `/workspace` (persistent across restarts — saves re-download on next boot)
   - **Exposed ports:** 8188 (ComfyUI), 8888 (Jupyter if added later), 22 (SSH)
3. Boot the pod — first start takes 30-60 min while models download. ComfyUI is then at port 8188.

## Build locally

```bash
git clone https://github.com/okymikhael/comfyui-minimax-h3.git
cd comfyui-minimax-h3
docker build -t kymkhl24/comfyui-minimax-h3:latest .
```

Run: `docker run --gpus all -p 8188:8188 kymkhl24/comfyui-minimax-h3:latest`

## Notes

- All model URLs are public HuggingFace repositories (no auth needed).
- Workflow was sourced from the YouTube video linked in the original spec.
- RunPod tip: use a Network Volume for `/workspace` to persist generations + model cache across pod restarts.
- shahzaib632_okymikhael
