#!/bin/bash

LOG_FILE="$(pwd)/ansible_setup.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  local message="$1"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $message"
}

log "Starting Ansible Controller Setup"

user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"

# Check if user already exists
if id "$user_name" &>/dev/null; then
  log "User $user_name already exists."
else
  log "Creating user: $user_name"
  sudo adduser --disabled-password --gecos "" "$user_name"
  log "User $user_name is created successfully"
  echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$user_name
fi

# Install AWS CLI
log "Installing AWS CLI"
sudo apt update -y
sudo apt-get install -y awscli

# Install Ansible
log "Installing Ansible"
sudo apt-add-repository ppa:ansible/ansible -y
sudo apt update -y
sudo apt install ansible -y

log "Creating SSH directory for $user_name"
sudo mkdir -p "$user_ssh_dir"
sudo chmod 700 "$user_ssh_dir"
sudo chown -R "$user_name:$user_name" "$user_home"

# Generate SSH key
if [ ! -f "$user_ssh_dir/id_rsa" ]; then
  log "Generating SSH key for $user_name"
  sudo -u "$user_name" ssh-keygen -t rsa -b 4096 -f "$user_ssh_dir/id_rsa" -N ""
fi

log "Uploading SSH key to S3"
aws s3 cp "$user_ssh_dir/id_rsa.pub" s3://my-key/server.pub

# Download SSH key from S3
ssh_key_path="$user_ssh_dir/authorized_keys"
log "Downloading SSH key from S3"
aws s3 cp s3://my-key/server.pub "$ssh_key_path"
chmod 600 "$ssh_key_path"
chown -R "$user_name:$user_name" "$user_home"

export AWS_REGION=ap-south-1

log "Ansible Controller Setup Completed"

log "Ansible setup script completed successfully."
echo "Cloning the Repo"
git clone https://github.com/Manohar-1305/ansible_setup.git

INVENTORY_FILE="/home/ansible-user/ansible_setup/ansible/inventories/inventory.ini"

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Ensure inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
  log "Inventory file not found. Creating it."
  sudo touch "$INVENTORY_FILE"
fi

# Fetch Ansible Controller Public IP
log "Fetching Ansible Controller IP"
ansible_controller=$(aws ec2 describe-instances --region "ap-south-1" --filters "Name=tag:Name,Values=ansible_controller" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

if [ -z "$ansible_controller" ]; then
  log "Failed to fetch Ansible Controller IP"
  exit 1
fi
log "Ansible Controller IP: $ansible_controller"

# Remove old Ansible_Controller entries to avoid duplication
sudo sed -i "/Ansible_Controller ansible_host=/d" "$INVENTORY_FILE"

# Ensure [controller] section exists and add Ansible_Controller under it
if ! grep -q "^\[controller\]" "$INVENTORY_FILE"; then
  log "Adding [controller] section"
  echo -e "\n[controller]" | sudo tee -a "$INVENTORY_FILE" >/dev/null
fi

# Add Ansible_Controller under [controller]
sudo sed -i "/^\[controller\]/a Ansible_Controller ansible_host=$ansible_controller" "$INVENTORY_FILE"

# Ensure [client] section exists
if ! grep -q "^\[client\]" "$INVENTORY_FILE"; then
  log "Adding [client] section"
  echo -e "\n[client]" | sudo tee -a "$INVENTORY_FILE" >/dev/null
fi
sleep 90
# Define and update client nodes
clients=("ansible_client_1" "ansible_client_2" "ansible_client_3")

for client_node in "${clients[@]}"; do
  log "Fetching IP for $client_node"
  

  ip=$(aws ec2 describe-instances --region "ap-south-1" --filters "Name=tag:Name,Values=$client_node" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)

  if [[ -n "$ip" ]]; then
    log "IP for $client_node: $ip"

    # Remove old entry for this client
    sudo sed -i "/$client_node ansible_host=/d" "$INVENTORY_FILE"

    # Append client under [client]
    sudo sed -i "/^\[client\]/a $client_node ansible_host=$ip" "$INVENTORY_FILE"
  else
    log "Failed to fetch IP for $client_node"
  fi
done
