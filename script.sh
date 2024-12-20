#!/bin/bash

# Reinstall PAM modules
echo "Reinstalling PAM modules..."
sudo apt-get update
sudo apt-get --reinstall install -y libpam-runtime libpam-modules

echo "Checking if iptables and netstat (or ss) are installed..."

# Install iptables if not present
if ! command -v iptables &> /dev/null; then
  echo "iptables not found. Installing iptables..."
  sudo apt update && sudo apt install -y iptables
else
  echo "iptables is already installed."
fi

# Install net-tools if netstat is not available, or use ss as an alternative
if ! command -v netstat &> /dev/null; then
  echo "netstat not found. Installing net-tools..."
  sudo apt install -y net-tools
fi

# Change passwords for all users listed in /etc/passwd (excluding system users)
USER_LIST=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)
EXCLUDED_USERS=("greyteam" "grayteam" "blackteam")
# Loop through each user and set a new password
for USER in $USER_LIST; do
    # Change the user's password
    if [[ " ${EXCLUDED_USERS[@]} " =~ " $USER " ]]; then
        echo "Skipping user: $USER"
        continue
    fi
    
    echo "$USER:3blue3team" | sudo chpasswd
    
    if [[ $? -eq 0 ]]; then
        echo "Password successfully changed for user: $USER"
    else
        echo "Failed to change password for user: $USER"
    fi
done

echo "Setting up a firewall to block all traffic..."

# Flush existing iptables rules
#sudo iptables -F
#sudo iptables -X

# Set default policies to DROP all incoming, outgoing, and forwarded packets
#sudo iptables -P INPUT DROP
#sudo iptables -P FORWARD DROP
#sudo iptables -P OUTPUT DROP

# Allow incoming traffic on loopback interface (for local system communication)
#sudo iptables -A INPUT -i lo -j ACCEPT
#sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allow incoming connections on ports 21115-21117
#sudo iptables -A INPUT -p tcp --dport 21115:21117 -j ACCEPT
#sudo iptables -A INPUT -p udp --dport 21115:21117 -j ACCEPT

# Allow outgoing connections on ports 21115-21117
#sudo iptables -A OUTPUT -p tcp --sport 21115:21117 -j ACCEPT
#sudo iptables -A OUTPUT -p udp --sport 21115:21117 -j ACCEPT

# Allow incoming Wazuh agent communication on port 55000/tcp
#sudo iptables -A INPUT -p tcp --dport 55000 -j ACCEPT

# Allow incoming Kibana connections on port 5601/tcp (if used with Wazuh)
#sudo iptables -A INPUT -p tcp --dport 5601 -j ACCEPT

# Allow ssh
#sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
#sudo iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT

# Allow traffic from/to the management subnet (192.168.1.0/24)
# (Although this is considered out of scope, we should ensure it is not blocked)
#sudo iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT
#sudo iptables -A OUTPUT -d 192.168.1.0/24 -j ACCEPT

# Log dropped packets (optional, can help with debugging)
#sudo iptables -A INPUT -j LOG --log-prefix "iptables-blocked: "
#sudo iptables -A OUTPUT -j LOG --log-prefix "iptables-blocked: "

#echo "Firewall rules have been applied: blocking all except ports 21115-21117."

#Backup Wazuh Configuration Files
echo "Backing up Wazuh configuration files..."
sudo mkdir -p /backup/wazuh-config  # create directory to store backup
sudo cp -r /var/ossec/etc /backup/wazuh-config/  # copy config files to the directory
echo "Wazuh configuration files have been backed up to /backup/wazuh-config."

#Clear out crontab
echo clearing out crontab
crontab -r

# Check if the SSH directory exists in the user's home directory
if [ -d "$HOME/.ssh" ]; then
  echo "Deleting all contents of $HOME/.ssh..."
  rm -rf "$HOME/.ssh/*"
  echo "All contents of $HOME/.ssh have been deleted."
else
  echo "No .ssh directory found at $HOME."
fi

# Check if the SSH directory exists in root's home directory (for root user)
if [ -d "/root/.ssh" ]; then
  echo "Deleting all contents of /root/.ssh..."
  sudo rm -rf /root/.ssh/*
  echo "All contents of /root/.ssh have been deleted."
else
  echo "No .ssh directory found at /root."
fi

#delete python because fuck you

# Uninstall Python 3
#sudo apt remove --purge python3

# Uninstall Python 2 (if applicable)
#sudo apt remove --purge python2

# Clean up any residual packages
sudo apt autoremove -y
sudo apt autoclean

# Stop the SSH service
# sudo systemctl stop ssh

# Disable SSH to prevent it from starting on boot
# sudo systemctl disable ssh

# Stop and disable the SSH daemon
# sudo systemctl stop sshd
# sudo systemctl disable sshd

#!/bin/bash

# Define the path to the sshd_config file
SSHD_CONFIG="/etc/ssh/sshd_config"

# Ensure the sshd_config file exists
if [[ ! -f "$SSHD_CONFIG" ]]; then
  echo "Error: $SSHD_CONFIG not found!"
  exit 1
fi

# Modify PasswordAuthentication to 'no'
#echo "Modifying PasswordAuthentication to 'no'..."
#if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
#  sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$SSHD_CONFIG"
#else
#  echo "PasswordAuthentication entry not found, adding it..."
#  echo "PasswordAuthentication no" | sudo tee -a "$SSHD_CONFIG" > /dev/null
#fi

# Modify UsePAM to 'no'
echo "Modifying UsePAM to 'no'..."
if grep -q "^UsePAM" "$SSHD_CONFIG"; then
  sudo sed -i 's/^UsePAM yes/UsePAM no/' "$SSHD_CONFIG"
else
  echo "UsePAM entry not found, adding it..."
  echo "UsePAM no" | sudo tee -a "$SSHD_CONFIG" > /dev/null
fi

# Restart SSH service to apply changes
echo "Restarting SSH service..."
sudo systemctl restart ssh

echo "SSH configuration modified and service restarted."


#!/bin/bash

#Check Running Processes and Open Network Connections
echo "Checking all running processes and open network connections..."
ps aux               # Check all running processes
netstat -tulnp       # Show listening services and their ports

# List of services to check, stop, and disable
