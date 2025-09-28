# Part one - Mini Soc

1. Wazuh Stack
----------------
- Deploy Wazuh Indexer, Manager, and Dashboard on Docker Swarm
- Expose the dashboard via HTTPS
- Persist data with Docker volumes
- Deploy multi-node topology for bonus points

2. CI/CD Pipeline (GitHub Actions + Self-Hosted Runners)
----------------
* On PR and push to main:
    - Build container images
    - Scan with Trivy (fail on Critical/High findings)
    - Run Selenium tests
    - Deploy to Swarm via Ansible (only after tests pass on main)
    - Document runner prerequisites (Docker, Python, Ansible, Trivy, Chrome/Playwright)

3. Testing
----------------
* Selenium test cases:
    - HTTPS dashboard availability
    - Page title and login form presence
    - Programmatic login with test credentials
    - API health probe: Wazuh Manager endpoint returns 200/valid JSON
    - Deployment (Ansible → Docker Swarm)
