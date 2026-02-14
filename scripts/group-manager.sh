#!/bin/bash
#
# Group Manager for Messaging Safety Skill
# Easily map, add, and manage Telegram groups
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/../config/rules.yaml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Show current groups
cmd_list() {
    echo "Configured Groups"
    echo "================="
    echo ""
    
    # Parse groups from YAML (simple grep approach)
    if grep -q "^groups:" "$RULES_FILE"; then
        # Extract group names and IDs
        awk '/^groups:/{flag=1} /^[^ ]/{if(flag && !/^groups:/)flag=0} flag' "$RULES_FILE" | \
        grep -E "^[ ]+[a-z_]+:" | \
        while read -r line; do
            group_name=$(echo "$line" | sed 's/://g' | xargs)
            # Get the next lines for this group
            awk "/^groups:/{found=1} found && /^  $group_name:/{p=1} p{print; if(/^  [a-z_]+:/ && NR>1)exit}" "$RULES_FILE" | \
            grep -E "(id:|name:|platform:)" | \
            head -3
            echo "---"
        done
    else
        echo "No groups configured yet."
        echo ""
        echo "Add a group with: group-manager add <name> <id>"
    fi
}

# Add a new group
cmd_add() {
    local name="${1:-}"
    local id="${2:-}"
    local platform="${3:-telegram}"
    
    if [[ -z "$name" || -z "$id" ]]; then
        echo "Usage: group-manager add <name> <id> [platform]"
        echo "Example: group-manager add my_team -1001234567890 telegram"
        exit 1
    fi
    
    # Check if group already exists
    if grep -q "^  $name:" "$RULES_FILE"; then
        log_warn "Group '$name' already exists"
        echo "Use 'group-manager update $name <new_id>' to update"
        exit 1
    fi
    
    # Add group to YAML
    # Find the line after "groups:" and insert there
    log_info "Adding group: $name (ID: $id)"
    
    # Create temp file with new group
    awk '
        /^groups:/{ 
            print
            print "  "name":"
            print "    id: \""id"\""
            print "    platform: \""platform"\""
            print "    name: \""name"\""
            getline
        }
        {print}
    ' name="$name" id="$id" platform="$platform" "$RULES_FILE" > "${RULES_FILE}.tmp"
    
    mv "${RULES_FILE}.tmp" "$RULES_FILE"
    
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
    
    # Remove group block from YAML
    awk '
        /^  name:/{ 
            if (skip) {skip=0; next}
        }
        /^  [a-z_]+:/{ 
            if ($1 == "  '"$name"':") {skip=1; next}
        }
        !skip {print}
    ' "$RULES_FILE" > "${RULES_FILE}.tmp"
    
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

  list              Show all configured groups
  add <name> <id> [platform]   Add a new group
  update <name> <new_id>       Update group ID
  remove <name>                 Remove a group
  get <name>                    Get group ID

EXAMPLES:

  # List all groups
  ./group-manager.sh list

  # Add a new Telegram group
  ./group-manager.sh add my_team -1001234567890 telegram

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
