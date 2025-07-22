# PacketFence-Cloudflare-DNS-Challenge
A script for obtaining a Let's Encrypt certificate with DNS Challenge for Cloudflare domains in PacketFence

This script is tested only on the PacketFence ZEN image.

# Deployment

1.  **Modify Script Variables**
    In the `letsencrypt-renew.sh` script, modify the `DOMAIN`, `SUBDOMAINS`, and `EMAIL` variables at the top according to your requirements.

2.  **Upload Script**
    Upload `letsencrypt-renew.sh` to the `/usr/local/pf/conf/` directory on your PacketFence server.

3.  **Grant Execute Permission**
    Give the script execute permission with the command `chmod +x /usr/local/pf/conf/letsencrypt-renew.sh`.

4.  **Install Dependencies**
    Ensure the `python3-venv` package is installed. If not installed, use the following command (for Debian/Ubuntu):
    `apt update && apt install python3-venv`

5.  **Create Cloudflare API Token**
    This script requires a Cloudflare API token with permission to modify DNS records for your domain.
    * Log in to your Cloudflare dashboard.
    * Go to "My Profile" -> "API Tokens" -> "Create Token".
    * Select the "Edit zone DNS" template.
    * In the "Zone Resources" section, select the specific domain zone for which you need to obtain certificates.
    * Continue and create the token. **Make sure to copy the generated API token as it will only appear once.**

6.  **Save Cloudflare Credentials**
    Create a file named `cloudflare.ini` in the `/usr/local/pf/conf/` directory. The file content should be as follows, replacing `YOUR_API_TOKEN` with the token you created in the previous step:
    ```ini
    # Cloudflare API credentials
    dns_cloudflare_api_token = YOUR_API_TOKEN
    ```

7.  **Run the Script**
    Execute the script to obtain Let's Encrypt certificates and automatically configure PacketFence for HTTP and RADIUS services.
    `/usr/local/pf/conf/letsencrypt-renew.sh`

    On the first run, the script will create a Python virtual environment for certbot and the Cloudflare DNS plugin in the `/opt/certbot-dns-cloudflare` directory. If you encounter any errors, try removing the folder `rm -rf /opt/certbot-dns-cloudflare` and then re-execute the script.

## Script Options

The script supports the following command-line options:

  `--force-config-packetfence`  Force PacketFence configuration (copying certificates and restarting services) even if the certificate is not renewed.
  
  `--force-renewal`             Force Certbot to attempt renewal even if the certificate is not nearing expiration.
  
  `-h, --help`                  Display this help message and exit.