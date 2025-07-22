# PacketFence Certificate DNS Challenge

Automated Let's Encrypt certificate management for PacketFence using DNS challenges. This repository provides scripts for two popular DNS providers:

## Supported DNS Providers

- **[Aliyun (Alibaba Cloud)](/aliyun)** - For domains managed by Aliyun DNS
- **[Cloudflare](/cloudflare)** - For domains managed by Cloudflare DNS

## Overview

These scripts automate the process of:
1. Obtaining Let's Encrypt certificates using DNS-01 challenge
2. Automatically configuring PacketFence to use the new certificates
3. Restarting required services (HTTP and RADIUS)
4. Setting up certificate renewal

## Which Version Should I Use?

Choose the version based on your DNS provider:

| DNS Provider | Directory | When to Use |
|--------------|-----------|-------------|
| Aliyun | [`/aliyun`](/aliyun) | If your domain's DNS is managed by Alibaba Cloud (Aliyun) |
| Cloudflare | [`/cloudflare`](/cloudflare) | If your domain's DNS is managed by Cloudflare |

## Requirements

- PacketFence ZEN image (tested environment)
- Python 3 with venv support
- Appropriate DNS provider credentials
- Domain with admin access for DNS record modification

## Quick Start

1. **Choose your DNS provider** from the table above
2. **Navigate to the corresponding directory** (`aliyun/` or `cloudflare/`)
3. **Follow the specific README** in that directory for detailed setup instructions

## Features

- ✅ Automatic certificate renewal
- ✅ PacketFence integration (HTTP & RADIUS)
- ✅ Service restart automation
- ✅ Virtual environment management
- ✅ Force renewal options
- ✅ Comprehensive error handling

## Support

Each DNS provider implementation is located in its own directory with specific documentation:

- [Aliyun Setup Guide](/aliyun/README.md)
- [Cloudflare Setup Guide](/cloudflare/README.md)

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file. 