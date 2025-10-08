chmod +x local_test.sh
chmod +x wazuh_init_check.sh

# Run Wazuh init check first
/bin/bash wazuh_init_check.sh && \

# Run local tests with environment variables
DEBUG=1 \
WAZUH_URL="https://127.0.0.1" \
WAZUH_USER="admin"
WAZUH_PASS="SecretPassword"
API_URL="https://127.0.0.1:55000" \
API_USER="test"
API_PASS="test"
/bin/bash local_test.sh
