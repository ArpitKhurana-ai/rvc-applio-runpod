#!/usr/bin/env bash
set -euo pipefail

echo "==========================================================="
echo "   RVC Applio + FileBrowser — RunPod Starter (Final Fix)"
echo "==========================================================="

# -------------------------------------------------------------------
# 1. Core Config & Paths
# -------------------------------------------------------------------
APP_ROOT="/app"
APPLIO_DIR="${APP_ROOT}/applio"
DATA_ROOT="/workspace"

export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# -------------------------------------------------------------------
# 2. Persistent Directory Setup
# -------------------------------------------------------------------
DATASET_DIR="${DATA_ROOT}/Datasets/Voice_Training_Upload"
PRETRAIN_DIR="${DATA_ROOT}/Models/RVC_Pretrained"
TRAINED_DIR="${DATA_ROOT}/Models/RVC_Trained_Models"
RMVPE_DIR="${DATA_ROOT}/Models/RMVPE"
UVR_DIR="${DATA_ROOT}/Models/UVR"
LOGS_DIR="${DATA_ROOT}/logs"

mkdir -p "${DATASET_DIR}" "${PRETRAIN_DIR}" "${TRAINED_DIR}" "${RMVPE_DIR}" "${UVR_DIR}" "${LOGS_DIR}"
echo ">> Persistent directory structure ready."

# -------------------------------------------------------------------
# 3. Symlinks
# -------------------------------------------------------------------
mkdir -p "${APPLIO_DIR}/rvc_extra"
ln -sfn "${DATASET_DIR}"  "${APPLIO_DIR}/rvc_extra/datasets"
ln -sfn "${PRETRAIN_DIR}" "${APPLIO_DIR}/rvc_extra/pretrained"
ln -sfn "${TRAINED_DIR}"  "${APPLIO_DIR}/rvc_extra/trained"
ln -sfn "${RMVPE_DIR}"    "${APPLIO_DIR}/rvc_extra/rmvpe"
ln -sfn "${UVR_DIR}"      "${APPLIO_DIR}/rvc_extra/uvr"

if [ ! -L "${APPLIO_DIR}/models" ]; then
  rm -rf "${APPLIO_DIR}/models"
  ln -s "${PRETRAIN_DIR}" "${APPLIO_DIR}/models"
fi

# -------------------------------------------------------------------
# 4. FileBrowser (Background)
# -------------------------------------------------------------------
FB_DB="${DATA_ROOT}/filebrowser.db"
if [[ ! -f "${FB_DB}" ]]; then
  filebrowser -d "${FB_DB}" config init
  filebrowser -d "${FB_DB}" config set --root "${DATA_ROOT}"
  filebrowser -d "${FB_DB}" users add admin 'Admin@123!' --perm.admin
fi

nohup filebrowser -d "${FB_DB}" --root "${DATA_ROOT}" --address 0.0.0.0 --port 8080 >"${LOGS_DIR}/filebrowser.log" 2>&1 &
echo ">> FileBrowser running on 8080."

# -------------------------------------------------------------------
# 5. AGGRESSIVE PATCHING (The Fix)
# -------------------------------------------------------------------
cd "${APPLIO_DIR}"
echo ">> Patching Applio Source Code..."

# Force Port Change: Find '6969' in ANY python file and change it to '7865'
# This targets config.py, app.py, or wherever the default is hidden.
grep -rIl "6969" . | xargs sed -i 's/6969/7865/g'

# Force Host Change: Find '127.0.0.1' and change to '0.0.0.0'
grep -rIl "127.0.0.1" . | xargs sed -i 's/127.0.0.1/0.0.0.0/g'
grep -rIl "localhost" . | xargs sed -i 's/localhost/0.0.0.0/g'

# Identify Entrypoint
if [[ -f "app.py" ]]; then
    TARGET_SCRIPT="app.py"
elif [[ -f "infer-web.py" ]]; then
    TARGET_SCRIPT="infer-web.py"
else
    echo "❌ ERROR: No entrypoint found."
    exit 1
fi

echo ">> Patched ports and hosts successfully."

# -------------------------------------------------------------------
# 6. Start & Monitor
# -------------------------------------------------------------------
echo ">> Starting Applio..."
export GRADIO_SERVER_NAME="0.0.0.0"
export GRADIO_SERVER_PORT="7865"
export HF_HOME="${DATA_ROOT}/.cache/huggingface"

# Run in background and capture PID
nohup python "$TARGET_SCRIPT" > "${LOGS_DIR}/applio_stdout.log" 2>&1 &
APPLIO_PID=$!

echo ">> Applio PID: $APPLIO_PID"
echo ">> Logs are streaming below. Wait for 'Running on local URL: http://0.0.0.0:7865'"

# Stream logs to RunPod console
tail -f "${LOGS_DIR}/applio_stdout.log"
