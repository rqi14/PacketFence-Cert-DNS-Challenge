# Troubleshooting Guide

## DNS Verification Failure Issues

### Problem Description
If you encounter the following error:
```
Certbot failed to authenticate some domains (authenticator: dns-cloudflare). The Certificate Authority reported these problems:
  Domain: pfm.in.langmubio.com
  Type:   unauthorized
  Detail: No TXT record found at _acme-challenge.pfm.in.langmubio.com
```

### Solutions

#### 1. Increase DNS Propagation Wait Time
The script is now set to 60 seconds by default. If it still fails, you can increase it further:

Edit the `letsencrypt-renew.sh` file and modify this line:
```bash
DNS_PROPAGATION_SECONDS=60
```
Change to:
```bash
DNS_PROPAGATION_SECONDS=120  # or higher
```

#### 2. Verify DNS Records
Run the DNS test script:
```bash
chmod +x test-dns.sh
./test-dns.sh
```

#### 3. Check Cloudflare Settings
1. Log in to your Cloudflare dashboard
2. Ensure the domain is added to Cloudflare
3. Check if DNS records are configured correctly
4. Verify API token permissions:
   - Zone:Zone:Read
   - Zone:DNS:Edit

#### 4. Manually Verify DNS Propagation
Use the following commands to check DNS records:
```bash
# Check A records
dig +short A pfm.in.langmubio.com

# Check TXT records
dig +short TXT _acme-challenge.pfm.in.langmubio.com

# Use different DNS servers
dig +short A pfm.in.langmubio.com @8.8.8.8
dig +short A pfm.in.langmubio.com @1.1.1.1
```

#### 5. Check Network Connectivity
Ensure the server can access:
- api.cloudflare.com
- acme-v02.api.letsencrypt.org

#### 6. Clean Up Old DNS Records
If it failed before, you may need to clean up old _acme-challenge records:
1. Log in to your Cloudflare dashboard
2. Find and delete all `_acme-challenge.*` TXT records
3. Re-run the script

#### 7. Use Debug Mode
Run the script with detailed output:
```bash
bash -x ./letsencrypt-renew.sh
```

### Common Issues

#### Q: DNS records are created but verification still fails
A: This is usually caused by DNS propagation delays. Try increasing the `DNS_PROPAGATION_SECONDS` value.

#### Q: Only some domains fail verification
A: Check if the failed domains are properly configured in Cloudflare and ensure the API token has sufficient permissions.

#### Q: Script successfully creates DNS records but Let's Encrypt cannot verify
A: This may be a network issue or DNS propagation delay. Wait a few minutes and retry, or increase the propagation wait time.

### Contact Support
If the problem persists, please provide:
1. Complete error logs
2. DNS test script output
3. Cloudflare DNS settings screenshots
4. Network connectivity test results 