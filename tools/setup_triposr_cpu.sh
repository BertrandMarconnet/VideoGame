#!/usr/bin/env bash
set -euo pipefail

# Reproducible, no-key TripoSR installation for a GitHub-hosted CPU runner.
INSTALL_DIR="${TRIPOSR_HOME:-$HOME/opt/TripoSR}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TRIPOSR_REF="${TRIPOSR_REF:-107cefdc244c39106fa830359024f6a2f1c78871}"
STAMP="$INSTALL_DIR/.blackout_cpu_ready_${TRIPOSR_REF}"

for command in git "$PYTHON_BIN" blender; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 2
  fi
done

mkdir -p "$(dirname "$INSTALL_DIR")"
if [ ! -d "$INSTALL_DIR/.git" ]; then
  git init "$INSTALL_DIR"
  git -C "$INSTALL_DIR" remote add origin https://github.com/VAST-AI-Research/TripoSR.git
fi

git -C "$INSTALL_DIR" fetch --depth 1 origin "$TRIPOSR_REF"
git -C "$INSTALL_DIR" checkout --detach --force FETCH_HEAD

if [ ! -x "$INSTALL_DIR/.venv/bin/python" ]; then
  "$PYTHON_BIN" -m venv "$INSTALL_DIR/.venv"
fi

# shellcheck disable=SC1091
source "$INSTALL_DIR/.venv/bin/activate"

if [ ! -f "$STAMP" ]; then
  python -m pip install --upgrade pip setuptools wheel
  python -m pip install --index-url https://download.pytorch.org/whl/cpu \
    torch==2.2.2 torchvision==0.17.2
  python -m pip install 'numpy<2' 'setuptools>=69' ninja
  cat > "$INSTALL_DIR/.blackout-constraints.txt" <<'CONSTRAINTS'
numpy<2
huggingface-hub<1.0
Pillow==10.1.0
transformers==4.35.0
trimesh==4.0.5
CONSTRAINTS
  MAX_JOBS="${MAX_JOBS:-2}" python -m pip install \
    -c "$INSTALL_DIR/.blackout-constraints.txt" \
    -r "$INSTALL_DIR/requirements.txt"
  touch "$STAMP"
fi

python - <<'PY'
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print("TripoSR execution device: cpu")
PY

blender --version | head -n 1
printf 'TRIPOSR_HOME=%s\n' "$INSTALL_DIR"
