# **Cloudflare Tunnel Automation Script**

A streamlined bash script to automate the creation, configuration, and deployment of multiple Cloudflare Tunnels on a single Linux machine using systemd templates.  
If you want to run multiple tunnels on one server without dealing with messy default configurations or manual file tracking, this script handles the entire lifecycle for you.

## **Features**

* **Smart Authentication**: Automatically detects if you're already logged in. Allows you to back up existing certificates if you need to switch Cloudflare accounts.  
* **Interactive Prompts**: Simply input your tunnel name, target domain, and local service address.  
* **Clean Configuration**: Moves and renames credential files (UUID.json → appname-creds.json) and generates a dedicated YAML config for each tunnel.  
* **DNS Routing**: Automatically routes your chosen hostname to the newly created tunnel.  
* **Systemd Integration**: Configures permissions and spins up the tunnel using a clean cloudflared@.service template.

## **Prerequisites**

1. **cloudflared installed**: Make sure the Cloudflare daemon is installed on your machine.  
2. **sudo privileges**: The script needs to move files to /etc/cloudflared/ and reload systemd daemons.  
3. **Systemd Template Unit**: This script relies on a template service. Before using the script, create the template:  
   sudo nano /etc/systemd/system/cloudflared@.service

   Paste the following configuration:  
   \[Unit\]  
   Description=Cloudflare Tunnel for %I  
   After=network.target network-online.target  
   Wants=network-online.target

```   
[Unit]
Description=Cloudflare Tunnel for %I
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/cloudflared tunnel --config /etc/cloudflared/%i.yml run
Restart=always
RestartSec=5s
DynamicUser=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```
## **Installation**

1. Clone this repository or download the script:  
   curl \-O \[https://raw.githubusercontent.com/YOUR\_USERNAME/YOUR\_REPO/main/create-tunnel.sh\](https://raw.githubusercontent.com/YOUR\_USERNAME/YOUR\_REPO/main/create-tunnel.sh)

2. Make the script executable:  
   chmod \+x create-tunnel.sh

## **Usage**

Run the script from your terminal:  
./create-tunnel.sh

### **Example Walkthrough**

1. **Authentication**: It will ask if you need to log in or switch accounts.  
2. **Tunnel Name**: myapp (This will be the internal name and prefix for your config files).  
3. **Public Hostname**: myapp.yourdomain.com (The URL you want to expose).  
4. **Local Service**: http://localhost:8080 (The internal IP and port of your app).

The script will output the progress, automatically register the DNS with Cloudflare, and start the systemd service (cloudflared@myapp.service).

## **Behind the Scenes**

When you create a tunnel named newapp, the script organizes your files perfectly in /etc/cloudflared/:

* /etc/cloudflared/newapp-creds.json (Your renamed Tunnel UUID credentials)  
* /etc/cloudflared/newapp.yml (Your custom routing configuration)

You can check the status of any individual tunnel at any time using:  
sudo systemctl status cloudflared@newapp.service

