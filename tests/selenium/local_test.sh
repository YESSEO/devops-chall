#!/bin/bash
set -euo pipefail

VENV_NAME="health_check"
REQUIREMENTS_FILE="requirements.txt"
SCRIPT_TO_RUN="pipeline_ui_tests.py"  # change this to your script path
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

# -----------------------------
# Setup pyenv
# -----------------------------
export PATH="$PYENV_ROOT/bin:$PATH"

if ! command -v pyenv >/dev/null 2>&1; then
    echo "[ERROR] pyenv not found in $PYENV_ROOT"
    echo "[INFO] Install pyenv first: https://github.com/pyenv/pyenv#installation"
    exit 1
fi

# Ensure pyenv-virtualenv plugin is present
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
    echo "[INFO] pyenv-virtualenv plugin not found, installing..."
    git clone https://github.com/pyenv/pyenv-virtualenv.git \
        "$PYENV_ROOT/plugins/pyenv-virtualenv"
fi

eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# -----------------------------
# Create virtualenv if needed
# -----------------------------
if ! pyenv virtualenvs --bare | grep -q "^${VENV_NAME}\$"; then
    echo "[INFO] Creating pyenv virtualenv: $VENV_NAME"
    pyenv virtualenv "$VENV_NAME"
else
    echo "[INFO] Virtualenv $VENV_NAME already exists"
fi

# Activate env
export PYENV_VERSION="$VENV_NAME"

# -----------------------------
# Install dependencies
# -----------------------------
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "[INFO] Installing dependencies from $REQUIREMENTS_FILE"
    pip install --upgrade pip
    pip install --requirement "$REQUIREMENTS_FILE"
else
    echo "[WARN] No requirements.txt found at $REQUIREMENTS_FILE"
fi

# -----------------------------
# Export environment variables
# -----------------------------
export DEBUG="${DEBUG:-1}"
export WAZUH_URL="${WAZUH_URL:-}"
export WAZUH_USER="${WAZUH_USER:-}"
export WAZUH_PASS="${WAZUH_PASS:-}"

export API_URL="${API_URL:-}"
export API_USER="${API_USER:-}"
export API_PASS="${API_PASS:-}"

echo "[INFO] Environment variables set for Python run"

# -----------------------------
# Check required environment variables
# -----------------------------
missing_vars=()

for var in WAZUH_URL WAZUH_USER WAZUH_PASS API_URL API_USER API_PASS; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "[ERROR] Missing required environment variables: ${missing_vars[*]}"
    echo "[HINT] Pass them before running, e.g.:"
    echo "       WAZUH_URL=... WAZUH_USER=... WAZUH_PASS=... API_URL=... API_USER=... API_PASS=... ./run_health_check.sh"
    exit 1
fi

# -----------------------------
# Run Python script
# -----------------------------

if [ -f "$SCRIPT_TO_RUN" ]; then
    echo "[INFO] Running script: $SCRIPT_TO_RUN"
    python "$SCRIPT_TO_RUN"
else
    echo "[ERROR] Script not found: $SCRIPT_TO_RUN"
    exit 1
fi

