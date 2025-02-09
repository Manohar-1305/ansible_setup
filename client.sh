#!/bin/bash

# Define variables
user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"
ssh_key_path="$user_ssh_dir/authorized_keys"

# Check if the user already exists
if id "$user_name" &>/dev/null; then
  echo "User $user_name already exists. Skipping user creation."
else
  # Create the user if not exists
  sudo adduser --disabled-password --gecos "" "$user_name"
  echo "User $user_name has been created successfully."
fi

sleep 2

# Create .ssh directory if not exists
if [ ! -d "$user_ssh_dir" ]; then
  sudo mkdir -p "$user_ssh_dir"
  sudo chmod 700 "$user_ssh_dir"
  sudo chown -R "$user_name:$user_name" "$user_ssh_dir"
fi

# Install AWS CLI if not installed
if ! command -v aws &>/dev/null; then
  echo "Installing AWS CLI..."
  sudo apt-get update -y
  sudo apt-get install -y awscli
else
  echo "AWS CLI is already installed."
fi

# Fetch and copy SSH public key from S3
sudo aws s3 cp s3://my-key/server.pub "$ssh_key_path"
sudo chmod 600 "$ssh_key_path"
sudo chown -R "$user_name:$user_name" "$user_home"

# Add user to sudoers if not already present
if ! sudo grep -q "$user_name ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/$user_name 2>/dev/null; then
  echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$user_name
  sudo chmod 440 /etc/sudoers.d/$user_name
  echo "Sudo privileges granted to $user_name."
else
  echo "Sudo privileges already exist for $user_name."
fi

echo "Setup completed successfully."
