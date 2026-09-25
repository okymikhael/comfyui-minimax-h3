# ComfyUI + MiniMax-H3 — Project Summary

**Date**: 2026-09-25
**Status**: ✅ Verified working

## What was built

A production-ready Docker image for running ComfyUI with the MiniMax-H3 Singularity video generation stack on RunPod cloud GPUs.

## Image location

- **Docker Hub**: `kymkhl24/comfyui-minimax-h3:latest`
- **Size**: 7.96 GB (bootstrap image; 70 GB models downloaded at runtime)
- **Digest**: `sha256:bef13c0f5ef668998f84047...`
- **Tags**: `latest`, `v1.0-working`, `shahzaib632_okymikhael`, `buildcache`

## How to deploy (next time)

### 1-Click via RunPod console

1. Go to https://www.runpod.io/console/pods
2. Click `+ Deploy`
3. **Image name**: `kymkhl24/comfyui-minimax-h3:latest`
4. **GPU**: NVIDIA A40 (62 GB) @ $0.54/hr, or L40S (188 GB) @ $0.81/hr, or RTX A6000 (62 GB) @ $0.36/hr
5. **Container disk**: 250 GB (for the downloaded models)
6. **Expose HTTP ports**: 8188 (ComfyUI), 8080, 8888, 22
7. **Environment variables**:
   - `HF_TOKEN` = your HuggingFace token (with `repo.read` + `repo.write` scopes)
8. Click `Deploy`
9. Wait 20-40 minutes (first boot downloads 70 GB models + auto-patches comfy_kitchen)
10. Click `Connect` → `HTTP Service` → port `8188`

### 1-Liner via GraphQL

```graphql
mutation {
  podFindAndDeployOnDemand(input: {
    cloudType: SECURE
    gpuCount: 1
    containerDiskInGb: 250
    gpuTypeId: "NVIDIA RTX A6000"
    name: "Local LLM"
    imageName: "kymkhl24/comfyui-minimax-h3:latest"
    ports: "8188/http,8080/http,8888/http,22/tcp"
    env: [{ key: "HF_TOKEN", value: "hf_YOUR_TOKEN_HERE" }]
  }) { id machineId machine { podHostId } }
}
```

Endpoint: `https://api.runpod.io/graphql` (POST with `Authorization: Bearer YOUR_RUNPOD_API_KEY`)

## Endpoints after deploy

| Port | Service | URL |
|---|---|---|
| 8188 | ComfyUI web UI | http://pod-XXXXXX-YYYY-ZZZZZ.proxy.runpod.net |
| 8080 | ComfyUI API | http://pod-XXXXXX-YYYY-ZZZZZ.proxy.runpod.net:8080 |
| 8888 | Jupyter | http://pod-XXXXXX-YYYY-ZZZZZ.proxy.runpod.net:8888 |
| 22 | SSH | `ssh pod-host-id@ssh.runpod.io` |

## Cost estimates (per hour)

- NVIDIA RTX A6000: $0.36/hr
- NVIDIA A40: $0.54/hr
- NVIDIA L40S: $0.81/hr

First boot = 30-40 min × hourly rate (download 70 GB models).

Subsequent boots = instant (models cached in container disk).

To minimize costs: **stop pod when done**, **don't terminate** (preserves container disk).

## Source code

- GitHub: https://github.com/okymikhael/comfyui-minimax-h3
- Tag: `v1.0-working` (matches the Docker Hub image)
- Files in repo:
  - `Dockerfile` — image definition
  - `entrypoint.sh` — runtime patch + model download + ComfyUI start
  - `download-models.sh` — model fetching logic (with private HF dataset preference)
  - `README.md` — full documentation
  - GitHub Actions workflow — auto-build + auto-push on push to main

## Models (downloaded at runtime)

Total: ~70 GB. Sourced from HuggingFace.

