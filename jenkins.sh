#!/bin/bash
set -e

sudo apt update -y
sudo apt install fontconfig openjdk-21-jre -y
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update -y
sudo apt install jenkins -y
sudo systemctl start jenkins
sudo systemctl enable jenkins
sudo usermod -aG jenkins ubuntu

sudo apt-get install -y \
    docker.io \
    openssh-server \
    curl \
    gnupg \
    git \
    maven \
    ca-certificates \
    apt-transport-https \
    software-properties-common

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

sudo hostnamectl set-hostname jenkins

# =====================================
# NEW RELIC INSTALLATION
# =====================================

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${new_relic_key}" NEW_RELIC_ACCOUNT_ID="${new_relic_account_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y