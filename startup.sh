#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================================="
echo "   RVC APPLIO RUNPOD TEMPLATE (Premium UX) - Starting Setup"
echo "=========================================================================="

# -------------------------------------------------------------------
# 1. Core Config & Paths
# -------------------------------------------------------------------
APP_ROOT="/app"
APPLIO_DIR="${APP_ROOT}/applio"
DATA_ROOT="/workspace"

export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
export FILEBROWSER_USER="admin"
export FILEBROWSER_PASS="Admin@123!RVC" # FIXED: 13 characters for strong password policy

# -------------------------------------------------------------------
# 2. Premium Directory Structure (UX Focused)
# -------------------------------------------------------------------
# Descriptive folders make the workspace intuitive for new users.
DATASET_DIR="${DATA_ROOT}/1_Datasets_For_Training"
TRAINED_DIR="${DATA_ROOT}/2_My_Trained_Models"
INFERENCE_DIR="${DATA_ROOT}/3_Inference_Outputs"
LOGS_DIR="${DATA_ROOT}/logs"

# Internals (Keep these out of the user's primary view)
PRETRAIN_DIR="${DATA_ROOT}/Models/RVC_Pretrained_DO_NOT_TOUCH"
RMVPE_DIR="${DATA_ROOT}/Models/RMVPE_DO_NOT_TOUCH"
UVR_DIR="${DATA_ROOT}/Models/UVR_DO_NOT_TOUCH"

mkdir -p \
  "${DATASET_DIR}" \
  "${TRAINED_DIR}" \
  "${INFERENCE_DIR}" \
  "${LOGS_DIR}" \
  "${PRETRAIN_DIR}" \
  "${RMVPE_DIR}" \
  "${UVR_DIR}"

echo ">> Persistent directory structure ready."

# -------------------------------------------------------------------
# 3. Symlinks (Mapping clear names to Applio internals)
# -------------------------------------------------------------------
echo ">> Linking descriptive folders into Applio's internal structure..."

mkdir -p "${APPLIO_DIR}/rvc_extra"

# Standard RVC internal links
ln -sfn "${DATASET_DIR}"  "${APPLIO_DIR}/rvc_extra/datasets"
ln -sfn "${PRETRAIN_DIR}" "${APPLIO_DIR}/rvc_extra/pretrained"
ln -sfn "${TRAINED_DIR}"  "${APPLIO_DIR}/rvc_extra/trained"
ln -sfn "${RMVPE_DIR}"    "${APPLIO_DIR}/rvc_extra/rmvpe"
ln -sfn "${UVR_DIR}"      "${APPLIO_DIR}/rvc_extra/uvr"

# Link Applio's output directory to our clear folder
# Applio often uses a 'results' folder for conversions
if [ -d "${APPLIO_DIR}/results" ]; then
    rm -rf "${APPLIO_DIR}/results"
    ln -sfn "${INFERENCE_DIR}" "${APPLIO_DIR}/results"
fi
if [ ! -L "${APPLIO_DIR}/models" ]; then
  rm -rf "${APPLIO_DIR}/models"
  ln -s "${PRETRAIN_DIR}" "${APPLIO_DIR}/models"
fi

# -------------------------------------------------------------------
# 4. FileBrowser Setup (Background Service + Initial Guide)
# -------------------------------------------------------------------
FB_DB="${DATA_ROOT}/filebrowser.db"
if [[ ! -f "${FB_DB}" ]]; then
  echo ">> Initializing FileBrowser database..."
  filebrowser -d "${FB_DB}" config init
  filebrowser -d "${FB_DB}" config set --root "${DATA_ROOT}"
  # Password fixed to be 13 chars
  filebrowser -d "${FB_DB}" users add "${FILEBROWSER_USER}" "${FILEBROWSER_PASS}" --perm.admin
fi