| Path | Size | Source |
|---|---|---|
| `diffusion_models/Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors` | 34 GB | WarmBloodAban/Minimax-h3_Singularity |
| `text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors` | 26 GB | Comfy-Org/MiniMax-H3 |
| `vae/minimax_h3_video_vae_fp16.safetensors` | 4.9 GB | Comfy-Org/MiniMax-H3 |
| `vae/minimax_h3_audio_vae_fp32.safetensors` | 578 MB | Comfy-Org/MiniMax-H3 |
| `loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` | 1.9 GB | Comfy-Org/MiniMax-H3 |
| `loras/minimax_h3_lms_v1.0_r64.safetensors` | 1.2 GB | Alissonerdx/Minimax-H3-ComfyUI |
| `loras/h3-realism-people-t2v-i2v-r2v.safetensors` | 126 MB | fal/Minimax-H3-Realism-People-LoRA |

## Critical fixes baked into image

1. **comfy_kitchen PEP585 patch** — comfy_kitchen 0.2.35 uses `list[int]` builtin generics which `torch.library.infer_schema` rejects. The `entrypoint.sh` patches the package files at runtime using `importlib.util.find_spec` (location-based, no import required). Idempotent — no-op if comfy_kitchen ships a fix in a future version.

2. **HF private dataset preference** — if `HF_TOKEN` env var is set AND a private dataset `okymikhael/comfyui-minimax-h3-models` exists, the entrypoint prefers that (faster authenticated CDN). Falls back to public repos if private unreachable.

3. **Workflow auto-load** — bundled `workflow.json` is copied to `/workspace/ComfyUI/workflows/MiniMax_H3_DualSampling.json` on first boot, so it appears in the Load dropdown immediately.

## Verified pods (Sept 25, 2026)

| Pod ID | GPU | Status |
|---|---|---|
| `vltoprpslnfb8j` | NVIDIA RTX A6000 | ✅ ComfyUI started, then stopped |
| `4o45192laugpza` | NVIDIA A40 | Stopped (used for first test) |
| `4v5c7f02ngyo2t` | NVIDIA L40S | Stopped (original, host unavailable) |

All 3 pods are currently in `EXITED` state — no GPU cost.

## Re-deploy steps (when Oky comes back)

1. Open RunPod console: https://www.runpod.io/console/pods
2. Click `+ Deploy`
3. Use settings above
4. Wait 30-40 min for first boot
5. Click `Connect` → ComfyUI loads

## Files in this project's repo

```
/tmp/comfyui-push/
├── Dockerfile               # image build definition
├── entrypoint.sh            # runtime patch + download + start
├── download-models.sh       # model fetching script
├── README.md                # user-facing docs
├── workflow.json            # ComfyUI workflow file
└── .github/workflows/
    └── docker-publish.yml   # auto-build + push on commit
```

## Git history (key commits)

```
d470e96  docs: full README with quickstart, model list, troubleshooting
72ba338  fix: patch comfy_kitchen directly via location, not via pre-import check
ceb225b  feat: prefer private HF dataset for model downloads
e67daf3  fix: move comfy_kitchen PEP585 patch from Dockerfile to entrypoint.sh
1e1c7e1  fix: patch comfy_kitchen PEP585 list[int] for torch 2.x infer_schema
b8ee636  refactor: switch to bootstrap image (small + on-demand model download)
```

## HF dataset (private)

`okymikhael/comfyui-minimax-h3-models` — private HF dataset containing the 7 model files. Used by `download-models.sh` for faster authenticated download (when `HF_TOKEN` is set). Created 2026-09-25.

## SSH access

To SSH into a running pod, use the `ssh proxy` command from the pod's JSON:
```bash
ssh vltoprpslnfb8j-64410d89@ssh.runpod.io
```

SSH key required: `Mavis@GandonganPC` (already registered on RunPod).

## Account info

- RunPod account: `okymikhael@gmail.com`
- RunPod user ID: `user_3JgUJbZbk7ai14pv5iRcbeNpqdL`
- Docker Hub: `kymkhl24`
- GitHub: `okymikhael/comfyui-minimax-h3`
- HF: `okymikhael/comfyui-minimax-h3-models` (private)
