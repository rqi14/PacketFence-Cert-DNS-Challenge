# PacketFence-Aliyun-DNS-Challenge
A script for obtaining Let's Encrypt certificate with DNS Challenge for Aliyun domains in PacketFence

This script is tested only on PacketFence ZEN image.

# Deployment

Upload `letsencrypt-renew.sh` to /usr/local/pf/conf/"

Make sure python3-venv package is installed (e.g., apt install python3-venv)."

Save Aliyun DNS credentials in /usr/local/pf/conf/aliyun.ini." 
For the cerbot Aliyun DNS plugin and the tutorial of obtaining credentials, please refer to https://github.com/tengattack/certbot-dns-aliyun

aliyun.ini example
```
# Aliyun DNS API credentials
dns_aliyun_access_key = example
dns_aliyun_access_key_secret = example
```
