#!/bin/bash

# ============== Customizable Variables ==============
DOMAIN="pf.example.com"
# Comma-separated list of additional hostnames to include as Subject Alternative Names (SANs).
# Entries can be subdomain prefixes (e.g., "www", "api") which will be appended to DOMAIN,
# or fully qualified domain names (FQDNs) (e.g., "sub.example.com", "other.net").
# Example: if DOMAIN is "example.com" and SUBDOMAINS is "www,portal.example.com,backup.net",
# the certificate will cover "example.com", "www.example.com", "portal.example.com", and "backup.net".
# Leave empty if no additional hostnames are needed.
SUBDOMAINS="pfm.example.com"
EMAIL="user@example.com"

# DNS propagation wait time in seconds (default: 60)
# Increase this value if you experience DNS verification failures
DNS_PROPAGATION_SECONDS=60

VENV_PATH="/opt/certbot-dns-aliyun"
CREDENTIALS_FILE="/usr/local/pf/conf/aliyun.ini"

HTTP_CERT_DIR="/usr/local/pf/conf/ssl"
RADIUS_CERT_DIR="/usr/local/pf/raddb/certs"
# Note: LOG_FILE is mentioned in cron job examples, not directly used by this script for its own logging.
# A cron job would typically redirect output: /path/to/script.sh >> /var/log/letsencrypt-renew.log 2>&1
# ====================================================

# Script behavior / Default values
FORCE_CONFIG=false # This will be updated by command line arguments if provided
FORCE_CERTBOT_RENEWAL=false # This will be updated by command line arguments if provided
MAX_RETRIES=5
INITIAL_RETRY_INTERVAL=3 # Start with a shorter interval
MAX_SINGLE_RETRY_INTERVAL=15 # Max seconds for a single sleep

# Function to display help message
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script obtains/renews Let's Encrypt certificates using certbot with the dns-aliyun plugin,"
    echo "installs them for PacketFence (HTTP and RADIUS), and restarts relevant services."
    echo ""
    echo "Options:"
    echo "  --force-config-packetfence  Force PacketFence configuration (copying certs and restarting"
    echo "                                services) even if the certificate does not need renewal."
    echo "  --force-renewal             Force Certbot to attempt renewal even if the certificate is not"
    echo "                                nearing expiration."
    echo "  -h, --help                  Display this help message and exit."
    echo ""
    echo "Prerequisites:"
echo "  - python3-venv package must be installed (e.g., apt install python3-venv)."
echo "  - Aliyun DNS credentials must be in /usr/local/pf/conf/aliyun.ini."
echo ""
echo "Troubleshooting:"
echo "  - If DNS verification fails, try increasing DNS_PROPAGATION_SECONDS (default: 60)"
echo "  - Check that your Aliyun API credentials have the necessary permissions"
echo "  - Ensure the domains are properly configured in Aliyun DNS"
exit 0
}

# Function to get service status
get_service_status() {
    local service=$1
    /usr/local/pf/bin/pfcmd service "$service" status
}

