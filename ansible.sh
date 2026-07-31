#!/bin/bash
apt update -y
mkdir -p /home/ubuntu/.ssh
echo "${private_key}" > /home/ubuntu/.ssh/id_rsa
chmod 400 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

# Install Ansible using the official PPA (Personal Package Archive)
echo "Adding Ansible PPA..."
sudo add-apt-repository --yes --update ppa:ansible/ansible

# Install Ansible
echo "Installing Ansible..."
sudo apt-get install -y ansible
hostnamectl set-hostname ansible
ansible-galaxy collection install community.docker

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin

# INSTALL REQUIRED PACKAGES
apt-get install -y \
    docker.io \
    openssh-server \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    software-properties-common

# ENABLE + START DOCKER
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# pull scripts folder containing the playbooks and Dockerfile from S3
aws s3 cp s3://${scripts_bucket_name}/scripts/ /opt/scripts/ --recursive
chown -R ubuntu:ubuntu /opt/scripts

# update the Ansible inventory file to include the localhost
echo "[all:vars]" > /etc/ansible/hosts
echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> /etc/ansible/hosts
echo "localhost ansible_connection=local" >> /etc/ansible/hosts
echo "[stage_env]" >> /etc/ansible/hosts
echo "${stage_env_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "[prod_env]" >> /etc/ansible/hosts
echo "${prod_env_ip_1} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "${prod_env_ip_2} ansible_user=ubuntu" >> /etc/ansible/hosts

# set permissions for the Ansible inventory file
chown ubuntu:ubuntu /etc/ansible/hosts

# Install New Relic CLI and set up monitoring
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY="${new_relic_key}" NEW_RELIC_ACCOUNT_ID="${new_relic_account_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y