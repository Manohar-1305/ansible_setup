#!/bin/bash

LOG_FILE="$(pwd)/ansible_setup.log" # Log file in the same directory where the script is run

exec > >(tee -a "$LOG_FILE") 2>&1 # Redirect stdout and stderr to the log file

sudo su -

user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"

log() {
  local message="$1"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $message"
}

log "Starting Ansible Controller Setup"

# Check if user already exists
if id "$user_name" &>/dev/null; then
  log "User $user_name already exists."
  exit 1
fi

# Create a user
log "Creating user: $user_name"
sudo adduser --disabled-password --gecos "" "$user_name"

log "User $user_name is created successfully"

# Add user to sudoer group
echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$user_name

# Switch to user from root
log "Switching to user: $user_name"
su - $user_name

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
mkdir -p $user_ssh_dir
chmod 700 $user_ssh_dir

# Generate SSH key
if [ ! -f "$user_ssh_dir/id_rsa" ]; then
  log "Generating SSH key for $user_name"
  ssh-keygen -t rsa -b 4096 -f $user_ssh_dir/id_rsa -N ""
fi

chown -R $user_name:$user_name $user_home

log "Uploading SSH key to S3"
aws s3 cp $user_ssh_dir/id_rsa.pub s3://my-key/server.pub

# Login into user
user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"
ssh_key_path="$user_ssh_dir/authorized_keys"

mkdir -p $user_ssh_dir
chmod 700 $user_ssh_dir

log "Downloading SSH key from S3"
aws s3 cp s3://my-key/server.pub $ssh_key_path
chmod 600 $ssh_key_path
chown -R $user_name:$user_name $user_home

export AWS_REGION=ap-south-1

# Function to update or add entries in inventory
update_entry() {
  local section=$1
  local host=$2
  local ip=$3

  log "Updating inventory entry: [$section] $host ansible_host=$ip"

  # Ensure the section header exists
  if ! grep -q "^\[$section\]" "$INVENTORY_FILE"; then
    log "Section $section not found. Adding section header."
    echo -e "\n[$section]" | sudo tee -a "$INVENTORY_FILE"
  fi

  # Remove existing entry if it exists
  sudo sed -i "/^\[$section\]/,/^\[.*\]/{/^$host ansible_host=.*/d}" "$INVENTORY_FILE"

  # Add or update the entry
  sudo sed -i "/^\[$section\]/a $host ansible_host=$ip" "$INVENTORY_FILE"
}

# Check if the inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
  log "Inventory file not found: $INVENTORY_FILE"
  exit 1
fi

# Fetch the Ansible Controller public IP
log "Fetching Ansible Controller IP"
ansible_controller=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:Name,Values=ansible_controller" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

if [ -z "$ansible_controller" ]; then
  log "Failed to fetch Ansible Controller IP"
  exit 1
fi
log "Ansible Controller IP: $ansible_controller"

sleep 90

# Define client nodes
clients=("ansible_client_1" "ansible_client_2" "ansible_client_3")

# Fetch and update IPs for clients
declare -A client_ips
for client_node in "${clients[@]}"; do
  log "Fetching IP for $client_node"

  # Fetch IP address from AWS
  ip=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:Name,Values=$client_node" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

  # Check if IP retrieval was successful
  if [[ -n "$ip" ]]; then
    client_ips["$client_node"]="$ip"
    log "IP for $client_node: $ip"
  else
    log "Failed to fetch IP for $client_node"
  fi
done

log "Ansible setup script completed successfully."