# Function to check if service status matches expected state
check_service_status() {
    local service=$1
    local expected_status=$2
    local current_status=$(get_service_status "$service")
    local actual_status=""

    # Try to parse the standard output: Header line, then data line.
    # If first line has "Service", "Status", "PID", then second line's 2nd field is the status.
    # For "radiusd", this will take the status of the first sub-service listed.
    actual_status=$(echo "$current_status" | awk '
        NR==1 && /Service/ && /Status/ && /PID/ { getline_flag=1; next }
        getline_flag==1 { print $2; exit }
    ')

    echo "DEBUG: For service '$service', expected '$expected_status', current_status was:"
    echo "$current_status"
    echo "DEBUG: Parsed actual_status: '$actual_status'"

    if [ -n "$actual_status" ] && [ "$actual_status" = "$expected_status" ]; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to reach expected state
wait_for_service() {
    local service=$1
    local expected_status=$2
    local retries=0
    local current_sleep_interval=$INITIAL_RETRY_INTERVAL
    
    echo "Waiting for $service to reach status: $expected_status"

    # Initial check before any waiting
    if check_service_status "$service" "$expected_status"; then
        echo "$service is now $expected_status (checked immediately after restart)."
        return 0
    fi
    echo "Initial check failed for $service, entering retry loop."

    while [ $retries -lt $MAX_RETRIES ]; do
        echo "Attempt $((retries + 1))/$MAX_RETRIES: $service not yet $expected_status, waiting ${current_sleep_interval}s..."
        sleep $current_sleep_interval
        if check_service_status "$service" "$expected_status"; then
            echo "$service is now $expected_status"
            return 0
        fi
        retries=$((retries + 1))
        current_sleep_interval=$((current_sleep_interval + INITIAL_RETRY_INTERVAL))
        if [ $current_sleep_interval -gt $MAX_SINGLE_RETRY_INTERVAL ]; then
            current_sleep_interval=$MAX_SINGLE_RETRY_INTERVAL
        fi
    done
    
    echo "Error: $service failed to reach status $expected_status after $MAX_RETRIES attempts"
    return 1
}

# Function to restart service with status checking
restart_service() {
    local service_name_to_restart=$1 # e.g., haproxy-portal or radiusd
    echo "Restarting $service_name_to_restart..."

    if [ "$service_name_to_restart" = "radiusd" ]; then
        echo "Initial status of RADIUS services:"
        /usr/local/pf/bin/pfcmd service radiusd status

        declare -A initial_started_services
        local initial_status_output
        initial_status_output=$(/usr/local/pf/bin/pfcmd service radiusd status)
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^(packetfence-radiusd-[a-zA-Z0-9_-]+)\.service[[:space:]]+(started|stopped|disabled) ]]; then
                local sub_service_name="${BASH_REMATCH[1]}"
                local sub_service_status="${BASH_REMATCH[2]}"
                if [ "$sub_service_status" = "started" ]; then
                    initial_started_services["$sub_service_name"]="started"
                    echo "DEBUG: Initially $sub_service_name was $sub_service_status"
                fi
            fi
        done <<< "$initial_status_output"

        /usr/local/pf/bin/pfcmd service radiusd restart

        echo "Performing initial check for RADIUS services post-restart..."
        local all_restarted_successfully=false
        local current_status_output_immediate
        current_status_output_immediate=$(/usr/local/pf/bin/pfcmd service radiusd status)
        local services_to_check_count_immediate=${#initial_started_services[@]}
        local services_restarted_count_immediate=0

        if [ $services_to_check_count_immediate -eq 0 ]; then 
            echo "DEBUG: No RADIUS sub-services were initially 'started'. Assuming immediate success."
            all_restarted_successfully=true
        else
            for sub_service_name_immediate in "${!initial_started_services[@]}"; do
                local found_started_immediate=false
                while IFS= read -r current_line_immediate; do
                    if [[ "$current_line_immediate" =~ ^(${sub_service_name_immediate})\\.service[[:space:]]+(started|stopped|disabled|activating|deactivating|failed)[[:space:]]+([0-9]+|Service[[:space:]]+disabled)$ ]]; then
                        if [ "${BASH_REMATCH[2]}" = "started" ]; then
                            found_started_immediate=true
                            break
                        fi
                    fi
                done <<< "$current_status_output_immediate"
                if $found_started_immediate; then
                    services_restarted_count_immediate=$((services_restarted_count_immediate + 1))
                fi
            done
            if [ "$services_restarted_count_immediate" -eq "$services_to_check_count_immediate" ]; then
                echo "All initially started RADIUS sub-services confirmed restarted immediately."
                all_restarted_successfully=true
            else
                 echo "Initial check failed for some RADIUS services, entering retry loop."
            fi
        fi

        if [ "$all_restarted_successfully" = true ]; then
            echo "Final status of RADIUS services (checked immediately):"
            /usr/local/pf/bin/pfcmd service radiusd status
            return 0 # Exit restart_service for radiusd as it was successful immediately
        fi

        # If immediate check failed, proceed to polling loop
        echo "Waiting for RADIUS services to stabilize (polling)..."
        local retries=0
        local current_sleep_interval=$INITIAL_RETRY_INTERVAL
        # Reset all_restarted_successfully for the loop, though it should be false here
        all_restarted_successfully=false
        while [ $retries -lt $MAX_RETRIES ]; do
            local current_status_output
            current_status_output=$(/usr/local/pf/bin/pfcmd service radiusd status)
            local services_to_check_count=${#initial_started_services[@]}
            local services_restarted_count=0

            if [ $services_to_check_count -eq 0 ]; then 
                echo "DEBUG: No RADIUS sub-services were initially 'started'. Assuming success if main restart command didn't fail."
                all_restarted_successfully=true
                break
            fi

            for sub_service_name in "${!initial_started_services[@]}"; do
                echo "DEBUG: Checking sub-service: [$sub_service_name] against current_status_output:"
                local found_started_for_sub_service=false
                while IFS= read -r current_line; do
                    echo "DEBUG:   Current line: [$current_line]"
                    # Check if the line starts with the specific sub-service name we are looking for
                    if [[ "$current_line" == "${sub_service_name}.service"* ]]; then
                        echo "DEBUG:     Line starts with ${sub_service_name}.service. Checking for 'started'...'"
                        # Now check if this specific line also contains " started " followed by a PID
                        if [[ "$current_line" =~ [[:space:]]started[[:space:]]+[0-9]+$ ]]; then
                            echo "DEBUG:     REGEX MATCHED ' started [PID]' for $sub_service_name on line: [$current_line]"
                            found_started_for_sub_service=true
                            echo "DEBUG:       Found [$sub_service_name] as 'started'."
                            break # Found this sub-service as started, no need to check more lines for it
                        else
                            echo "DEBUG:     Line for $sub_service_name found, but not in 'started [PID]' state. Line: [$current_line]"
                        fi
                    fi
                done <<< "$current_status_output"

                if $found_started_for_sub_service; then
                    services_restarted_count=$((services_restarted_count + 1))
                else
                    echo "DEBUG: $sub_service_name is not 'started' yet in current output."
                fi
            done

            if [ "$services_restarted_count" -eq "$services_to_check_count" ]; then
                all_restarted_successfully=true
                echo "All initially started RADIUS sub-services have restarted successfully."
                break
            fi
            
            echo "Attempt $((retries + 1))/$MAX_RETRIES: Not all RADIUS services confirmed restarted, waiting ${current_sleep_interval}s..."
            sleep $current_sleep_interval
            retries=$((retries + 1))
            # Dynamically increase sleep interval, up to a max
            current_sleep_interval=$((current_sleep_interval + INITIAL_RETRY_INTERVAL))
            if [ $current_sleep_interval -gt $MAX_SINGLE_RETRY_INTERVAL ]; then
                current_sleep_interval=$MAX_SINGLE_RETRY_INTERVAL
            fi
        done

        if [ "$all_restarted_successfully" = false ]; then
            echo "Error: Not all initially started RADIUS sub-services restarted successfully after $MAX_RETRIES attempts."
        fi
        echo "Final status of RADIUS services:"
        /usr/local/pf/bin/pfcmd service radiusd status

    else # For non-radiusd services (e.g., haproxy-portal)
        echo "Initial status of $service_name_to_restart:"
        get_service_status "$service_name_to_restart"
        
        /usr/local/pf/bin/pfcmd service "$service_name_to_restart" restart
        
        wait_for_service "$service_name_to_restart" "started"
        
        echo "Final status of $service_name_to_restart:"
        get_service_status "$service_name_to_restart"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --force-config-packetfence)
            FORCE_CONFIG=true
            shift # past argument
            ;;
        --force-renewal)
            FORCE_CERTBOT_RENEWAL=true
            shift # past argument
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Ensure Python version for virtual environment path is determined correctly
PYTHON_VERSION=$(python3 -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}")')
export PYTHONPATH="${VENV_PATH}/lib/${PYTHON_VERSION}/site-packages:$PYTHONPATH"

# Create directories if they don't exist
mkdir -p "$HTTP_CERT_DIR" "$RADIUS_CERT_DIR"

# Check if python3-venv is installed (for Debian/Ubuntu)
if ! dpkg -s python3-venv > /dev/null 2>&1 && ! python3 -m venv -h > /dev/null 2>&1; then
    echo "Error: python3-venv package is not installed. This is required to create the virtual environment."
    echo "Please install it using the following command (you might need sudo):"
    PYTHON_MAJOR_MINOR_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    echo "  apt install python3-venv  # or potentially: apt install python${PYTHON_MAJOR_MINOR_VERSION}-venv"
    exit 1
fi

# Check if virtual environment exists, create if not
if [ ! -d "$VENV_PATH" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create virtual environment. Please check your python3-venv installation."
        exit 1
    fi
    echo "Upgrading pip and installing packages (certbot, certbot-dns-aliyun)..."
    "${VENV_PATH}/bin/pip" install --upgrade pip
    "${VENV_PATH}/bin/pip" install certbot==2.11.1 certbot-dns-aliyun
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install packages in virtual environment."
        exit 1
    fi
fi

# Check if aliyun.ini exists and has correct permissions
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Error: aliyun.ini file not found. Please create it with your Aliyun DNS credentials:"
    echo "  dns_aliyun_access_key = YOUR_ACCESS_KEY"
    echo "  dns_aliyun_access_key_secret = YOUR_ACCESS_KEY_SECRET"
    exit 1
fi

# Set secure permissions on credentials file
echo "Setting secure permissions on credentials file..."
chmod 600 "$CREDENTIALS_FILE"
chown root:root "$CREDENTIALS_FILE" # Assumes script is run as root or with sudo

# Check if we need to obtain a new certificate
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
NEED_RENEWAL=false # Default, will be set to true if conditions met

if [ "$FORCE_CERTBOT_RENEWAL" = true ]; then
    echo "Forcing renewal attempt as per --force-renewal flag."
    NEED_RENEWAL=true
elif [ -f "$CERT_PATH" ]; then
    # Check if certificate is valid for more than 30 days
    EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
    EXPIRY_SECONDS=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_SECONDS=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_SECONDS - $CURRENT_SECONDS) / 86400 ))
    
    if [ $DAYS_LEFT -gt 30 ]; then
        echo "Certificate is still valid for $DAYS_LEFT days."
        if [ "$FORCE_CONFIG" = false ]; then
            echo "Skipping renewal and configuration."
            exit 0
        else
            echo "Skipping renewal but will continue with configuration."
        fi
    else
        echo "Certificate needs renewal ($DAYS_LEFT days left)."
        NEED_RENEWAL=true
    fi
