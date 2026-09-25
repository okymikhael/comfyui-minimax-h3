#!/bin/bash
# download-models.sh — fetches all 7 MiniMax-H3 model files at runtime.
# Idempotent: skips files that already exist (so subsequent container starts are fast).
# Speed: HF CDN is global, downloads ~50 MB/s typical.
#
# Strategy: prefer the user's private HF dataset (fast, authenticated),
# fall back to public HF repos if dataset is unavailable.
set -u

MODELS="/workspace/ComfyUI/models"
mkdir -p "$MODELS"/{diffusion_models,text_encoders,vae,loras}

# Token (if present in env) — used to access the private dataset fallback
HF_TOKEN="${HF_TOKEN:-}"

# Try private HF dataset first, fall back to public repos
dl() {
    local dir="$1" url="$2" name="$3" private_path="$4"
    local target="$MODELS/$dir/$name"
    if [ -f "$target" ] && [ "$(stat -c%s "$target" 2>/dev/null || echo 0)" -gt 100000 ]; then
        echo "  [skip] $dir/$name already exists ($(stat -c%s "$target" 2>/dev/null || echo 0) bytes)"
        return 0
    fi
    local final_url="$url"
    if [ -n "$HF_TOKEN" ] && [ -n "$private_path" ]; then
        # Try private dataset first
        local private_url="https://huggingface.co/datasets/okymikhael/comfyui-minimax-h3-models/resolve/main/$private_path"
        if wget --spider --quiet --timeout=10 "$private_url" 2>/dev/null; then
            final_url="$private_url"
            echo "  [fetch-private] $dir/$name  from $private_url"
        fi
    fi
    echo "  [fetch] $dir/$name"
    mkdir -p "$MODELS/$dir"
    local auth_args=()
    if [ -n "$HF_TOKEN" ]; then
        auth_args=(--header="Authorization: Bearer $HF_TOKEN")
    fi
    wget --tries=20 --retry-connrefused --waitretry=5 \
         --timeout=300 --read-timeout=120 \
         --continue \
         "${auth_args[@]}" \
         -O "$target" "$final_url"
    local rc=$?
    echo "  [done] $dir/$name size=$(stat -c%s "$target" 2>/dev/null || echo 0) rc=$rc"
}

echo "=== downloading MiniMax-H3 model stack (first boot only) ==="
echo "    mode: $([ -n "$HF_TOKEN" ] && echo 'authenticated (private dataset preferred)' || echo 'public repos only')"

# 1. Diffusion model (~32 GB) — main singularity weight
dl diffusion_models \
   "https://huggingface.co/WarmBloodAban/Minimax-h3_Singularity/resolve/main/Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors" \
   "Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors" \
   "diffusion_models/Minimax-h3_Singularity_ref2va_v1.3_int8.safetensors"

# 2. Text encoder (Qwen3-VL)
dl text_encoders \
   "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors" \
   "qwen3vl_32b_minimax_h3_int8_convrot.safetensors" \
   "text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"

# 3. VAEs (video + audio)
dl vae \
   "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors" \
   "minimax_h3_video_vae_fp16.safetensors" \
   "vae/minimax_h3_video_vae_fp16.safetensors"
dl vae \
   "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors" \
   "minimax_h3_audio_vae_fp32.safetensors" \
   "vae/minimax_h3_audio_vae_fp32.safetensors"

# 4. LoRAs (turbo + LMS + realism)
dl loras \
   "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors" \
   "minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors" \
   "loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
dl loras \
   "https://huggingface.co/Alissonerdx/Minimax-H3-ComfyUI/resolve/main/loras/minimax_h3_lms_v1.0_r64.safetensors" \
   "minimax_h3_lms_v1.0_r64.safetensors" \
   "loras/minimax_h3_lms_v1.0_r64.safetensors"
dl loras \
   "https://huggingface.co/fal/Minimax-H3-Realism-People-LoRA/resolve/main/h3-realism-people-t2v-i2v-r2v.safetensors" \
   "h3-realism-people-t2v-i2v-r2v.safetensors" \
   "loras/h3-realism-people-t2v-i2v-r2v.safetensors"

echo "=== model download complete ==="
ls -lah "$MODELS"/{diffusion_models,text_encoders,vae,loras}
