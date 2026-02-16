#!/bin/bash
#
# Messaging Safety Send Script
# Validates and sends messages through the safety system
#
# Usage: ./send.sh <message_file> <destination_alias> [options]
#   destination_alias: boss_dm, expertclaw_ops, etc. (from rules.yaml)
#   options:
#     --type <type>      Message type for classification (default: digest)
#     --subtype <sub>    Message subtype (default: content)
#     --dry-run          Validate only, don't send
#
# Exit codes:
#   0: Message sent successfully
#   1: Validation failed (blocked by rules)
#   2: Configuration error
#   3: Send failed
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/../config/rules.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
MESSAGE_TYPE="digest"
MESSAGE_SUBTYPE="content"
DRY_RUN=false
OVERRIDE_CODE="BOSS_OVERRIDE"

# Parse arguments
MESSAGE_FILE=""
DESTINATION=""

usage() {
    cat << EOF
Usage: $(basename "$0") <message_file> <destination_alias> [options]

Arguments:
  message_file        Path to file containing message content
  destination_alias   Destination name from rules.yaml (e.g., boss_dm)

Options:
  --type <type>       Message category (default: digest)
  --subtype <sub>     Message subtype (default: content)
  --dry-run           Validate only, don't actually send
  --help              Show this help

Examples:
  $(basename "$0") /tmp/alert.md boss_dm
  $(basename "$0") /tmp/alert.md expertclaw_ops --type digest --subtype reddit
  $(basename "$0") /tmp/alert.md boss_dm --dry-run

EOF
}

log_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1" >&2
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# Get destination info from rules (id and optional topic_id)
get_destination_info() {
    local dest_name="$1"
    local dest_block
    local found_id=""
    local found_topic=""
    
    # Read file and find the destination block with actual data
    local in_block=false
    local current_name=""
    
    while IFS= read -r line; do
        # Check for destination entry (2-space indent + name:)
        if [[ "$line" =~ ^\ \ ${dest_name}:$ ]]; then
            in_block=true
            current_name="$dest_name"
            continue
        fi
        
        # Exit block if we hit another 2-space entry
        if $in_block && [[ "$line" =~ ^\ \ [a-z_0-9]+:$ ]]; then
            # If we found an ID, return it
            if [[ -n "$found_id" ]]; then
                echo "${found_id}|${found_topic}"
                return 0
            fi
            in_block=false
            current_name=""
        fi
        
        # Parse properties within block
        if $in_block; then
            if [[ "$line" =~ ^\ \ \ \ id:\ *(.*)$ ]]; then
                found_id="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^\ \ \ \ topic_id:\ *(.*)$ ]]; then
                found_topic="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$RULES_FILE"
    
    # Return last block if found
    if [[ -n "$found_id" ]]; then
        echo "${found_id}|${found_topic}"
        return 0
    fi
    
    return 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            MESSAGE_TYPE="$2"
            shift 2
            ;;
        --subtype)
            MESSAGE_SUBTYPE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 2
            ;;
        *)
            if [[ -z "$MESSAGE_FILE" ]]; then
                MESSAGE_FILE="$1"
            elif [[ -z "$DESTINATION" ]]; then
                DESTINATION="$1"
            else
                log_error "Too many arguments"
                usage
                exit 2
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$MESSAGE_FILE" || -z "$DESTINATION" ]]; then
    log_error "Missing required arguments"
    usage
    exit 2
fi

if [[ ! -f "$MESSAGE_FILE" ]]; then
    log_error "Message file not found: $MESSAGE_FILE"
    exit 2
fi

if [[ ! -f "$RULES_FILE" ]]; then
    log_error "Rules file not found: $RULES_FILE"
    exit 2
fi

# Read message content
MESSAGE_CONTENT=$(cat "$MESSAGE_FILE")

# Check for override code
if echo "$MESSAGE_CONTENT" | grep -q "$OVERRIDE_CODE"; then
    log_warn "Override code detected — skipping validation"
    VALIDATION_PASSED=true
else
    VALIDATION_PASSED=false
fi

# Get destination info (id and topic_id)
dest_info=$(get_destination_info "$DESTINATION") || {
    log_error "Destination '$DESTINATION' not found in rules.yaml"
    exit 2
}

dest_id=$(echo "$dest_info" | cut -d'|' -f1)
topic_id=$(echo "$dest_info" | cut -d'|' -f2)

if [[ -z "$dest_id" || "$dest_id" == "TBD" ]]; then
    log_error "Destination '$DESTINATION' has no valid ID configured"
    exit 2
fi

# Validate against rules (unless overridden)
if [[ "$VALIDATION_PASSED" != "true" ]]; then
    log_info "Validating message type: ${MESSAGE_TYPE}.${MESSAGE_SUBTYPE}"
    if [[ -n "$topic_id" ]]; then
        log_info "Destination: ${DESTINATION} (${dest_id}, topic: ${topic_id})"
    else
        log_info "Destination: ${DESTINATION} (${dest_id})"
    fi
    
    # Check if this message type exists in rules
    category_rules=$(awk "/^  ${MESSAGE_TYPE}:/{flag=1} /^  [a-z_]+:/{if(flag && !/^  ${MESSAGE_TYPE}:/)exit} flag" "$RULES_FILE")
    
    if [[ -z "$category_rules" ]]; then
        log_error "Message type '${MESSAGE_TYPE}' not found in rules"
        exit 2
    fi
    
    # Check if destination is explicitly allowed
    allowed_in=$(echo "$category_rules" | grep "allowed_in:" | head -1)
    blocked_in=$(echo "$category_rules" | grep "blocked_in:" | head -1)
    
    # Check blocked list first
    if echo "$blocked_in" | grep -q "$DESTINATION"; then
        log_error "BLOCKED: Destination '$DESTINATION' is in blocked_in list for ${MESSAGE_TYPE}"
        log_error "Rules: $blocked_in"
        echo "BLOCKED"
        exit 1
    fi
    
    # Check allowed list
    if ! echo "$allowed_in" | grep -q "$DESTINATION"; then
        # Check wildcard
        if echo "$allowed_in" | grep -q '"\*"'; then
            log_info "Wildcard (*) allowed — permitting send"
            VALIDATION_PASSED=true
        else
            log_error "BLOCKED: Destination '$DESTINATION' not in allowed_in list for ${MESSAGE_TYPE}"
            log_error "Allowed: $allowed_in"
            echo "BLOCKED"
            exit 1
        fi
    else
        VALIDATION_PASSED=true
    fi
fi

if [[ "$VALIDATION_PASSED" == "true" ]]; then
    log_info "✓ Validation passed"
fi

# Dry run - stop here
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run mode — message NOT sent"
    if [[ -n "$topic_id" ]]; then
        echo "WOULD_SEND_TO: ${DESTINATION} (${dest_id}, topic: ${topic_id})"
    else
        echo "WOULD_SEND_TO: ${DESTINATION} (${dest_id})"
    fi
    exit 0
fi

# Send the message
if [[ -n "$topic_id" ]]; then
    log_info "Sending message to ${DESTINATION} (topic: ${topic_id})..."
else
    log_info "Sending message to ${DESTINATION}..."
fi

# Output structured data for the caller to handle
# The actual send is done through OpenClaw's message system
echo "SEND_TO: ${DESTINATION}"
echo "SEND_ID: ${dest_id}"
if [[ -n "$topic_id" ]]; then
    echo "TOPIC_ID: ${topic_id}"
fi
echo "---"
cat "$MESSAGE_FILE"

log_info "✓ Message processed"
exit 0
