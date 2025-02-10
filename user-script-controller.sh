#!/bin/bash

sudo su -

user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"

# Check if user already exists
if id "$user_name" &>/dev/null; then
  echo "User $user_name already exists."
  exit 1
fi

# create a user
sudo adduser --disabled-password --gecos "" "$user_name"

echo "User $user_name is created succesfully"

# add user to sudoer group
echo "ansible-user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible-user

# Switch to user from rot
su - ansible-user

# install awscli
sudo apt update -y
sudo apt-get install -y awscli

# Install ansible
sudo apt-add-repository ppa:ansible/ansible -y
sudo apt update -y
sudo apt install ansible -y

mkdir -p $user_ssh_dir
chmod 700 $user_ssh_dir

#Generate SSH key
if [ ! -f "$user_ssh_dir/id_rsa" ]; then
  ssh-keygen -t rsa -b 4096 -f $user_ssh_dir/id_rsa -N ""
fi

chown -R $user_name:$user_name $user_home

aws s3 cp $user_ssh_dir/id_rsa.pub s3://my-key/server.pub

#logi =n into user
user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"
ssh_key_path="$user_ssh_dir/authorized_keys"

mkdir -p $user_ssh_dir
chmod 700 $user_ssh_dir

aws s3 cp s3://my-key/server.pub $ssh_key_path
chmod 600 $ssh_key_path
chown -R $user_name:$user_name $user_home

cd
# Navigate to home directory and log a message
cd $user_home && echo "correct till this step" >>main-data.log 2>&1

git clone "https://github.com/Manohar-1305/ansible_playbook_k8s-installation.git"

INVENTORY_FILE="ansible_playbook_k8s-installation/ansible/inventories/inventory.ini"

LOG_FILE="ansible_script.log"

export AWS_REGION=ap-south-1

log() {
  local message="$1"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" | sudo tee -a "$LOG_FILE"
}

# Function to update or add entries
update_entry() {
  local section=$1
  local host=$2
  local ip=$3

  log "Updating entry: Section: $section, Host: $host, IP: $ip"

  # Ensure the section header exists
  if ! grep -q "^\[$section\]" "$INVENTORY_FILE"; then
    log "Section $section not found. Adding section header."
    sudo bash -c "echo -e '\n[$section]' >>'$INVENTORY_FILE'"
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

# Fetch the Bastion host public IP
log "Fetching Ansible_controller IP"
ansible_controller=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:Name,Values=ansible_controller" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

if [ -z "$ansible_controller" ]; then
  log "Failed to fetch Ansible_controller IP"
  exit 1
fi
log "Controller: $ansible_controller"
sleep 90
# Define arrays for master and worker nodes
ansible_client=("ansible_client1" "ansible_client2" "ansible_client3")

# Fetch and update IPs for masters
declare -A ansible_client_ips
for ansible_client in "${ansible_client[@]}"; do
  log "Fetching IP for $ansible_client"

  # First attempt to fetch IP
  ip=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:Name,Values=$ansible_client" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)

  if [ -z "$ip" ]; then
    log "Failed to fetch IP for $ansible_client on first attempt. Retrying..."
    sleep 10 # Optional: small delay before retrying

    # Second attempt
    ip=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:Name,Values=$ansible_client" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)

    if [ -z "$ip" ]; then
      log "Failed to fetch IP for $ansible_client after retry. Skipping..."
      continue
    fi
  fi

  log "$ansible_client IP: $ip"
  ansible_client_ips["$ansible_client"]=$ip
done

# Sequentially update entries for worker nodes
log "Updating workers section in sequence"
update_entry "client" "ansible_client1" "${ansible_client_ips[ansible_client1]}"
update_entry "client" "ansible_client2" "${ansible_client_ips[ansible_client2]}"
update_entry "client" "ansible_client3" "${ansible_client_ips[ansible_client3]}"

# Update entries for bastion and NFS
update_entry "controller" "ansible_controller" "$ansible_controller"
