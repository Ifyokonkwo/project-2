#!/bin/bash
set -e

# -----------------------------------
# SYSTEM UPDATE
# -----------------------------------
apt-get update -y
apt-get upgrade -y

# -----------------------------------
# INSTALL REQUIRED PACKAGES
# -----------------------------------
apt-get install -y \
    docker.io \
    openssh-server \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    software-properties-common

# -----------------------------------
# ENABLE + START DOCKER
# -----------------------------------
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "Docker installation completed successfully."

# =====================================
# NEW RELIC INSTALLATION
# =====================================
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${new_relic_key}" NEW_RELIC_ACCOUNT_ID="${new_relic_account_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y