#!/usr/bin/env bash
set -euo pipefail

echo "==========================================================="
echo "   RVC Applio + FileBrowser — RunPod Starter (Patched)"
echo "==========================================================="

# -------------------------------------------------------------------
# 1. Core Config & Paths
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
# 2. Persistent Directory Setup
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
# 3. Symlinks (Linking /workspace to /app/applio)
# -------------------------------------------------------------------
echo ">> Linking persistent folders into Applio..."

mkdir -p "${APPLIO_DIR}/rvc_extra"

ln -sfn "${DATASET_DIR}"  "${APPLIO_DIR}/rvc_extra/datasets"
ln -sfn "${PRETRAIN_DIR}" "${APPLIO_DIR}/rvc_extra/pretrained"
ln -sfn "${TRAINED_DIR}"  "${APPLIO_DIR}/rvc_extra/trained"
ln -sfn "${RMVPE_DIR}"    "${APPLIO_DIR}/rvc_extra/rmvpe"
ln -sfn "${UVR_DIR}"      "${APPLIO_DIR}/rvc_extra/uvr"

# Optional: Link models dir if needed by specific Applio versions
if [ ! -L "${APPLIO_DIR}/models" ]; then
  rm -rf "${APPLIO_DIR}/models"
  ln -s "${PRETRAIN_DIR}" "${APPLIO_DIR}/models"
fi

# -------------------------------------------------------------------
# 4. FileBrowser Setup (Background Service)
# -------------------------------------------------------------------
FB_DB="${DATA_ROOT}/filebrowser.db"

if [[ ! -f "${FB_DB}" ]]; then
  echo ">> Initializing FileBrowser database..."
  filebrowser -d "${FB_DB}" config init
  filebrowser -d "${FB_DB}" config set --root "${DATA_ROOT}"
  filebrowser -d "${FB_DB}" users add admin 'Admin@123!' --perm.admin
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
# 5. CODE PATCHING (The "Nuclear" Fix)
# -------------------------------------------------------------------
# This section forces Applio to listen on 0.0.0.0 by modifying the code directly.
# This bypasses issues where flags or env vars are ignored.

echo ">> Patching Applio source to FORCE 0.0.0.0 binding..."
cd "${APPLIO_DIR}"

# Identify the entry point
if [[ -f "app.py" ]]; then
    TARGET_SCRIPT="app.py"
elif [[ -f "infer-web.py" ]]; then
    TARGET_SCRIPT="infer-web.py"
else
    echo "❌ ERROR: No valid Applio entrypoint found (app.py or infer-web.py)"
    ls -la
    exit 1
fi

echo ">> Target script identified: $TARGET_SCRIPT"

# Replace '127.0.0.1' with '0.0.0.0' inside the python file
sed -i 's/server_name="127.0.0.1"/server_name="0.0.0.0"/g' "$TARGET_SCRIPT"
sed -i "s/server_name='127.0.0.1'/server_name='0.0.0.0'/g" "$TARGET_SCRIPT"

# Also patch config.json if it exists (another common place for local-only restrictions)
find . -maxdepth 2 -name "config.json" -exec sed -i 's/127.0.0.1/0.0.0.0/g' {} +

# -------------------------------------------------------------------
# 6. Start Applio with Monitoring
# -------------------------------------------------------------------
echo ">> Starting Applio (RVC WebUI)..."
echo "⚠️  IMPORTANT: Initial download of models (1.5GB+) will happen now."
echo "⚠️  The WebUI will return 502 Bad Gateway until this download finishes."

export GRADIO_SERVER_NAME="0.0.0.0"
export GRADIO_SERVER_PORT="7865"
export HF_HOME="${DATA_ROOT}/.cache/huggingface"

# Start Applio in background, directing output to a log file
nohup python "$TARGET_SCRIPT" > "${LOGS_DIR}/applio_stdout.log" 2>&1 &
APPLIO_PID=$!

echo ">> Applio process launched with PID: $APPLIO_PID"
echo ">> Tailing logs now. Wait for 'Running on local URL'..."
echo "-------------------------------------------------------"

# Tail the log file to the console so RunPod Logs show progress.
# This loop runs forever (or until container stops), effectively keeping the container alive.
tail -f "${LOGS_DIR}/applio_stdout.log"
