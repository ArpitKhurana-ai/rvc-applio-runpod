# syntax=docker/dockerfile:1

# -------------------------------------------------------------------
# Base: PyTorch 2.5.1 + CUDA 12.8 (stable for Applio & RVC training)
# -------------------------------------------------------------------
FROM pytorch/pytorch:2.5.1-cuda12.8-cudnn9-runtime

# -------------------------------------------------------------------
# Core environment
# -------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    WAN_RVC_ROOT=/workspace \
    APPLIO_DIR=/workspace/applio

WORKDIR /workspace

# -------------------------------------------------------------------
# System Dependencies required by Applio + audio processing
# -------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    wget \
    curl \
    sox \
    unzip \
    nano \
    locales \
    build-essential \
    gcc \
    g++ \
    libsndfile1 \
    espeak-ng \
    libsoxr-dev \
    libsox-dev \
    libsdl2-2.0-0 \
    portaudio19-dev \
    libssl-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Locale Setup
# -------------------------------------------------------------------
RUN locale-gen en_US.UTF-8 || true
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# -------------------------------------------------------------------
# Python tools & HF CLI
# -------------------------------------------------------------------
RUN python -m pip install --upgrade pip setuptools wheel
RUN python -m pip install huggingface_hub

# -------------------------------------------------------------------
# Install FileBrowser
# -------------------------------------------------------------------
RUN wget -q https://github.com/filebrowser/filebrowser/releases/latest/download/linux-amd64-filebrowser.tar.gz \
    -O /tmp/filebrowser.tar.gz && \
    tar -xzf /tmp/filebrowser.tar.gz -C /usr/local/bin filebrowser && \
    chmod +x /usr/local/bin/filebrowser && \
    rm /tmp/filebrowser.tar.gz

# -------------------------------------------------------------------
# Clone Applio
# -------------------------------------------------------------------
RUN git clone https://github.com/IAHispano/Applio.git ${APPLIO_DIR}
WORKDIR ${APPLIO_DIR}

# -------------------------------------------------------------------
# Install Applio dependencies
# -------------------------------------------------------------------
RUN python -m pip install -r requirements.txt

# -------------------------------------------------------------------
# Ports
# -------------------------------------------------------------------
EXPOSE 7865   # Applio WebUI
EXPOSE 8080   # FileBrowser

# -------------------------------------------------------------------
# Startup Script
# -------------------------------------------------------------------
COPY startup.sh /workspace/startup.sh
RUN chmod +x /workspace/startup.sh

# -------------------------------------------------------------------
# Command
# -------------------------------------------------------------------
WORKDIR /workspace
CMD ["/bin/bash", "/workspace/startup.sh"]
