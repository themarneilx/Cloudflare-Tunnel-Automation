#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================="
echo "  Cloudflare Tunnel Automation Script"
echo "=========================================="
echo ""

# 1. Authentication Check
CERT_FILE="$HOME/.cloudflared/cert.pem"

if [ -f "$CERT_FILE" ]; then
    echo "✅ Existing Cloudflare certificate found."
    read -p "Do you want to log in to a DIFFERENT Cloudflare account? (y/N): " DIFF_ACCT
    if [[ "$DIFF_ACCT" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Backing up the old certificate..."
        # Renames the old cert with a timestamp so you don't lose it
        mv "$CERT_FILE" "${CERT_FILE}.bak_$(date +%F_%H-%M-%S)"
        
        echo "Please follow the prompt below to authenticate in your browser."
        echo "------------------------------------------------------------"
        cloudflared tunnel login
        echo "------------------------------------------------------------"
        echo "Authentication complete!"
        echo ""
    else
        echo "Proceeding with the current logged-in account..."
        echo ""
    fi
else
    read -p "No certificate found. Do you want to log in to Cloudflare? (y/N): " LOGIN_CHOICE
    if [[ "$LOGIN_CHOICE" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Please follow the prompt below to authenticate in your browser."
        echo "------------------------------------------------------------"
        cloudflared tunnel login
        echo "------------------------------------------------------------"
        echo "Authentication complete!"
        echo ""
    else
        echo "Skipping Cloudflare login..."
        echo ""
    fi
fi

# 2. Gather Information
read -p "1. Enter the new tunnel name (e.g., myapp): " TUNNEL_NAME
read -p "2. Enter the public hostname (e.g., myapp.yourdomain.com): " HOSTNAME
read -p "3. Enter the local service address (e.g., http://localhost:8080): " LOCAL_SERVICE

echo ""
echo "Creating tunnel '$TUNNEL_NAME'..."

# 3. Create the tunnel
cloudflared tunnel create "$TUNNEL_NAME"

# 4. Get the UUID of the newly created tunnel
UUID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')

if [ -z "$UUID" ]; then
    echo "Error: Could not retrieve Tunnel UUID. Was it created successfully?"
    exit 1
fi

echo "Success! Tunnel created with UUID: $UUID"
echo ""

# 5. Move the credentials file to /etc/cloudflared/
echo "Moving credentials file to /etc/cloudflared/$TUNNEL_NAME-creds.json..."
sudo mv "$HOME/.cloudflared/$UUID.json" "/etc/cloudflared/$TUNNEL_NAME-creds.json"

# 6. Create the configuration file
echo "Generating configuration file /etc/cloudflared/$TUNNEL_NAME.yml..."
sudo tee "/etc/cloudflared/$TUNNEL_NAME.yml" > /dev/null <<EOF
tunnel: $UUID
credentials-file: /etc/cloudflared/$TUNNEL_NAME-creds.json

ingress:
  - hostname: $HOSTNAME
    service: $LOCAL_SERVICE
  - service: http_status:404
EOF

# 7. Route DNS
echo "Routing DNS for $HOSTNAME..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$HOSTNAME"

# 8. Set correct permissions for systemd DynamicUser
echo "Setting file permissions to 644..."
sudo chmod 644 "/etc/cloudflared/$TUNNEL_NAME-creds.json"
sudo chmod 644 "/etc/cloudflared/$TUNNEL_NAME.yml"

# 9. Enable and start the service
echo "Enabling and starting systemd service cloudflared@$TUNNEL_NAME.service..."
sudo systemctl daemon-reload
sudo systemctl enable --now "cloudflared@$TUNNEL_NAME.service"

echo ""
echo "=========================================="
echo " Done! Here is the status of your tunnel: "
echo "=========================================="
sudo systemctl status "cloudflared@$TUNNEL_NAME.service" --no-pager
