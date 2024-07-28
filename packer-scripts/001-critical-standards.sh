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

###########################
# Function to enable logging and auditing
enable_logging_auditing() {
  # Install and configure auditd
  if [ -f /etc/debian_version ]; then
    # Install auditd on Debian-based systems
    apt-get update && apt-get install -y auditd
  elif [ -f /etc/redhat-release ]; then
    # Install auditd on RedHat-based systems
    yum install -y audit
  fi
  # Ensure auditd starts on boot and is running
  systemctl enable auditd
  systemctl start auditd
  ###########################
  # Backup the audit rule file
  ###########################
  cp /etc/audit/audit.rules /etc/audit/audit.rules.bak
  ###########################
  # Add the following rules to the audit rule file
  ###########################
  echo "Setting up basic audit rules..."
   #Appending rules to the actual audit.rules file
  echo "# Audit all commands executed by users" >> /etc/audit/rules.d/*.rules
  echo "-a always,exit -F arch=b64 -S execve -k command" >> /etc/audit/rules.d/*.rules
  echo "# Monitor changes to critical files" >> /etc/audit/rules.d/*.rules
  echo "-w /etc/shadow -p wa -k identity" >> /etc/audit/rules.d/*.rules
  echo "-w /etc/sudoers -p wa -k actions" >> /etc/audit/rules.d/*.rules
  echo "# Monitor system calls related to user and system activity" >> /etc/audit/rules.d/*.rules
  echo "-a always,exit -F arch=b64 -S open,openat,creat,truncate,ftruncate -k file_access" >> /etc/audit/rules.d/*.rules
  # Restart auditd to apply new rules
  systemctl restart auditd
  # Validate auditd is logging appropriate events
  auditctl -l
  # Capture the exit code
  exit_code=$?
  # Return the exit code
  return $exit_code
}
# Function to limit user privileges
limit_user_privileges() {
  # Create a backup of the sudoers file
  cp /etc/sudoers /etc/sudoers.bak
  # Ensure authorized user exists
  if ! id -u authorized_user > /dev/null 2>&1; then
    useradd -m authorized_user
  fi
  # Configure sudoers file to limit root access
  echo "authorized_user ALL=(ALL) ALL" > /etc/sudoers.d/authorized_user
#echo "authorized_user ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/authorized_user
  # Set correct permissions for sudoers file
  chmod 0440 /etc/sudoers.d/authorized_user
  # Ensure only authorized users have sudo access
  usermod -aG sudo authorized_user
  # Validate sudo configuration
  visudo -c
  # Capture the exit code
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: sudo configuration failed."
  fi
  # Return the exit code
  return $exit_code
}
# Log function
log_action() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') : $message" >> /var/log/script.log
}
# Main script execution
enable_logging_auditing
# Check the exit code of the previous function
if [ $? -ne 0 ]; then
  log_action "Failed to enable logging and auditing. Exiting..."
  exit 1
fi
limit_user_privileges
# Check the exit code of the previous function
if [ $? -ne 0 ]; then
  log_action "Failed to limit user privileges. Exiting..."
  exit 1
fi
log_action "Script executed successfully."
echo "Script executed successfully."

# Display the final exit code before exiting
echo "Final exit code: $exit_code"
exit $exit_code


echo "#################### 001-critical-standards.sh execution completed ################" > /var/log/001-critical-standards.log

