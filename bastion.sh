#!/bin/bash
mkdir-p /home/ubuntu/.ssh
echo "${private_key}" > /home/ubuntu/.ssh/id_rsa
chmod 400 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
hostnamectl set-hostname bastion

# =====================================
# NEW RELIC INSTALLATION
# =====================================
# =====================================
# NEW RELIC INSTALLATION
# =====================================

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${new_relic_key}" NEW_RELIC_ACCOUNT_ID="${new_relic_account_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y