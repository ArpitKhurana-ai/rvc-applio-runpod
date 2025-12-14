# syntax=docker/dockerfile:1

FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    APP_DIR=/app \
    DATA_DIR=/workspace

# ---------------------------------------------------------------
# System deps
# ---------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
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
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# ---------------------------------------------------------------
# PyTorch (GPU for amd64, CPU for arm64)
# ---------------------------------------------------------------
RUN pip install --upgrade pip setuptools wheel && \
    if [ "$(uname -m)" = "x86_64" ]; then \
        pip install torch==2.5.1+cu121 torchvision==0.20.1 torchaudio==2.5.1 \
          --index-url https://download.pytorch.org/whl/cu121; \
    else \
        pip install torch torchvision torchaudio \
          --index-url https://download.pytorch.org/whl/cpu; \
    fi

# ---------------------------------------------------------------
# App directory (IMPORTANT: NOT /workspace)
# ---------------------------------------------------------------
WORKDIR /app

# ---------------------------------------------------------------
# HuggingFace
# ---------------------------------------------------------------
RUN pip install huggingface_hub

# ---------------------------------------------------------------
# FileBrowser
# ---------------------------------------------------------------
RUN wget -q https://github.com/filebrowser/filebrowser/releases/latest/download/linux-amd64-filebrowser.tar.gz \
    -O /tmp/filebrowser.tar.gz && \
    tar -xzf /tmp/filebrowser.tar.gz -C /usr/local/bin filebrowser && \
    chmod +x /usr/local/bin/filebrowser && \
    rm /tmp/filebrowser.tar.gz

# ---------------------------------------------------------------
# Clone Applio INTO /app
# ---------------------------------------------------------------
RUN git clone https://github.com/IAHispano/Applio.git /app/applio
WORKDIR /app/applio

# Remove torch pins
RUN sed -i '/^torch==/d' requirements.txt && \
    sed -i '/^torchaudio==/d' requirements.txt && \
    sed -i '/^torchvision==/d' requirements.txt

RUN pip install -r requirements.txt

# ---------------------------------------------------------------
# Startup script (OUTSIDE /workspace)
# ---------------------------------------------------------------
COPY startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

EXPOSE 7865
EXPOSE 8080

WORKDIR /app
CMD ["/bin/bash", "/app/startup.sh"]
