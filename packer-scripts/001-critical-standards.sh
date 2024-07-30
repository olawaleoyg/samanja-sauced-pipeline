#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Enable debugging
set -x

sleep 15
echo "#################### Executing 001-critical-standards.sh ######################"

# Function to disable root login and enforce key-based authentication in the SSH configuration file
configure_ssh_security() {
  # Check if the system is Debian-based or Red Hat-based
  if [ -f /etc/debian_version ]; then
    echo "Detected Debian-based system."
  elif [ -f /etc/redhat-release ]; then
    echo "Detected Red Hat-based system."
  else
    echo "Unsupported Linux distribution."
    return 1
  fi

  SSH_CONFIG_FILE="/etc/ssh/sshd_config"

  # Backup the original SSH configuration file
  cp "$SSH_CONFIG_FILE" "${SSH_CONFIG_FILE}.backup"
  echo "Original SSH configuration file backed up to ${SSH_CONFIG_FILE}.backup."

  # Disable root login
  if ! grep -q "^PermitRootLogin" "$SSH_CONFIG_FILE"; then
    echo "PermitRootLogin no" >> "$SSH_CONFIG_FILE"
  else
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG_FILE"
  fi
  echo "Root login disabled successfully."

  # Enforce key-based authentication
  if ! grep -q "^PubkeyAuthentication" "$SSH_CONFIG_FILE"; then
    echo "PubkeyAuthentication yes" >> "$SSH_CONFIG_FILE"
  else
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG_FILE"
  fi
  echo "Public key authentication enabled successfully."

  # Disable password authentication
  if ! grep -q "^PasswordAuthentication" "$SSH_CONFIG_FILE"; then
    echo "PasswordAuthentication no" >> "$SSH_CONFIG_FILE"
  else
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG_FILE"
  fi
  echo "Password authentication disabled successfully."

  # Determine SSH service name and restart it
  if systemctl list-units --type=service | grep -q sshd.service; then
    SSH_SERVICE="sshd.service"
  elif systemctl list-units --type=service | grep -q ssh.service; then
    SSH_SERVICE="ssh.service"
  else
    echo "Failed to detect SSH service. Please check the SSH configuration."
    return 1
  fi

  if systemctl restart "$SSH_SERVICE"; then
    echo "$SSH_SERVICE restarted successfully."
  else
    echo "Failed to restart $SSH_SERVICE. Please check the SSH configuration."
    return 1
  fi

  echo "SSH security configuration completed successfully."
  return 0
}

# Function to configure the firewall
configure_firewall() {
  if [ -f /etc/debian_version ]; then
    # Debian-based systems
    if ! command -v ufw > /dev/null; then
      echo "ufw not detected. Installing ufw..."
      apt-get update -y
      apt-get install -y ufw
      echo "ufw installation completed."
    else
      echo "ufw is already installed."
    fi

    echo "Configuring firewall using ufw..."
    # Enable ufw
    ufw --force enable
    # Allow necessary services by port numbers
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    # Deny all other incoming connections by default
    ufw default deny incoming
    # Allow all outgoing connections by default
    ufw default allow outgoing
    # Reload ufw to apply changes
    ufw reload
    # Check ufw status
    ufw status verbose

  elif [ -f /etc/redhat-release ]; then
    # RedHat-based systems
    if ! command -v firewalld > /dev/null; then
      echo "firewalld not detected. Installing firewalld..."
      yum install -y firewalld
      echo "firewalld installation completed."
    else
      echo "firewalld is already installed."
    fi

    echo "Configuring firewall using firewalld..."
    # Start and enable firewalld
    systemctl start firewalld
    systemctl enable firewalld
    # Allow necessary services by port numbers
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    # Reload firewalld to apply changes
    firewall-cmd --reload
    # Check firewalld status
    firewall-cmd --list-all

  else
    echo "Unsupported Linux distribution."
    return 1
  fi

  echo "Firewall configuration completed successfully."
  return 0
}

# Call the SSH security configuration function
configure_ssh_security
exit_code=$?
echo $exit_code > /opt/script-error-code

# If the SSH security configuration was successful, configure the firewall
if [ $exit_code -eq 0 ]; then
  configure_firewall
  exit_code=$?
fi

# Display the final exit code before exiting
echo "Final exit code: $exit_code"
exit $exit_code

echo "#################### 001-critical-standards.sh execution completed ################" > /var/log/001-critical-standards.log

