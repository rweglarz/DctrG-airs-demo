#!/bin/bash

INSTANCE_NAME=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/name")
AIRS_API_KEY=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/airs-api-key")
AIRS_PROFILE_NAME=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/airs-profile-name")

echo "Running on instance: $INSTANCE_NAME"

# Set up logging
exec 1> >(tee -a /var/log/startup-script.log) 2>&1
echo "[$(date)] Starting startup script..."

# Exit on any error
set -ex


cat <<EOF > /usr/local/share/ca-certificates/pan_decrypt.crt
${decrypt_cert}
EOF
/usr/sbin/update-ca-certificates


# Install prerequisites
echo "[$(date)] Installing prerequisites..."
apt-get update
apt-get install -y python3-pip python3-venv git



# Set up environment variables
if [[ "$INSTANCE_NAME" == "ai-vm-protected" ]]; then
    echo "[$(date)] Setting up environment variables..."
    echo "export SSL_CERT_FILE=/usr/local/share/ca-certificates/pan_decrypt.crt" >> /root/.bashrc
    echo "export REQUESTS_CA_BUNDLE=/usr/local/share/ca-certificates/pan_decrypt.crt" >> /root/.bashrc
    echo "export GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=/usr/local/share/ca-certificates/pan_decrypt.crt" >> /root/.bashrc
else
    echo "[$(date)] Skipping environment variables..."
fi

source /root/.bashrc

# Stop service if exists
echo "[$(date)] Handling bank-app service..."
if systemctl list-unit-files | grep -q bank-app.service; then
    systemctl stop bank-app.service
fi

# Setup application
echo "[$(date)] Setting up application..."
cd /home/paloalto || mkdir -p /home/paloalto && cd /home/paloalto
[ -d "apps" ] && rm -rf apps

# Create and activate virtual environment
echo "[$(date)] Setting up virtual environment..."
python3 -m venv /root/venv
source /root/venv/bin/activate

echo "[$(date)] Cloning repository..."
git clone ${apps_github.path} --branch ${apps_github.branch} apps
cd apps

echo "[$(date)] Installing requirements..."
pip install -r requirements.txt

echo "[$(date)] Copying files..."
if [ -f "bank-app.sh" ]; then
    cp bank-app.sh /usr/local/bin/
    chmod +x /usr/local/bin/bank-app.sh
else
    echo "Error: bank-app.sh not found"
    exit 1
fi

if [ -f "gemini-app.sh" ]; then
    cp gemini-app.sh /usr/local/bin/
    chmod +x /usr/local/bin/gemini-app.sh
else
    echo "Error: gemini-app.sh not found"
    exit 1
fi

if [[ "$INSTANCE_NAME" == "ai-vm-protected" ]]; then
    echo "Configuring protected instance..."
    ln -s bank-app-protected.py bank-app.py
elif [[ "$INSTANCE_NAME" == "ai-vm-unprotected" ]]; then
    echo "Configuring unprotected instance..."
    ln -s bank-app-unprotected.py bank-app.py
elif [[ "$INSTANCE_NAME" == "ai-vm-api" ]]; then
    echo "Configuring api instance..."
    ln -s bank-app-api.py bank-app.py
else 
    echo "what is this instance?"
    exit 1
fi

# Create service files with environment variables
echo "[$(date)] Creating service files..."




cat > /etc/systemd/system/bank-app.service << EOL
[Unit]
Description=Bank App Service
After=network.target

[Service]
Environment=AIRS_API_KEY=$AIRS_API_KEY
Environment=AIRS_PROFILE_NAME=$AIRS_PROFILE_NAME
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/local/bin/bank-app.sh
Restart=always
User=root
WorkingDirectory=/home/paloalto/apps

[Install]
WantedBy=multi-user.target
EOL


# just overwrite the file for protected vm
if [[ "$INSTANCE_NAME" == "ai-vm-protected" ]]; then
cat > /etc/systemd/system/bank-app.service << 'EOL'
[Unit]
Description=Bank App Service
After=network.target

[Service]
Environment=SSL_CERT_FILE=/usr/local/share/ca-certificates/pan_decrypt.crt
Environment=REQUESTS_CA_BUNDLE=/usr/local/share/ca-certificates/pan_decrypt.crt
Environment=GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=/usr/local/share/ca-certificates/pan_decrypt.crt
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/local/bin/bank-app.sh
Restart=always
User=root
WorkingDirectory=/home/paloalto/apps

[Install]
WantedBy=multi-user.target
EOL
fi





cat > /etc/systemd/system/gemini-app.service << 'EOL'
[Unit]
Description=Gemini App Service
After=network.target

[Service]
ExecStart=/usr/local/bin/gemini-app.sh
Restart=always
User=root
WorkingDirectory=/home/paloalto/apps

[Install]
WantedBy=multi-user.target
EOL


# just overwrite the file for protected vm
if [[ "$INSTANCE_NAME" == "ai-vm-protected" ]]; then
cat > /etc/systemd/system/gemini-app.service << 'EOL'
[Unit]
Description=Gemini App Service
After=network.target

[Service]
Environment=SSL_CERT_FILE=/usr/local/share/ca-certificates/pan_decrypt.crt
Environment=REQUESTS_CA_BUNDLE=/usr/local/share/ca-certificates/pan_decrypt.crt
Environment=GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=/usr/local/share/ca-certificates/pan_decrypt.crt
ExecStart=/usr/local/bin/gemini-app.sh
Restart=always
User=root
WorkingDirectory=/home/paloalto/apps

[Install]
WantedBy=multi-user.target
EOL
fi





# Reload systemd and start service
echo "[$(date)] Starting services..."
systemctl daemon-reload
systemctl enable bank-app.service
systemctl enable gemini-app.service
systemctl start bank-app.service
systemctl start gemini-app.service
systemctl status bank-app.service
systemctl status gemini-app.service

echo "[$(date)] Startup script completed"

