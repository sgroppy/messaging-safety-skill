#!/bin/bash
#
# Group Manager for Messaging Safety Skill
# Easily map, add, and manage Telegram groups
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/../config/rules.yaml"

# Colors - using printf for compatibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2
}

log_success() {
    printf "${GREEN}[OK]${NC} %s\n" "$1" >&2
}

log_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# Show current groups
cmd_list() {
    echo "Configured Groups"
    echo "================="
    echo ""
    
    # Parse groups from YAML
    if ! grep -q "^groups:" "$RULES_FILE"; then
        echo "No groups configured yet."
        echo ""
        echo "Add a group with: group-manager add <name> <id> [platform] [topic_id]"
        return 0
    fi
    
    # Parse group blocks
    local in_groups=false
    local group_name=""
    local group_id=""
    local group_topic=""
    local group_platform=""
    local group_desc=""
    local count=0
    
    while IFS= read -r line; do
        # Detect start of groups section
        if [[ "$line" =~ ^groups: ]]; then
            in_groups=true
            continue
        fi
        
        # Exit groups section at next top-level key
        if $in_groups && [[ "$line" =~ ^[a-z_]+: ]] && [[ ! "$line" =~ ^groups: ]]; then
            in_groups=false
            continue
        fi
        
        if $in_groups; then
            # New group entry (2-space indent + name:)
            if [[ "$line" =~ ^\ \ ([a-z_0-9]+):$ ]]; then
                # Print previous group if we have one
                if [[ -n "$group_name" ]]; then
                    echo "Name: $group_name"
                    [[ -n "$group_id" ]] && echo "  ID: $group_id"
                    [[ -n "$group_topic" && "$group_topic" != "null" ]] && echo "  Topic ID: $group_topic"
                    [[ -n "$group_platform" ]] && echo "  Platform: $group_platform"
                    [[ -n "$group_desc" ]] && echo "  Description: $group_desc"
                    echo "---"
                    ((count++)) || true
                fi
                # Start new group
                group_name="${BASH_REMATCH[1]}"
                group_id=""
                group_topic=""
                group_platform=""
                group_desc=""
            # Group properties (4-space indent)
            elif [[ "$line" =~ ^\ \ \ \ id:\ *(.*)$ ]]; then
                group_id="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^\ \ \ \ topic_id:\ *(.*)$ ]]; then
                group_topic="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^\ \ \ \ platform:\ *(.*)$ ]]; then
                group_platform="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^\ \ \ \ description:\ *(.*)$ ]]; then
                group_desc="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$RULES_FILE"
    
    # Print last group
    if [[ -n "$group_name" ]]; then
        echo "Name: $group_name"
        [[ -n "$group_id" ]] && echo "  ID: $group_id"
        [[ -n "$group_topic" && "$group_topic" != "null" ]] && echo "  Topic ID: $group_topic"
        [[ -n "$group_platform" ]] && echo "  Platform: $group_platform"
        [[ -n "$group_desc" ]] && echo "  Description: $group_desc"
        ((count++)) || true
    fi
    
    if [[ $count -eq 0 ]]; then
        echo "No groups configured yet."
        echo ""
        echo "Add a group with: group-manager add <name> <id> [platform] [topic_id]"
    fi
    
    return 0
}

