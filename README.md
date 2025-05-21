# PacketFence-Aliyun-DNS-Challenge
A script for obtaining Let's Encrypt certificate with DNS Challenge for Aliyun domains in PacketFence

This script is tested only on PacketFence ZEN image.

# Deployment

Change `DOMAIN`, `SUBDOMAIN`, and `EMAIL` in `letsencrypt-renew.sh`

Upload `letsencrypt-renew.sh` to /usr/local/pf/conf/"

Give the script permission to run with `chmod +x /usr/local/pf/conf/letsencrypt-renew.sh`

Make sure python3-venv package is installed (e.g., apt install python3-venv)."

Save Aliyun DNS credentials in /usr/local/pf/conf/aliyun.ini." 
For the cerbot Aliyun DNS plugin and the tutorial of obtaining credentials, please refer to https://github.com/tengattack/certbot-dns-aliyun

aliyun.ini example
```
# Aliyun DNS API credentials
dns_aliyun_access_key = example
dns_aliyun_access_key_secret = example
```

Run the script to obtain Let's Encrypt certificate and configure PacketFence to use it for HTTP and RADIUS.

In the first run, it will create a virtualenv for certbot and aliyun dns plugin in /opt/certbot-dns-aliyun. 
If you encounter any errors, try to remove the folder `rm -R /opt/certbot-dns-aliyun` and execute the script again.

The script comes with the following options:

  --force-config-packetfence  Force PacketFence configuration (copying certs and restarting services) even if the certificate does not need renewal.
  
  --force-renewal             Force Certbot to attempt renewal even if the certificate is not nearing expiration.
  
  -h, --help                  Display this help message and exit.

  
