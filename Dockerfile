# syntax=docker/dockerfile:1

# -------------------------------------------------------------------
# Base: NVIDIA CUDA 12.8 (works on all RunPod GPUs, Blackwell, Hopper)
# -------------------------------------------------------------------
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# -------------------------------------------------------------------
# Core environment
# -------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    APPLIO_DIR=/workspace/applio

WORKDIR /workspace

# -------------------------------------------------------------------
# System dependencies (required for Applio + RVC training)
# -------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    ffmpeg \
    wget \
    curl \
    unzip \
    nano \
    sox \
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
    locales \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Python defaults
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# -------------------------------------------------------------------
# Install PyTorch (GPU) - Torch 2.5.1 CUDA 12.x wheels
# -------------------------------------------------------------------
RUN pip install --upgrade pip setuptools wheel && \
    pip install torch==2.5.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# -------------------------------------------------------------------
# Hugging Face CLI
# -------------------------------------------------------------------
RUN pip install huggingface_hub

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
# Fix broken Torch version inside Applio requirements
# -------------------------------------------------------------------
RUN sed -i 's/torch==2.7.1+cu128/torch==2.5.1+cu121/g' requirements.txt

# -------------------------------------------------------------------
# Install Applio requirements
# -------------------------------------------------------------------
RUN pip install -r requirements.txt

# -------------------------------------------------------------------
# Ports
# -------------------------------------------------------------------
EXPOSE 7865     # Applio UI
EXPOSE 8080     # FileBrowser
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Startup
# -------------------------------------------------------------------
COPY startup.sh /workspace/startup.sh
RUN chmod +x /workspace/startup.sh

WORKDIR /workspace
CMD ["/bin/bash", "/workspace/startup.sh"]
