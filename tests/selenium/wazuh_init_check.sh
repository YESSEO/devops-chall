#!/bin/bash

# =========================
# Default values
# =========================
HOST="localhost"
PORT1=443
PORT2=55000
MAX_RETRIES=100
DELAY=20

# =========================
# Help function
# =========================
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --host HOST            Hostname or IP to check (default: localhost)
  --port1 PORT           Dashboard port (default: 443)
  --port2 PORT           API port (default: 55000)
  --max-retries NUM      Max number of retries per check (default: 100)
  --delay SECONDS        Delay between retries (default: 20)
  -h, --help             Show this help message and exit

Example:
  $0 --host 127.0.0.1 --port1 443 --port2 55000 --max-retries 50 --delay 10
EOF
    exit 0
}

# =========================
# Parse arguments
# =========================
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --host) HOST="$2"; shift 2 ;;
        --port1) PORT1="$2"; shift 2 ;;
        --port2) PORT2="$2"; shift 2 ;;
        --max-retries) MAX_RETRIES="$2"; shift 2 ;;
        --delay) DELAY="$2"; shift 2 ;;
        -h|--help) show_help ;;
        *) echo "[ERROR] Unknown parameter: $1"; show_help ;;
    esac
done

# =========================
# Validation
# =========================
[[ "$PORT1" =~ ^[0-9]+$ ]] || { echo "[ERROR] port1 must be numeric"; exit 1; }
[[ "$PORT2" =~ ^[0-9]+$ ]] || { echo "[ERROR] port2 must be numeric"; exit 1; }
[[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || { echo "[ERROR] max-retries must be numeric"; exit 1; }
[[ "$DELAY" =~ ^[0-9]+$ ]] || { echo "[ERROR] delay must be numeric"; exit 1; }

echo "[INFO] Configuration:"
echo "       HOST=$HOST"
echo "       PORT1=$PORT1"
echo "       PORT2=$PORT2"
echo "       MAX_RETRIES=$MAX_RETRIES"
echo "       DELAY=$DELAY"

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
            echo "[ERROR] Port $port did not open in time."
            exit 1
        fi
        sleep "$DELAY"
    done
    echo "[SUCCESS] Port $port is open."
}

# =========================
# Check Wazuh Dashboard (443)
# =========================
check_dashboard() {
    local retries=$MAX_RETRIES
    local tmpfile
    tmpfile=$(mktemp)

    echo "[INFO] Checking Wazuh dashboard on port $PORT1..."
    while [ "$retries" -gt 0 ]; do
        response=$(curl -sk -w "%{http_code}" -o "$tmpfile" "https://$HOST/app/login?")
        curl_exit=$?
        body=$(cat "$tmpfile")

        if [ $curl_exit -eq 0 ] && [ "$response" -eq 200 ] && [[ -n "$body" ]] && \
           [[ "$body" == *"/ui/favicons/browserconfig.xml"* ]]; then
            echo "[SUCCESS] Wazuh dashboard is fully ready (HTTP 200)."
            rm -f "$tmpfile"
            return 0
        else
            echo "[INFO] ($response) waiting ..."
        fi

        retries=$((retries-1))
        echo "[INFO] Not ready yet, retrying in $DELAY seconds... ($retries retries left)"
        sleep "$DELAY"
    done

    rm -f "$tmpfile"
    echo "[ERROR] Wazuh dashboard did not become ready."
    exit 1
}

# =========================
# Check Wazuh API (55000)
# =========================
check_api() {
    local retries=$MAX_RETRIES
    local tmpfile
    tmpfile=$(mktemp)

    echo "[INFO] Checking Wazuh API on port $PORT2..."
    while [ "$retries" -gt 0 ]; do
        response=$(curl -sk -w "%{http_code}" -o "$tmpfile" "https://$HOST:$PORT2")
        curl_exit=$?
        body=$(cat "$tmpfile")

        if [ $curl_exit -eq 0 ] && [ "$response" -eq 401 ] && [[ "$body" == *"No authorization token provided"* ]]; then
            echo "[SUCCESS] Wazuh API is ready (HTTP 401)."
            rm -f "$tmpfile"
            return 0
        fi

        retries=$((retries-1))
        echo "[INFO] API not ready yet, retrying in $DELAY seconds... ($retries retries left)"
        sleep "$DELAY"
    done

    rm -f "$tmpfile"
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

wazuh_wazuh_masterecho "[SUCCESS] All checks passed successfully."