# Add a new group
cmd_add() {
    local name="${1:-}"
    local id="${2:-}"
    local platform="${3:-telegram}"
    local topic_id="${4:-}"
    
    if [[ -z "$name" || -z "$id" ]]; then
        echo "Usage: group-manager add <name> <id> [platform] [topic_id]"
        echo "Example: group-manager add my_team -1001234567890 telegram"
        echo "Example with topic: group-manager.sh add my_topic -1001234567890 telegram 42"
        exit 1
    fi
    
    # Check if group already exists
    if grep -q "^  $name:" "$RULES_FILE"; then
        log_warn "Group '$name' already exists"
        echo "Use 'group-manager update $name <new_id>' to update"
        exit 1
    fi
    
    log_info "Adding group: $name (ID: $id)"
    
    # Build group entry as separate lines
    {
        echo ""
        echo "  $name:"
        echo "    id: \"$id\""
        echo "    platform: \"$platform\""
        if [[ -n "$topic_id" ]]; then
            echo "    topic_id: \"$topic_id\""
            log_info "Topic ID: $topic_id"
        fi
        echo "    name: \"$name\""
    } > /tmp/group_entry_$$
    
    # Insert after groups: line using sed
    sed -i "/^groups:/r /tmp/group_entry_$$" "$RULES_FILE"
    rm -f /tmp/group_entry_$$
    
    log_success "Group '$name' added successfully"
    echo ""
    echo "Update rules to use this group:"
    echo "  allowed_in: [$name]"
    echo "  blocked_in: [$name]"
}

# Update group ID
cmd_update() {
    local name="${1:-}"
    local new_id="${2:-}"
    
    if [[ -z "$name" || -z "$new_id" ]]; then
        echo "Usage: group-manager update <name> <new_id>"
        exit 1
    fi
    
    if ! grep -q "^  $name:" "$RULES_FILE"; then
        log_error "Group '$name' not found"
        exit 1
    fi
    
    log_info "Updating group '$name' to ID: $new_id"
    
    # Update the ID line for this group
    sed -i "/^  $name:/,/^  [a-z_]*:/{s/id: \".*\"/id: \"$new_id\"/}" "$RULES_FILE"
    
    log_success "Group '$name' updated"
}

# Remove a group
cmd_remove() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        echo "Usage: group-manager remove <name>"
        exit 1
    fi
    
    if ! grep -q "^  $name:" "$RULES_FILE"; then
        log_error "Group '$name' not found"
        exit 1
    fi
    
    log_warn "Removing group: $name"
    
    # Remove group block from YAML using awk
    # This removes the group entry and all its 4-space indented properties
    awk '
        /^  [a-z_0-9]+:/{ 
            in_block = ($0 ~ "^  "name":")
        }
        !in_block { print }
    ' name="$name" "$RULES_FILE" > "${RULES_FILE}.tmp"
    
    mv "${RULES_FILE}.tmp" "$RULES_FILE"
    
    log_success "Group '$name' removed"
}

# Get group ID
cmd_get() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        echo "Usage: group-manager get <name>"
        exit 1
    fi
    
    # Extract ID for group
    awk '/^  '$name':/{found=1} found && /id:/{print $2; exit}' "$RULES_FILE" | tr -d '"'
}

# Show help
show_help() {
    cat << 'EOF'
Group Manager for Messaging Safety Skill
========================================

Manage Telegram groups easily without editing YAML manually.

COMMANDS:

  list                    Show all configured groups
  add <name> <id> [platform] [topic_id]   Add a new group
  update <name> <new_id>  Update group ID
  remove <name>           Remove a group
  get <name>              Get group ID

EXAMPLES:

  # List all groups
  ./group-manager.sh list

  # Add a new Telegram group
  ./group-manager.sh add my_team -1001234567890 telegram

  # Add a group with a specific topic
  ./group-manager.sh add content_topic -1001234567890 telegram 42

  # Update group ID
  ./group-manager.sh update my_team -1009876543210

  # Get group ID for scripting
  ./group-manager.sh get my_team

FILES:
  Config: ../config/rules.yaml

EOF
}

# Main
cmd="${1:-help}"
shift || true

case "$cmd" in
    list|ls)
        cmd_list
        ;;
    add)
        cmd_add "$@"
        ;;
    update)
        cmd_update "$@"
        ;;
    remove|rm|delete)
        cmd_remove "$@"
        ;;
    get)
        cmd_get "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $cmd"
        echo ""
        show_help
        exit 1
        ;;
esac
