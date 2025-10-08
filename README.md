# Phase 1 - Build a Mini SOC
--------------
# CI/CD Pipeline (GitHub Actions + Self-hosted Runners)

* This repository implements a fully automated CI/CD pipeline using:
- **GitHub Actions** for workflow automation
- **Self-hosted runners** for custom execution environments
- **Docker Swarm** for deployment

The pipeline automatically builds, scans, tests, and deploys containerized applications.

# Workflow Trigger

* The pipeline runs automatically on:
	- **Pull requests** to `main` from `pre-prod` branch
	- **Push events** to `main`

## CI/CD Pipeline Steps

### 1. **Build Container Images**

* Docker images are built for the application [docker-images.sh ](https://github.com/YESSEO/devops-chall/blob/main/.github/workflows/pr_wazuh_build.yml#L13)
```yaml
  build-docker-images:
    runs-on: self-hosted
    outputs:
      wazuh_base: ${{ steps.detect.outputs.wazuh_base }}
      wazuh_version: ${{ steps.detect.outputs.wazuh_version }}
    steps:
      - name: Checkout PR branch
        uses: actions/checkout@v4
        with:
          ref: pre-prod # Files lives in this pr
          fetch-depth: 0
          clean: false

      - name: Detect submitted wazuh-docker folder
        id: detect
        run: |
            ...
      - name: Run build script
        working-directory: ${{ steps.detect.outputs.wazuh_base }}
        run: |
          /bin/bash build-docker-images/build-images.sh
```


### 2. Scan with **Trivy** (fail on Critical/High findings)

* Trivy vulnerability scan is performed immediately after a successful Docker image build, [trivy-scan](https://github.com/YESSEO/devops-chall/blob/main/.github/workflows/pr_wazuh_build.ymll#L50)

```yaml
  trivy-scan:
    runs-on: self-hosted
    needs: build-docker-images
    steps:
      - uses: actions/checkout@v4
        with:
          ref: pre-prod
          fetch-depth: 0
          clean: false

      - name: Trivy Scan - Wazuh Indexer
        run: |
          trivy image --scanners vuln wazuh/wazuh-indexer:${{ needs.build-docker-images.outputs.wazuh_version }} \
          --ignorefile "$GITHUB_WORKSPACE"/trivy/.trivyignore \
          --severity CRITICAL,HIGH --exit-code 1\
          --format json --output "$GITHUB_WORKSPACE"/reports/trivy/trivy-wazuh-indexer.json \


      - name: Trivy Scan - Wazuh Dashboard
        run: |
          trivy image --scanners vuln wazuh/wazuh-dashboard:${{ needs.build-docker-images.outputs.wazuh_version }} \
          --ignorefile "$GITHUB_WORKSPACE"/trivy/.trivyignore \
          --severity CRITICAL,HIGH --exit-code 1\
          --format json --output "$GITHUB_WORKSPACE"/reports/trivy/trivy-wazuh-dashboard.json
          ...
```

### 3. **Local Test Deployment**

 -  After building Docker images and passing the Trivy scan, the pipeline **deploys a test environment locally** [deploy-test](https://github.com/YESSEO/devops-chall/blob/main/.github/workflows/pr_wazuh_build.yml#L90)

```yaml
  deploy-test:
    runs-on: self-hosted
    needs: [build-docker-images, trivy-scan]
    steps:
      - uses: actions/checkout@v4
        with:
          ref: pre-prod
          fetch-depth: 0
          clean: false

      - name: Compose up
        working-directory: ${{ needs.build-docker-images.outputs.wazuh_base }}/multi-node
        run: |
          docker compose -f generate-indexer-certs.yml run --rm generator && \
          docker compose up -d
```

* The job performs the following:
    - Checks out the PR branch to ensure tests run against the correct code.
    - Runs a **certificate generator** for the Wazuh stack (`generate-indexer-certs.yml`).
    - Starts the full **multi-node Wazuh test environment** in detached mode with Docker Compose.
* This ensures the environment is fully set up before executing automated tests.

### 4. Automated Testing

* Before running Selenium , the pipeline ensures the **Wazuh dashboard is fully up and responsive**.
* This is handeled by the **wait-dashboard-api** job [deploy-test](https://github.com/YESSEO/devops-chall/blob/main/.github/workflows/pr_wazuh_build.yml#L106) , which executes the script [wazuh_ini_check.sh](https://github.com/YESSEO/devops-chall/blob/main/tests/selenium/wazuh_init_check.sh)

```sh
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
...
```