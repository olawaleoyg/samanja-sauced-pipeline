# samanja-sauced-pipeline test

readme# DevOps-af-xterns-pod-a-June2024-SHALI-Packer

## Project Overview
Timedelta requires a Secure, Highly-Available Logging Infrastructure (SHALI) to support its internal operations. The SHALI project will leverage AWS, Terraform, Packer, Ansible, Splunk, Wazuh, Shell scripts, and Github Actions to create an environment where all server traffic is scanned via a proxy server, and logs are consolidated and stored securely

## SHALI Packer Repository

This repository contains Packer templates for creating hardened AMIs according to CSI standards for the SHALI project.

## Setup Instructions for Packer

### Prerequisites
1. Install Packer
2. Install Git

**Clone the repository:**
  ```
  git clone https://github.com/<YourUsername>/DevOps-af-xterns-pod-a-June2024-SHALI-Packer.git
  ```

**Navigate to the repository directory:**
  ```
  cd DevOps-af-xterns-pod-a-June2024-SHALI-Packer
  ```
## Please take note of the followings in line 15 to 25 of template.pkr.hcl
### Making choice of AMI OS, if you want ubuntu, set use_ubuntu default to "true", while use_rehat default will be set to "false"
### Making choice of AMI OS, if you want redhat, set use_ubuntu default to "false", while use_rehat default will be set to "true"

variable to select ubuntu AMI
variable "use_ubuntu" {
  type    = bool
  default = true
}

variable to select redhat AMI
variable "use_redhat" {
  type    = bool
  default = false
}

**To build an AMI, run the following command:**
  ```
  packer build template.pkr.hcl
  ```


# Reason for your selection between both tools.
There are other tools for time synchronization:
Other Time Synchronization Tools
1. systemd-timesyncd: Less feature-rich and not as accurate as ntpd or chrony.
2. OpenNTPD: Limited features compared to ntpd and chrony.
3. PTP (Precision Time Protocol)
Why ntpd or chrony Might Be Better
* ntpd: Highly mature, stable, feature-rich, and widely supported. Best for stable, continuously connected systems.
* chrony: Fast synchronization, flexible, good for intermittent connections, and lightweight. Best for environments with intermittent connectivity.

# the use case of some functions purpose and example
---
execute_and_check() {
  local func_name=$1
  shift
  $func_name "$@"
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    log "Error: $func_name failed with exit code $exit_code."
    exit $exit_code
  fi
}
---

local func_name=$1
Assigns the first argument passed to execute_and_check to the variable func_name.
In this context, $1 is expected to be the name of the function you want to execute. For example, if you call execute_and_check configure_time_sync, func_name will be set to configure_time_sync.
2. shift
Removes the first argument (func_name) from the list of arguments.
After shift, $@ will contain all arguments except the first one. This allows you to pass the remaining arguments to the function being executed.
3. $func_name "$@"
Executes the function whose name is stored in func_name with all the remaining arguments.
$func_name is treated as a command (function call), and "$@" represents all the remaining arguments. For instance, if func_name is configure_time_sync, this line will execute configure_time_sync with any additional arguments that were passed to execute_and_check.
4. local exit_code=$?
Captures the exit code of the last executed command (i.e., the function).
$? holds the exit code of the most recently executed command. local exit_code=$? stores this exit code in the exit_code variable for later use.
5. if [ $exit_code -ne 0 ]; then
Checks if the exit code is non-zero (indicating an error).
If the function returns a non-zero exit code (typically used to indicate failure), this condition evaluates to true.
6. log "Error: $func_name failed with exit code $exit_code."
Logs an error message including the function name and exit code.
The log function is called to write a message to the log file, indicating which function failed and what the exit code was.
7. exit $exit_code
Purpose: Exits the script with the exit code of the failed function.
This ensures that the script stops executing further and exits with the same exit code as the failed function, which is useful for error handling and debugging.
