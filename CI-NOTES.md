# CI notes — what this build does

The `.github/workflows/docker-publish.yml` triggers on every push to `main` and:

1. Checks out the repo
2. Sets up Docker Buildx (modern build engine with cache support)
3. Logs into Docker Hub using the secrets you added (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)
4. Extracts image metadata — tags it as `latest` and `shahzaib632_okymikhael`
5. Builds the image from `Dockerfile` and pushes to Docker Hub
6. Caches layers in Docker Hub as `buildcache` for faster future builds

## Where to watch the build
- https://github.com/okymikhael/comfyui-minimax-h3/actions
- Each run takes 30-60 min (model downloads are the slowest part)
- Free public-repo GitHub runners give you 2,000 min/month

## Caveat: GitHub free runners have ~14 GB disk
- The full image is ~80 GB.
- Buildx uses layer-streaming + registry cache, so the runner doesn't keep full layers.
- If the build still fails with "no space left on device", we have two fallbacks:
  1. Use a paid Linux runner (Settings → Billing)
  2. Split into multiple smaller builds and merge

## Manual trigger
You can also kick a rebuild with the "Run workflow" button on the Actions tab.
