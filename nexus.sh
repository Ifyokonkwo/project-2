#!/bin/bash

# Update system and install OpenJDK 17
sudo apt update
sudo apt install openjdk-17-jdk -y

# Create nexus user
sudo adduser --system --no-create-home --group nexus

# Navigate to /opt
cd /opt
sudo wget https://download.sonatype.com/nexus/3/nexus-3.92.2-01-linux-x86_64.tar.gz

# Extract and rename Nexus directory
sudo tar -xvzf nexus-3.92.2-01-linux-x86_64.tar.gz
sudo mv nexus-3.92.2-01 nexus

# Set proper ownership
sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work

# Configure Nexus to run as nexus user (without interactive editor)
echo 'run_as_user="nexus"' | sudo tee /opt/nexus/bin/nexus.rc

# Create systemd service file for Nexus
sudo tee /etc/systemd/system/nexus.service > /dev/null <<EOF
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start Nexus
sudo systemctl daemon-reload
sudo systemctl enable nexus
sudo systemctl start nexus

# Check Nexus status
sleep 10
sudo systemctl status nexus --no-pager

sudo hostnamectl set-hostname nexus

# =====================================
# NEW RELIC INSTALLATION
# =====================================

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${new_relic_key}" NEW_RELIC_ACCOUNT_ID="${new_relic_account_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y