#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${TRIPOSR_HOME:-$HOME/opt/TripoSR}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu121}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 2
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "$PYTHON_BIN is required" >&2
  exit 2
fi
if ! command -v blender >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Blender is required for metric scaling, decimation and Godot collision output.
On Ubuntu/WSL: sudo apt-get update && sudo apt-get install -y blender
EOF
  exit 2
fi
if ! command -v nvidia-smi >/dev/null 2>&1; then
  cat >&2 <<'EOF'
No NVIDIA GPU was detected. TripoSR can fall back to CPU, but the GitHub workflow
requires a GPU runner because CPU generation is too slow for routine production.
EOF
  exit 2
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
if [ ! -d "$INSTALL_DIR/.git" ]; then
  git clone --depth 1 https://github.com/VAST-AI-Research/TripoSR.git "$INSTALL_DIR"
else
  git -C "$INSTALL_DIR" fetch --depth 1 origin main
  git -C "$INSTALL_DIR" reset --hard origin/main
fi

"$PYTHON_BIN" -m venv "$INSTALL_DIR/.venv"
# shellcheck disable=SC1091
source "$INSTALL_DIR/.venv/bin/activate"
python -m pip install --upgrade pip setuptools wheel
python -m pip install torch torchvision --index-url "$TORCH_INDEX_URL"
python -m pip install -r "$INSTALL_DIR/requirements.txt"

python - <<'PY'
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if not torch.cuda.is_available():
    raise SystemExit("PyTorch cannot access CUDA. Check the driver and wheel index URL.")
print(f"GPU: {torch.cuda.get_device_name(0)}")
PY

cat <<EOF
TripoSR runner dependencies installed in:
  $INSTALL_DIR

Next steps:
1. Add this machine as a GitHub self-hosted runner for BertrandMarconnet/VideoGame.
2. Assign labels: gpu,triposr,linux,x64
3. Keep the runner application online.
4. Run the workflow: Generate open-source 3D asset (TripoSR).
EOF
