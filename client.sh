#!/bin/bash
sleep 30
# Define variables
log_file="/var/log/user_setup.log"
user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"
ssh_key_path="$user_ssh_dir/authorized_keys"

# Function to log messages
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$log_file"
}

log "Starting user setup script."

# Check if the user already exists
if id "$user_name" &>/dev/null; then
  log "User $user_name already exists. Skipping user creation."
else
  # Create the user if not exists
  sudo adduser --disabled-password --gecos "" "$user_name" && log "User $user_name has been created successfully."
fi

sleep 2

# Create .ssh directory if not exists
if [ ! -d "$user_ssh_dir" ]; then
  sudo mkdir -p "$user_ssh_dir"
  sudo chmod 700 "$user_ssh_dir"
  sudo chown -R "$user_name:$user_name" "$user_ssh_dir"
  log "Created .ssh directory for $user_name."
fi

# Install AWS CLI if not installed
if ! command -v aws &>/dev/null; then
  log "Installing AWS CLI..."
  sudo apt-get update -y >> "$log_file" 2>&1
  sudo apt-get install -y awscli >> "$log_file" 2>&1
  log "AWS CLI installation completed."
else
  log "AWS CLI is already installed."
fi

# Fetch and copy SSH public key from S3
if sudo aws s3 cp s3://my-key/server.pub "$ssh_key_path" >> "$log_file" 2>&1; then
  sudo chmod 600 "$ssh_key_path"
  sudo chown -R "$user_name:$user_name" "$user_home"
  log "SSH public key fetched and configured successfully."
else
  log "Failed to fetch SSH public key from S3."
fi

# Add user to sudoers if not already present
if ! sudo grep -q "$user_name ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/$user_name 2>/dev/null; then
  echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$user_name >> "$log_file" 2>&1
  sudo chmod 440 /etc/sudoers.d/$user_name
  log "Sudo privileges granted to $user_name."
else
  log "Sudo privileges already exist for $user_name."
fi

log "Setup completed successfully."