else
    echo "No existing certificate found for $DOMAIN. Will attempt to obtain a new one."
    NEED_RENEWAL=true
fi

# Get the certificate if needed
if [ "$NEED_RENEWAL" = true ]; then
    echo "Obtaining certificate for $DOMAIN..."

    declare -a cert_domains_args=("-d" "$DOMAIN")
    declare -a certbot_extra_args=() # Array for additional certbot flags like --force-renewal

    if [ "$FORCE_CERTBOT_RENEWAL" = true ]; then
        certbot_extra_args+=("--force-renewal")
    fi

    if [ -n "$SUBDOMAINS" ]; then
        echo "Processing additional hostnames (SANs): $SUBDOMAINS"
        declare -a temp_sub_array
        # Use mapfile and process substitution to split by comma and handle various spacings
        mapfile -t temp_sub_array < <(echo "$SUBDOMAINS" | tr ',' '\\n')

        for item in "${temp_sub_array[@]}"; do
            # Trim whitespace from each item
            sub=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "$sub" ]; then # Ensure it's not an empty string after trimming
                if [[ "$sub" == "$DOMAIN" ]]; then
                    echo "DEBUG: Main domain $DOMAIN found in SUBDOMAINS variable, already primary."
                elif [[ "$sub" == *.* ]]; then # If $sub contains a dot, assume it's an FQDN
                    echo "Adding SAN to certificate request: $sub"
                    cert_domains_args+=("-d" "$sub")
                else # Otherwise, it's a prefix
                    local full_hostname_candidate="$sub.$DOMAIN"
                    echo "Adding SAN to certificate request: $full_hostname_candidate"
                    cert_domains_args+=("-d" "$full_hostname_candidate")
                fi
            else
                echo "DEBUG: Skipped empty or whitespace-only subdomain part from input '$item'."
            fi
        done
    fi

    "${VENV_PATH}/bin/certbot" certonly \
        --authenticator dns-aliyun \
        --dns-aliyun-credentials "$CREDENTIALS_FILE" \
        --dns-aliyun-propagation-seconds "$DNS_PROPAGATION_SECONDS" \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        "${cert_domains_args[@]}" \
        "${certbot_extra_args[@]}" \
        --key-type rsa --rsa-key-size 2048

    if [ $? -ne 0 ]; then
        echo "Error: Failed to obtain certificate from Let's Encrypt."
        exit 1
    fi
    echo "Certificate obtained successfully."
