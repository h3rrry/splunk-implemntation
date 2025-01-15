#!/bin/bash

echo

yum install wget nc -y

cd /tmp

wget -O splunk-9.4.0-6b4ebe426ca6-linux-amd64.tgz "https://download.splunk.com/products/splunk/releases/9.4.0/linux/splunk-9.4.0-6b4ebe426ca6-linux-amd64.tgz"

echo

echo "Splunk Downloaded."

echo

tar -xzvf /tmp/splunk-9.4.0-6b4ebe426ca6-linux-amd64.tgz -C /opt

rm -f /tmp/splunk-9.4.0-6b4ebe426ca6-linux-amd64.tgz

# Create a new Splunk user for server operations
useradd splunk

echo

echo "Splunk installed and Splunk Linux user created."

echo

chown -R splunk:splunk /opt/splunk

echo

# Start Splunk with predefined admin credentials
echo "Starting Splunk with admin username 'admin' and password 'TemporaryPass123'..."
runuser -l splunk -c "/opt/splunk/bin/splunk start --accept-license --no-prompt --answer-yes --seed-username admin --seed-passwd TemporaryPass123"

# Enable Splunk to start at boot
/opt/splunk/bin/splunk enable boot-start -user splunk

runuser -l splunk -c '/opt/splunk/bin/splunk stop'

chown root:splunk /opt/splunk/etc/splunk-launch.conf

chmod 644 /opt/splunk/etc/splunk-launch.conf

# Prompt user for role
echo
echo "Is this a Heavy Forwarder (HF), Deployment Server (DS), or an Indexer (IDX)? Enter 'HF' or 'DS' or 'IDX':"
read splunk_role

if [[ $splunk_role == "HF" ]]; then
    echo "Configuring for Heavy Forwarder (HF)..."

    # Create all-hf-base directory
    mkdir -p /opt/splunk/etc/apps/all-hf-base/local

    # Create outputs.conf
    cat <<EOF > /opt/splunk/etc/apps/all-hf-base/local/outputs.conf
[tcpout]
defaultGroup = default-autolb-group

[tcpout:default-autolb-group]
server = 127.0.0.1:9997
maxQueueSize = 20MB
#useACK = true
#forceTimebasedAutoLB = true
#autoLBFrequency= 5
#autoLBVolume = 1MB
indexAndForward = false
compressed = true

[tcpout-server://127.0.0.1:9997]
EOF

    # Create server.conf
    cat <<EOF > /opt/splunk/etc/apps/all-hf-base/local/server.conf
[general]
parallelIngestionPipelines = 2
EOF

    # Create web.conf
    cat <<EOF > /opt/splunk/etc/apps/all-hf-base/local/web.conf
[settings]
enableSplunkWebSSL = true
max_upload_size = 2048
EOF

    # Prompt user for Indexer IP
    echo
    echo "Please enter the Indexer IP address:"
    read idx_ip

    # Update outputs.conf with Indexer IP
    sed -i "s/^server = .*/server = $idx_ip:9997/" /opt/splunk/etc/apps/all-hf-base/local/outputs.conf
    echo "Updated outputs.conf with Indexer IP: $idx_ip"

elif [[ $splunk_role == "DS" ]]; then
    echo "Configuring for Deployment Server (DS)..."

    # Create all-ds-base directory
    mkdir -p /opt/splunk/etc/apps/all-ds-base/local

    # Create web.conf
    cat <<EOF > /opt/splunk/etc/apps/all-ds-base/local/web.conf
[settings]
enableSplunkWebSSL = true
max_upload_size = 2048
EOF

elif [[ $splunk_role == "IDX" ]]; then
    echo "Configuring for Indexer (IDX)..."

    # Create all-idx-base directory
    mkdir -p /opt/splunk/etc/apps/all-idx-base/local

    # Create web.conf
    cat <<EOF > /opt/splunk/etc/apps/all-idx-base/local/web.conf
[settings]
enableSplunkWebSSL = true
max_upload_size = 2048
EOF

    # Create all-indexes directory
    mkdir -p /opt/splunk/etc/apps/all-indexes/local

    # Download indexes.conf
    echo "Downloading indexes.conf..."
    wget -O /opt/splunk/etc/apps/all-indexes/local/indexes.conf "https://raw.githubusercontent.com/h3rrry/splunk-implemntation/refs/heads/main/indexes.conf"
else
    echo "Invalid role entered. Please run the script again and enter 'HF', 'DS', or 'IDX'."
    exit 1
fi

# Test connection to Indexer IP on port 9997 if it's HF
if [[ $splunk_role == "HF" ]]; then
    echo
    echo "Testing connection to Indexer IP ($idx_ip) on port 9997..."
    nc -zv $idx_ip 9997

    if [[ $? -eq 0 ]]; then
        echo "Connection to $idx_ip on port 9997 is successful!"
    else
        echo "Failed to connect to $idx_ip on port 9997. Please check the network or Indexer settings."
    fi
fi

# Prompt user for global banner details
echo
echo "Creating global banner configuration..."
mkdir -p /opt/splunk/etc/system/local
echo "What is the banner name?"
read banner_name
echo "What is the banner background color? Choose from (Blue, Green, Yellow, Orange, Red):"
read banner_color
banner_color=$(echo "$banner_color" | tr '[:upper:]' '[:lower:]')

# Map to correct case-sensitive values for Splunk
case "$banner_color" in
    blue)
        banner_color="Blue"
        ;;
    green)
        banner_color="Green"
        ;;
    yellow)
        banner_color="Yellow"
        ;;
    orange)
        banner_color="Orange"
        ;;
    red)
        banner_color="Red"
        ;;
    *)
        echo "Invalid color entered. Defaulting to Blue."
        banner_color="Blue"
        ;;
esac

# Create global-banner.conf
cat <<EOF > /opt/splunk/etc/system/local/global-banner.conf
[BANNER_MESSAGE_SINGLETON]
global_banner.background_color = $banner_color
global_banner.message = $banner_name
global_banner.visible = 1
EOF

echo "Global banner configuration created with name '$banner_name' and color '$banner_color'."

# Restart Splunk
runuser -l splunk -c '/opt/splunk/bin/splunk start'

if [[ -f /opt/splunk/bin/splunk ]]
then
    echo Splunk Enterprise
    cat /opt/splunk/etc/splunk.version | head -1
    echo "has been installed, configured, and started!"
    echo
    echo
    echo "     Splunk Enterprise Installed Successfully by Nournet Administrators!!"
    echo
    echo
    echo
else
    echo Splunk Enterprise has FAILED install!
fi

# End of File
