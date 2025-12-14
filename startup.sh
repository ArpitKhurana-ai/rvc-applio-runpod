#!/usr/bin/env bash
set -e

echo "==========================================================="
echo "   RVC Applio + FileBrowser — RunPod Starter"
echo "==========================================================="

# -------------------------------------------------------------------
# Core paths (CRITICAL SEPARATION)
# -------------------------------------------------------------------
APP_ROOT="/app"
APPLIO_DIR="${APP_ROOT}/applio"
DATA_ROOT="/workspace"

export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

echo "🔹 App root:      ${APP_ROOT}"
echo "🔹 Applio dir:    ${APPLIO_DIR}"
echo "🔹 Data root:     ${DATA_ROOT}"

# -------------------------------------------------------------------
# Persistent directory layout
# -------------------------------------------------------------------
DATASET_DIR="${DATA_ROOT}/Datasets/Voice_Training_Upload"
PRETRAIN_DIR="${DATA_ROOT}/Models/RVC_Pretrained"
TRAINED_DIR="${DATA_ROOT}/Models/RVC_Trained_Models"
RMVPE_DIR="${DATA_ROOT}/Models/RMVPE"
UVR_DIR="${DATA_ROOT}/Models/UVR"
LOGS_DIR="${DATA_ROOT}/logs"

mkdir -p \
  "${DATASET_DIR}" \
  "${PRETRAIN_DIR}" \
  "${TRAINED_DIR}" \
  "${RMVPE_DIR}" \
  "${UVR_DIR}" \
  "${LOGS_DIR}"

echo ">> Persistent directory structure ready."

# -------------------------------------------------------------------
# Symlinks into Applio (SAFE NOW)
# -------------------------------------------------------------------
echo ">> Linking persistent folders into Applio..."

mkdir -p "${APPLIO_DIR}/rvc_extra"

ln -sfn "${DATASET_DIR}"  "${APPLIO_DIR}/rvc_extra/datasets"
ln -sfn "${PRETRAIN_DIR}" "${APPLIO_DIR}/rvc_extra/pretrained"
ln -sfn "${TRAINED_DIR}"  "${APPLIO_DIR}/rvc_extra/trained"
ln -sfn "${RMVPE_DIR}"    "${APPLIO_DIR}/rvc_extra/rmvpe"
ln -sfn "${UVR_DIR}"      "${APPLIO_DIR}/rvc_extra/uvr"

# Optional: models dir
if [ ! -L "${APPLIO_DIR}/models" ]; then
  rm -rf "${APPLIO_DIR}/models"
  ln -s "${PRETRAIN_DIR}" "${APPLIO_DIR}/models"
fi

# -------------------------------------------------------------------
# FileBrowser setup
# -------------------------------------------------------------------
FB_DB="${DATA_ROOT}/filebrowser.db"

if [[ ! -f "${FB_DB}" ]]; then
  echo ">> Initializing FileBrowser database..."
  filebrowser -d "${FB_DB}" config init
  filebrowser -d "${FB_DB}" config set --root "${DATA_ROOT}"
  filebrowser -d "${FB_DB}" users add admin admin --perm.admin
fi

echo ">> Starting FileBrowser on port 8080..."
nohup filebrowser \
  -d "${FB_DB}" \
  --root "${DATA_ROOT}" \
  --address 0.0.0.0 \
  --port 8080 \
  >"${LOGS_DIR}/filebrowser.log" 2>&1 &

sleep 1
echo ">> FileBrowser running."

# -------------------------------------------------------------------
# Start Applio (FOREGROUND — REQUIRED)
# -------------------------------------------------------------------
echo ">> Starting Applio (RVC WebUI) on port 7865..."
cd "${APPLIO_DIR}"

exec python app.py --port 7865 --host 0.0.0.0

