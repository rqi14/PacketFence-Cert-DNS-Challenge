# Troubleshooting Guide

## DNS Verification Failure Issues

### Problem Description
If you encounter the following error:
```
Certbot failed to authenticate some domains (authenticator: dns-aliyun). The Certificate Authority reported these problems:
  Domain: example.com
  Type:   unauthorized
  Detail: No TXT record found at _acme-challenge.example.com
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
Use the following commands to check DNS records:
```bash
# Check A records
dig +short A your-domain.com

# Check TXT records
dig +short TXT _acme-challenge.your-domain.com

# Use different DNS servers
dig +short A your-domain.com @8.8.8.8
dig +short A your-domain.com @1.1.1.1
```

#### 3. Check Aliyun DNS Settings
1. Log in to your Aliyun console
2. Ensure the domain is added to Aliyun DNS
3. Check if DNS records are configured correctly
4. Verify API credentials permissions:
   - DNS management permissions
   - Access to the specific domain zone

#### 4. Check Network Connectivity
Ensure the server can access:
- alidns.aliyuncs.com
- acme-v02.api.letsencrypt.org

#### 5. Clean Up Old DNS Records
If it failed before, you may need to clean up old _acme-challenge records:
1. Log in to your Aliyun console
2. Find and delete all `_acme-challenge.*` TXT records
3. Re-run the script

#### 6. Use Debug Mode
Run the script with detailed output:
```bash
bash -x ./letsencrypt-renew.sh
```

### Common Issues

#### Q: DNS records are created but verification still fails
A: This is usually caused by DNS propagation delays. Try increasing the `DNS_PROPAGATION_SECONDS` value.

#### Q: Only some domains fail verification
A: Check if the failed domains are properly configured in Aliyun DNS and ensure the API credentials have sufficient permissions.

#### Q: Script successfully creates DNS records but Let's Encrypt cannot verify
A: This may be a network issue or DNS propagation delay. Wait a few minutes and retry, or increase the propagation wait time.

### Contact Support
If the problem persists, please provide:
1. Complete error logs
2. DNS query results
3. Aliyun DNS settings screenshots
4. Network connectivity test results 