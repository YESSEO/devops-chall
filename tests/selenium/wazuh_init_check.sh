#!/bin/bash

# =========================
# Configurable variables
# =========================
HOST="localhost"
PORT1=443
PORT2=55000
MAX_RETRIES=60
DELAY=15

# =========================
# Function to wait for port
# =========================
wait_for_port() {
  local port=$1
  local retries=$MAX_RETRIES

  echo "[INFO] Waiting for port $port to be open on $HOST..."
  while ! nc -z "$HOST" "$port" >/dev/null 2>&1; do
    retries=$((retries-1))
    if [ "$retries" -le 0 ]; then
      echo "[INFO] Port $port did not open in time."
      exit 1
    fi
    sleep "$DELAY"
  done
  echo "[SUCCUESS] Port $port is open."
}

# =========================
# Wait for Wazuh Dashboard (443)
# =========================
check_dashboard() {
  local retries=$MAX_RETRIES

  echo "[INFO] Checking Wazuh dashboard on port $PORT1..."
  while [ "$retries" -gt 0 ]; do
    response=$(curl -sk -w "%{http_code}" -o /tmp/resp.txt "https://$HOST/app/login?")
    body=$(cat /tmp/resp.txt)

    if [ "$response" -eq 200 ] && [[ -n "$body" ]] && \ 
          [[ "$body" != *"Wazuh dashboard server is not ready yet"* ]]; then
      echo "[SUCCESS] Wazuh dashboard is ready (HTTP 200, correct response)."
      return 0
    fi

    retries=$((retries-1))
    echo "[INFO] Not ready yet, retrying in $DELAY seconds... ($retries retries left)"
    sleep "$DELAY"
  done

  echo "[ERROR] Wazuh dashboard did not become ready."
  exit 1
}

# =========================
# Wait for Wazuh API (55000)
# =========================
check_api() {
  local retries=$MAX_RETRIES

  echo "[info] Checking Wazuh API on port $PORT2..."
  while [ "$retries" -gt 0 ]; do
    response=$(curl -sk -w "%{http_code}" -o /tmp/api_resp.txt "https://$HOST:$PORT2")
    body=$(cat /tmp/api_resp.txt)

    if [ "$response" -eq 401 ] && [[ "$body" == *"No authorization token provided"* ]]; then
      echo "[SUCCESS] Wazuh API is ready (HTTP 401, correct JSON response)."
      return 0
    fi

    retries=$((retries-1))
    echo "[INFO] API not ready yet, retrying in $DELAY seconds... ($retries retries left)"
    sleep "$DELAY"
  done

  echo "[ERROR] Wazuh API did not respond correctly."
  exit 1
}

# =========================
# Main execution
# =========================
wait_for_port "$PORT1"
check_dashboard

wait_for_port "$PORT2"
check_api

echo "[SUCCESS] All checks passed successfully."
