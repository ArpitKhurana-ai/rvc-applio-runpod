# syntax=docker/dockerfile:1

# -------------------------------------------------------------------
# Base: PyTorch + CUDA 12.8 + cuDNN9 (good for RTX 5090 / Blackwell)
# -------------------------------------------------------------------
# If needed you can bump this later (e.g. to 2.9.x) by changing the tag.
FROM pytorch/pytorch:2.7.1-cuda12.8-cudnn9-runtime

# -------------------------------------------------------------------
# Core env
# -------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    WAN_RVC_ROOT=/workspace \
    APPLIO_DIR=/workspace/applio

WORKDIR /workspace

# -------------------------------------------------------------------
# System deps
# -------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ffmpeg \
        wget \
        curl \
        sox \
        ca-certificates \
        unzip \
        nano \
        locales && \
    rm -rf /var/lib/apt/lists/*

# Ensure UTF-8 locale (helps with Python / Gradio)
RUN locale-gen en_US.UTF-8 || true
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# -------------------------------------------------------------------
# Python deps (global)
# -------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends build-essential gcc g++
RUN python -m pip install --upgrade pip setuptools wheel

# Hugging Face CLI (optional but useful for model sync)
RUN python -m pip install huggingface_hub

# -------------------------------------------------------------------
# Install FileBrowser (single binary)
# -------------------------------------------------------------------
# See: https://github.com/filebrowser/filebrowser/releases
RUN wget -q https://github.com/filebrowser/filebrowser/releases/latest/download/linux-amd64-filebrowser.tar.gz \
    -O /tmp/filebrowser.tar.gz && \
    tar -xzf /tmp/filebrowser.tar.gz -C /usr/local/bin filebrowser && \
    chmod +x /usr/local/bin/filebrowser && \
    rm /tmp/filebrowser.tar.gz

# -------------------------------------------------------------------
# Clone Applio (RVC Web UI)
# -------------------------------------------------------------------
RUN git clone https://github.com/IAHispano/Applio.git ${APPLIO_DIR}

WORKDIR ${APPLIO_DIR}

# Install Applio requirements
# (They recommend Python 3.9–3.11; this base image is in that range)
RUN python -m pip install -r requirements.txt

# Optional: if you ever need to force a specific Torch build, do it *after* requirements.txt
# RUN python -m pip install --force-reinstall "torch==2.7.1" --index-url https://download.pytorch.org/whl/cu128

# -------------------------------------------------------------------
# Ports
# -------------------------------------------------------------------
# Applio WebUI
EXPOSE 7865
# FileBrowser
EXPOSE 8080

# -------------------------------------------------------------------
# Copy startup script
# -------------------------------------------------------------------
COPY startup.sh /workspace/startup.sh
RUN chmod +x /workspace/startup.sh

# -------------------------------------------------------------------
# Default command
# -------------------------------------------------------------------
WORKDIR /workspace
CMD ["/bin/bash", "/workspace/startup.sh"]
