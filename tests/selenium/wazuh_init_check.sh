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
    # Run curl and capture exit code
    response=$(curl -sk -w "%{http_code}" -o /tmp/resp.txt "https://$HOST/app/login?")
    curl_exit=$?
    body=$(cat /tmp/resp.txt)

    # Check if curl succeeded
    if [ $curl_exit -ne 0 ]; then
      echo "[INFO] Curl failed (exit code $curl_exit), dashboard not ready yet."
    # Check HTTP status
    elif [ "$response" -ne 200 ]; then
      echo "[INFO] HTTP status $response, dashboard not ready yet."
    # Check body non-empty
    elif [[ -z "$body" ]]; then
      echo "[INFO] Dashboard response body is empty, not ready yet."
    # Check body content
    elif [[ "$body" == *"Wazuh dashboard server is not ready yet"* ]]; then
      echo "[INFO] Dashboard reports 'server not ready yet'."
    else
      echo "[SUCCESS] Wazuh dashboard is ready (HTTP 200, non-empty, correct response)."
      return 0
    fi

    retries=$((retries-1))
    echo "[INFO] Retry in $DELAY seconds... ($retries retries left)"
    sleep "$DELAY"
  done

  echo "[ERROR] Wazuh dashboard did not become ready after $MAX_RETRIES attempts."
  exit 1
}

# =========================
# Wait for Wazuh API (55000)
# =========================
check_api() {
  local retries=$MAX_RETRIES

  echo "[INFO] Checking Wazuh API on port $PORT2..."
  while [ "$retries" -gt 0 ]; do
    response=$(curl -sk -w "%{http_code}" -o /tmp/api_resp.txt "https://$HOST:$PORT2")
    curl_exit=$?
    body=$(cat /tmp/api_resp.txt)

    # Check if curl succeeded
    if [ $curl_exit -ne 0 ]; then
      echo "[INFO] Curl failed (exit code $curl_exit), API not ready yet."
    # Check HTTP status code
    elif [ "$response" -ne 401 ]; then
      echo "[INFO] HTTP status $response, API not ready yet."
    # Check body is non-empty
    elif [[ -z "$body" ]]; then
      echo "[INFO] API response body is empty, not ready yet."
    # Check body content
    elif [[ "$body" != *"No authorization token provided"* ]]; then
      echo "[INFO] API response not valid yet."
    else
      echo "[SUCCESS] Wazuh API is ready (HTTP 401, non-empty, correct JSON response)."
      return 0
    fi

    retries=$((retries-1))
    echo "[INFO] Retry in $DELAY seconds... ($retries retries left)"
    sleep "$DELAY"
  done

  echo "[ERROR] Wazuh API did not become ready after $MAX_RETRIES attempts."
  exit 1
}


# =========================
# Main 
# =========================
wait_for_port "$PORT1"
check_dashboard

wait_for_port "$PORT2"
check_api

echo "[SUCCESS] All checks passed successfully."
