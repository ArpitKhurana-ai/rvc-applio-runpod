#!/usr/bin/env bash
set -e

echo "==========================================================="
echo "   RVC Applio + FileBrowser — RunPod Starter"
echo "==========================================================="

# -------------------------------------------------------------------
# Core env
# -------------------------------------------------------------------
export PYTHONUNBUFFERED=1
# Helps avoid some OOM fragmentation issues on 12–16 GB cards
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

export WAN_RVC_ROOT="/workspace"
export APPLIO_DIR="${WAN_RVC_ROOT}/applio"

# You can optionally set this at template level (for private HF repos)
# export HF_TOKEN=""

cd "${WAN_RVC_ROOT}"

# -------------------------------------------------------------------
# Directory layout (beginner-friendly)
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

echo ">> Directory structure ensured:"
echo "   - ${DATASET_DIR} (upload training data here)"
echo "   - ${PRETRAIN_DIR} (pretrained RVC / TITAN / Ov2Super)"
echo "   - ${TRAINED_DIR} (your trained voices)"
echo "   - ${RMVPE_DIR} (F0 models)"
echo "   - ${UVR_DIR} (vocal separation models)"
echo "   - ${LOGS_DIR}"

# -------------------------------------------------------------------
# (Optional) Hugging Face model sync
# -------------------------------------------------------------------
# This is **for you**, not end-users. You can hardcode your HF repo that
# bundles pretrains (RVC V2, TITAN, Ov2Super, RMVPE, UVR, etc.).
#
# Example pattern (commented out by default):
#
# if [[ -n "${HF_TOKEN}" ]]; then
#   echo ">> HF_TOKEN detected, syncing models from Hugging Face..."
#   huggingface-cli download your-username/your-rvc-bundle \
#     --local-dir "${WAN_RVC_ROOT}/Models" \
#     --token "${HF_TOKEN}" \
#     --exclude ".gitattributes"
# else
#   echo ">> No HF_TOKEN set. Skipping automatic model download."
#   echo ">> Place your models manually into:"
#   echo "   - ${PRETRAIN_DIR}"
#   echo "   - ${TRAINED_DIR}"
#   echo "   - ${RMVPE_DIR}"
#   echo "   - ${UVR_DIR}"
# fi

# -------------------------------------------------------------------
# Symlinks into Applio (so UX is clean)
# -------------------------------------------------------------------
if [[ -d "${APPLIO_DIR}" ]]; then
  echo ">> Wiring Applio to standardized /workspace paths..."

  # These paths are "extra" mount points. Even if Applio doesn't use
  # them by default, you can browse to them from inside the UI.
  mkdir -p "${APPLIO_DIR}/rvc_extra"

  ln -sfn "${DATASET_DIR}"  "${APPLIO_DIR}/rvc_extra/datasets"
  ln -sfn "${PRETRAIN_DIR}" "${APPLIO_DIR}/rvc_extra/pretrained"
  ln -sfn "${TRAINED_DIR}"  "${APPLIO_DIR}/rvc_extra/trained"
  ln -sfn "${RMVPE_DIR}"    "${APPLIO_DIR}/rvc_extra/rmvpe"
  ln -sfn "${UVR_DIR}"      "${APPLIO_DIR}/rvc_extra/uvr"

  echo ">> Applio extra mounts:"
  echo "   - ${APPLIO_DIR}/rvc_extra/datasets  -> ${DATASET_DIR}"
  echo "   - ${APPLIO_DIR}/rvc_extra/pretrained -> ${PRETRAIN_DIR}"
  echo "   - ${APPLIO_DIR}/rvc_extra/trained    -> ${TRAINED_DIR}"
fi

# -------------------------------------------------------------------
# FileBrowser setup (admin / admin)
# -------------------------------------------------------------------
FB_DB="${WAN_RVC_ROOT}/filebrowser.db"

if [[ ! -f "${FB_DB}" ]]; then
  echo ">> Initializing FileBrowser database..."
  filebrowser -d "${FB_DB}" config init
  # Root at /workspace so users see Datasets + Models immediately
  filebrowser -d "${FB_DB}" config set --root "${WAN_RVC_ROOT}"
  # Create default admin user (demo template, you can warn in README/video)
  filebrowser -d "${FB_DB}" users add admin admin --perm.admin
fi

echo ">> Starting FileBrowser on :8080 (user: admin / pass: admin)"
nohup filebrowser -d "${FB_DB}" -p 8080 >/workspace/filebrowser.log 2>&1 &

# -------------------------------------------------------------------
# Applio launch
# -------------------------------------------------------------------
echo ">> Starting Applio (RVC WebUI) on :7865"
cd "${APPLIO_DIR}"

# NOTE:
# Applio normally uses run-applio.sh, but core entry is app.py
# We bind to 0.0.0.0 so RunPod exposes it.
python app.py --port 7865 --host 0.0.0.0 >/workspace/applio.log 2>&1
