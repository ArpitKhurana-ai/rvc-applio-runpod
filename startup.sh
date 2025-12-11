#!/usr/bin/env bash
set -e

echo "==========================================================="
echo "   RVC Applio + FileBrowser — RunPod Starter"
echo "==========================================================="

# -------------------------------------------------------------------
# Core env
# -------------------------------------------------------------------
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

export WAN_RVC_ROOT="/workspace"
export APPLIO_DIR="${WAN_RVC_ROOT}/applio"

cd "${WAN_RVC_ROOT}"

# -------------------------------------------------------------------
# Directory layout
# -------------------------------------------------------------------
DATASET_DIR="${WAN_RVC_ROOT}/Datasets/Voice_Training_Upload"
PRETRAIN_DIR="${WAN_RVC_ROOT}/Models/RVC_Pretrained"
TRAINED_DIR="${WAN_RVC_ROOT}/Models/RVC_Trained_Models"
RMVPE_DIR="${WAN_RVC_ROOT}/Models/RMVPE"
UVR_DIR="${WAN_RVC_ROOT}/Models/UVR"
LOGS_DIR="${WAN_RVC_ROOT}/logs"

mkdir -p \
  "${DATASET_DIR}" \
  "${PRETRAIN_DIR}" \
  "${TRAINED_DIR}" \
  "${RMVPE_DIR}" \
  "${UVR_DIR}" \
  "${LOGS_DIR}"

echo ">> Directory structure ensured."
echo ">> Applio folder: ${APPLIO_DIR}"

# -------------------------------------------------------------------
# Symlinks into Applio
# -------------------------------------------------------------------
if [[ -d "${APPLIO_DIR}" ]]; then
  echo ">> Linking dataset & model folders into Applio..."

  mkdir -p "${APPLIO_DIR}/rvc_extra"

  ln -sfn "${DATASET_DIR}"  "${APPLIO_DIR}/rvc_extra/datasets"
  ln -sfn "${PRETRAIN_DIR}" "${APPLIO_DIR}/rvc_extra/pretrained"
  ln -sfn "${TRAINED_DIR}"  "${APPLIO_DIR}/rvc_extra/trained"
  ln -sfn "${RMVPE_DIR}"    "${APPLIO_DIR}/rvc_extra/rmvpe"
  ln -sfn "${UVR_DIR}"      "${APPLIO_DIR}/rvc_extra/uvr"
fi

# -------------------------------------------------------------------
# FileBrowser setup
# -------------------------------------------------------------------
FB_DB="${WAN_RVC_ROOT}/filebrowser.db"

if [[ ! -f "${FB_DB}" ]]; then
  echo ">> Initializing FileBrowser database..."
  filebrowser -d "${FB_DB}" config init
  filebrowser -d "${FB_DB}" config set --root "${WAN_RVC_ROOT}"
  filebrowser -d "${FB_DB}" users add admin admin --perm.admin
fi

echo ">> Starting FileBrowser on port 8080..."
nohup filebrowser -d "${FB_DB}" --root "${WAN_RVC_ROOT}" --port 8080 \
  >/workspace/filebrowser.log 2>&1 &

sleep 1
echo ">> FileBrowser running. Log: /workspace/filebrowser.log"

# -------------------------------------------------------------------
# Start Applio — IMPORTANT: run in FOREGROUND (blocking)
# -------------------------------------------------------------------
echo ">> Starting Applio (RVC WebUI) on port 7865..."
cd "${APPLIO_DIR}"

# FIX: run in foreground so RunPod proxy detects it
exec python3 app.py --port 7865 --host 0.0.0.0