nohup filebrowser \
  -d "${FB_DB}" \
  --root "${DATA_ROOT}" \
  --address 0.0.0.0 \
  --port 8080 \
  >"${LOGS_DIR}/filebrowser.log" 2>&1 &
echo ">> FileBrowser running on 8080."

# -------------------------------------------------------------------
# 5. WELCOME FILE & GUIDANCE (UX Focused)
# -------------------------------------------------------------------
echo -e "
-----------------------------------------------------
WELCOME TO APPLIO RVC - RUNPOD TEMPLATE
-----------------------------------------------------

[GETTING STARTED - YOUR FIRST 10 MINUTES]
1. UPLOAD: Place your voice samples (ideally 10+ minutes) into:
   ==> /1_Datasets_For_Training

2. TRAIN: Go to the Applio WebUI (Port 7865), select the 'Train' tab,
   and choose your dataset folder. Set 50 Total Epochs for a fast test run.

3. INFER: After training, use the 'Inference' tab. Your model will appear
   in the dropdown. Convert your audio.

4. DOWNLOAD: Your final converted audio files will appear in:
   ==> /3_Inference_Outputs

-----------------------------------------------------
FILEBROWSER LOGIN
-----------------------------------------------------
Username: ${FILEBROWSER_USER}
Password: ${FILEBROWSER_PASS}
-----------------------------------------------------
" > "${DATA_ROOT}/A_README_FOR_BEGINNERS.txt"
echo ">> Created beginner's README in /workspace."

# -------------------------------------------------------------------
# 6. AGGRESSIVE PATCHING (Retained Fixes)
# -------------------------------------------------------------------
cd "${APPLIO_DIR}"
echo ">> Patching Applio Source Code (Fixing 127.0.0.1/6969 defaults)..."

# Identify Entrypoint
if [[ -f "app.py" ]]; then
    TARGET_SCRIPT="app.py"
elif [[ -f "infer-web.py" ]]; then
    TARGET_SCRIPT="infer-web.py"
else
    echo "❌ ERROR: No entrypoint found."
    exit 1
fi

# Force Port Change: Find '6969' in ANY file and change it to '7865'
grep -rIl "6969" . | xargs sed -i 's/6969/7865/g'

# Force Host Change: Find '127.0.0.1' or 'localhost' and change to '0.0.0.0'
grep -rIl "127.0.0.1" . | xargs sed -i 's/127.0.0.1/0.0.0.0/g'
grep -rIl "localhost" . | xargs sed -i 's/localhost/0.0.0.0/g'

echo ">> Patched ports and hosts successfully."

# -------------------------------------------------------------------
# 7. Start & Monitor (Premium Console Banner)
# -------------------------------------------------------------------
echo ">> Starting Applio..."
export GRADIO_SERVER_NAME="0.0.0.0"
export GRADIO_SERVER_PORT="7865"
export HF_HOME="${DATA_ROOT}/.cache/huggingface"

# Run in background and capture PID
nohup python "$TARGET_SCRIPT" > "${LOGS_DIR}/applio_stdout.log" 2>&1 &
APPLIO_PID=$!

echo -e "\n\n"
echo "********************************************************************************"
echo "* ✅ APPLIO RVC TEMPLATE IS LAUNCHING...                    *"
echo "********************************************************************************"
echo "* *"
echo "* WebUI (RVC):   [Wait for 'Running on local URL' below] - Port 7865           *"
echo "* FileBrowser:   [Connect now!] - Port 8080                                   *"
echo "* *"
echo "* LOGIN INFO (FileBrowser):                                                   *"
echo "* Username: ${FILEBROWSER_USER}                                             *"
echo "* Password: ${FILEBROWSER_PASS}                                             *"
echo "* *"
echo "* Your first step is in the FileBrowser: /A_README_FOR_BEGINNERS.txt          *"
echo "********************************************************************************"
echo -e "\n"

# Stream logs to RunPod console (this keeps the container alive)
tail -f "${LOGS_DIR}/applio_stdout.log"
