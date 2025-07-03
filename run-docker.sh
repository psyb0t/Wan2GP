#!/usr/bin/env bash
set -euo pipefail

# Build the Docker image
docker build --build-arg CUDA_ARCHITECTURES="8.6" -t psyb0t/wan2gp .

# detect whether we need sudo
if [ "$EUID" -ne 0 ]; then
    SUDO='sudo'
else
    SUDO=''
fi

# 1) Check for nvidia-container-runtime in docker runtimes
if ! docker info 2>/dev/null | grep -q 'Runtimes:.*nvidia'; then
    echo "⚠️  NVIDIA Docker runtime not found. Installing nvidia-docker2..."
    $SUDO apt-get update
    $SUDO apt-get install -y curl ca-certificates gnupg
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | $SUDO apt-key add -
    distribution=$(
        . /etc/os-release
        echo $ID$VERSION_ID
    )
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list |
        $SUDO tee /etc/apt/sources.list.d/nvidia-docker.list
    $SUDO apt-get update
    $SUDO apt-get install -y nvidia-docker2
    echo "🔄 Restarting Docker service..."
    $SUDO systemctl restart docker
    echo "✅ NVIDIA Docker runtime installed."
else
    echo "✅ NVIDIA Docker runtime found."
fi

# 2) Prepare cache dirs & build volume mounts
cache_dirs=(numba matplotlib huggingface torch)
cache_mounts=()
for d in "${cache_dirs[@]}"; do
    mkdir -p "$HOME/.cache/$d"
    chmod 700 "$HOME/.cache/$d"
    cache_mounts+=(-v "$HOME/.cache/$d:/home/user/.cache/$d")
done

# 3) Run your container with expanded mounts
docker run --rm -it \
    --name wan2gp \
    --gpus all \
    --runtime=nvidia \
    -p 7860:7860 \
    -v "$(pwd):/workspace" \
    "${cache_mounts[@]}" \
    psyb0t/wan2gp \
    --profile 2 \
    --attention sage \
    --compile \
    --perc-reserved-mem-max 1.0
