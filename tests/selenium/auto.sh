#!/bin/bash
# This script is just an example of what the selenium pipeline script takes
# Export the following vars for manual test
export DEBUG=1
export WAZUH_URL=
export WAZUH_USER=
export WAZUH_PASS=

export API_URL=
export API_USER=
export API_PASS=
python3 pipeline_ui_tests.py --ignore-certificate-errors