fi

# Copy certificates to HTTP directory
echo "Copying certificates to HTTP directory: $HTTP_CERT_DIR"
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "${HTTP_CERT_DIR}/server.crt"
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "${HTTP_CERT_DIR}/server.key"
cp "/etc/letsencrypt/live/$DOMAIN/chain.pem" "${HTTP_CERT_DIR}/server.chain.crt"

# Create server.pem (certificate + key)
cat "${HTTP_CERT_DIR}/server.crt" "${HTTP_CERT_DIR}/server.key" > "${HTTP_CERT_DIR}/server.pem"

# Copy certificates to RADIUS directory
echo "Copying certificates to RADIUS directory: $RADIUS_CERT_DIR"
cp "${HTTP_CERT_DIR}/server.crt" "${RADIUS_CERT_DIR}/server.crt"
cp "${HTTP_CERT_DIR}/server.key" "${RADIUS_CERT_DIR}/server.key"
# DO NOT copy chain.pem to RADIUS ca.pem. ca.pem is for client CA trust or specific server CA overrides.
# The server.crt (fullchain.pem) should provide the necessary chain for the server certificate itself.

# Set correct permissions and ownership
echo "Setting permissions and ownership for certificate files..."
# HTTP Files - Target Owner: pf:pf (to resolve Web UI cert/key match issues)
chmod 644 "${HTTP_CERT_DIR}/server.crt"
chmod 644 "${HTTP_CERT_DIR}/server.chain.crt"
chmod 644 "${HTTP_CERT_DIR}/server.pem"
chmod 600 "${HTTP_CERT_DIR}/server.key"
echo "DEBUG: Setting HTTP certs owner to pf:pf"
chown pf:pf "${HTTP_CERT_DIR}/server.crt" "${HTTP_CERT_DIR}/server.key" "${HTTP_CERT_DIR}/server.chain.crt" "${HTTP_CERT_DIR}/server.pem"

# RADIUS Files - Target Owner: pf:pf, specific permissions based on original state
chmod 664 "${RADIUS_CERT_DIR}/server.crt" # Original: pf:pf 664
chmod 660 "${RADIUS_CERT_DIR}/server.key" # Original: pf:pf 660
echo "DEBUG: Setting RADIUS server.crt and server.key owner to pf:pf and specific perms"
chown pf:pf "${RADIUS_CERT_DIR}/server.crt" "${RADIUS_CERT_DIR}/server.key"
# RADIUS ca.pem is NOT managed by this script (content, permissions, or ownership)
# It should be managed by PacketFence UI or admin for client CA trust purposes.
# Original ca.pem was pf:pf 664 - we are not touching it.

# Restart HTTP services
echo "Restarting HTTP services..."
restart_service "haproxy-portal"
restart_service "haproxy-admin"
restart_service "api-frontend"

# Restart RADIUS services
echo "Restarting RADIUS services..."
restart_service "radiusd"

echo "Configuration completed successfully." 
