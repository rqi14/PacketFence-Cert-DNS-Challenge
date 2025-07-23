# Changelog

## [2025-07-23] - DNS Propagation Improvements

### Added
- **DNS Propagation Wait Time**: Added configurable DNS propagation wait time for both Cloudflare and Aliyun scripts
  - Default: 60 seconds (increased from 10 seconds)
  - Configurable via `DNS_PROPAGATION_SECONDS` variable
  - Helps resolve DNS verification failures

### Enhanced
- **Cloudflare Script** (`cloudflare/letsencrypt-renew.sh`):
  - Added `--dns-cloudflare-propagation-seconds` parameter
  - Added troubleshooting information in help output
  - Improved error handling for DNS verification failures

- **Aliyun Script** (`aliyun/letsencrypt-renew.sh`):
  - Added `--dns-aliyun-propagation-seconds` parameter
  - Added troubleshooting information in help output
  - Improved error handling for DNS verification failures

### Documentation
- **Troubleshooting Guides**: Created comprehensive troubleshooting guides for both DNS providers
  - `cloudflare/TROUBLESHOOTING.md`
  - `aliyun/TROUBLESHOOTING.md`
  - Includes common issues and solutions
  - Step-by-step troubleshooting procedures

- **README Updates**: Enhanced README files with troubleshooting sections
  - Added common issues and solutions
  - Included DNS propagation information
  - Added links to troubleshooting guides

### Fixed
- **DNS Verification Failures**: Resolved issues where Let's Encrypt could not find DNS TXT records
- **Language Consistency**: Ensured all documentation and comments are in English
- **Error Handling**: Improved error messages and troubleshooting guidance

### Technical Details
- DNS propagation wait time is now configurable per script
- Both scripts use the same approach for consistency
- All documentation is now in English for better international support
- Added comprehensive troubleshooting procedures for common DNS issues 