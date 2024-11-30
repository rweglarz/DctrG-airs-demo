#!/bin/bash

INSTANCE_NAME=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/name")
echo "Running on instance: $INSTANCE_NAME"

# Set up logging
exec 1> >(tee -a /var/log/startup-script.log) 2>&1
echo "[$(date)] Starting startup script..."

# Exit on any error
set -ex

# Install prerequisites
echo "[$(date)] Installing prerequisites..."
apt-get update
apt-get install -y python3-pip python3-venv git

# Create and activate virtual environment
echo "[$(date)] Setting up virtual environment..."
python3 -m venv /root/venv
source /root/venv/bin/activate


cat <<EOF > /etc/ssl/certs/root_ca.pem
-----BEGIN CERTIFICATE-----
MIIE1jCCAr6gAwIBAgIFAIKd1VUwDQYJKoZIhvcNAQELBQAwHTEbMBkGA1UEAxMS
UldFIFNDTSBVUyBST09UIENBMB4XDTI0MTEyMTE2MTQyOVoXDTI4MTIzMDE2MTQy
OVowHTEbMBkGA1UEAxMSUldFIFNDTSBVUyBST09UIENBMIICIjANBgkqhkiG9w0B
AQEFAAOCAg8AMIICCgKCAgEAqn/jcdEXGUmMaFWYCOmt+nMMxptir6KTxhH94yg1
lXtLQRzpNn1RkwJLu7nRKq6v0B6kdVYlde5Yb/v0m6tytzkxokQa0Eb1dbLwts2J
teMRxx2/5cUK2G5+DH5/AFllRBjMm1KtrJB92UxRiO/NDZ+q6CID/jtSw+CXlSb1
QGo/xXbSWxunun4BG9GuQskYDYZeUMnuFL4vBQzsIqVMqHSoKjzHn+DvUARE/4ls
bXxOC1qkkQKqZDdeoYlBsKTOC0sP9nTnM6F8ChmCthb8+Rqj7u/eBgi7Ey3yfO28
9b7mT5u2CXdVeKT3y+DCqxdoKYT+6f/jcnOfLnuZQwxA5SzOafS/dU45fln2J2vn
wMiIXxJESq4OqjVEYjkjVMGcsZz31yq2Du5dz3xnEtTe3rY4h7L7dEBlWwhxTh33
Lbt8/W4wfoZBFK/FwjmpGxpuCnh/SUb51WPX2Iexaja59hq/iFYVCn8oUvqjRV9f
APCLXUrkQVpdIaOmVnGDZauURvbm39xK9iB1r3jrWj9BoXijArVAwApPlIyglxfj
JmhbuepG+J1vTe3u+iYC8hi3CDod7TcnfInPjtZawlFqbSBIiZUyxZBJ+z2U6CWb
GpQHPrnAUuiq8+Hb/KrYB4TT1DHLkIZEzAICi/0mbGRrQqk0FIkKpprJkkysIzqk
ztcCAwEAAaMdMBswDAYDVR0TBAUwAwEB/zALBgNVHQ8EBAMCAgQwDQYJKoZIhvcN
AQELBQADggIBAGxnjwjwMDuXAmBVslw6fBa5CI5of5zUGFyf8i8pRo+N5IhetWpr
W6iIOwJhrOBTfAoawEUEAAcIC9dgzMOWG9osRygYEjQv7If5LmHaWXDMxEp4/s4F
c25PR1MQwU6Mrc+lLcAbXyzcP1i9YnS8stYOlwk8JN/lwmasEWTRdGSrLVTURcXd
WcsrUkO7J5FeaDh+g7E7sfg1XR/SBFL+JXCwhWGSb/6OiYOky/XoiokbUnnQzvTy
IN3dlANH84jOsUrbNmFCqJMoQCLSMVnkL2xpvS82XRqT+IZNgXoct15DprmzRJ8v
YlN1dfsFKOv9kP1BXeZQ5fNudm8Osu4nhB6M50e4tnJF50rjx4yLLPU3ODkLrDUe
qXP/UgaCFR29g4cy/6My1rsxXWfNP13isDK3QyKOvRC9uul04Qa6OwEdQIzL7ocj
KdEIu+N4WAmK89YXUHgV7TvtFEGZ3wl6DSbU0tWeuVUluh7eN99JQarEgE/Dfmb6
E80h7HoYgYPpNsnD3gvP9aWr0Ynpx8s9GZMrZo9pwmYwP423DBS7F1jhx3joMBQJ
FsNXcC/kTC/acYTSFXN7JjI0Vz763fM2wZxafcqnldoWHB5A9zXt4SxtUwe0bHZr
f9bXuIb/izwiA2K8Va3EI2COsm9+aXn2jA41zvihL1ydCij2c1Enz2w4
-----END CERTIFICATE-----
EOF

# Set up environment variables
echo "[$(date)] Setting up environment variables..."
echo "export SSL_CERT_FILE=/etc/ssl/certs/root_ca.pem" >> /root/.bashrc
echo "export REQUESTS_CA_BUNDLE=/etc/ssl/certs/root_ca.pem" >> /root/.bashrc
echo "export GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=/etc/ssl/certs/root_ca.pem" >> /root/.bashrc


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

echo "[$(date)] Cloning repository..."
git clone https://github.com/DctrG/apps.git
cd apps

echo "[$(date)] Installing requirements..."
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt

echo "[$(date)] Copying files..."
if [ -f "bank-app.sh" ]; then
    cp bank-app.sh /usr/bin/
    chmod +x /usr/bin/bank-app.sh
else
    echo "Error: bank-app.sh not found"
    exit 1
fi

if [ -f "gemini-app.py" ]; then
    cp gemini-app.sh /usr/bin/
    chmod +x /usr/bin/gemini-app.sh
else
    echo "Error: gemini-app.py not found"
    exit 1
fi

if [[ "$INSTANCE_NAME" == "ai-vm-protected" ]]; then
    echo "Configuring protected instance..."
    mv bank-app-protected.py bank-app.py
fi

if [[ "$INSTANCE_NAME" == "ai-vm-unprotected" ]]; then
    echo "Configuring protected instance..."
    mv bank-app-unprotected.py bank-app.py
fi

if [[ "$INSTANCE_NAME" == "ai-vm-api" ]]; then
    echo "Configuring api instance..."
    mv bank-app-api.py bank-app.py
fi

# Create service files with environment variables
echo "[$(date)] Creating service files..."

cat > /etc/systemd/system/bank-app.service << 'EOL'
[Unit]
Description=Bank App Service
After=network.target

[Service]
Environment=SSL_CERT_FILE=/etc/ssl/certs/root_ca.pem
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/root_ca.pem
Environment=GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=/etc/ssl/certs/root_ca.pem
ExecStart=/usr/bin/bank-app.sh
Restart=always
User=root
WorkingDirectory=/home/paloalto/apps

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/gemini-app.service << 'EOL'
[Unit]
Description=Gemini App Service
After=network.target

[Service]
# Environment=SSL_CERT_FILE=/etc/ssl/certs/root_ca.pem
# Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/root_ca.pem
# Environment=GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=/etc/ssl/certs/root_ca.pem
ExecStart=/usr/bin/gemini-app.sh
Restart=always
User=root
WorkingDirectory=/home/paloalto/apps

[Install]
WantedBy=multi-user.target
EOL

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
