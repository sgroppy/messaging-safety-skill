---
name: messaging-safety
version: "1.1.0"
description: |
  Pre-send validation system to prevent mis-routed messages.
  Supports granular rules, wildcards, hierarchical message classification,
  and Telegram topic IDs for group threading.
  
  Features:
  - Block messages by type, content pattern, or destination
  - Hierarchical rules (general → specific)
  - Wildcard support for message categories
  - Confirmation prompts for risky sends
  - Telegram topic ID support for group threading
  - Easy YAML configuration

author: Expert Claw
license: MIT

hooks:
  pre-message-send:
    handler: ./hooks/pre-message-send.ts
    description: Validates every message before sending

config:
  path: ./config/rules.yaml
  description: |
    Message routing rules and destination definitions.
    Supports Telegram topic IDs via topic_id field.

commands:
  messaging-safety:
    description: Manage messaging safety rules
    subcommands:
      - status: Show current rules and recent blocks
      - test: Test a message against rules without sending
      - reload: Reload rules from config file

scripts:
  group-manager:
    path: ./scripts/group-manager.sh
    description: Manage Telegram groups and topic IDs
    usage: |
      ./group-manager.sh list                    # Show all groups
      ./group-manager.sh add <name> <id> [platform] [topic_id]
      ./group-manager.sh update <name> <new_id>
      ./group-manager.sh remove <name>
      ./group-manager.sh get <name>
  
  send:
    path: ./scripts/send.sh
    description: Validate and send messages through safety system
    usage: |
      ./send.sh <message_file> <destination> [options]
      Options:
        --type <category>      Message category (default: digest)
        --subtype <sub>        Message subtype (default: content)
        --dry-run              Validate only, don't send

setup: ./scripts/setup.ts

---

## Telegram Topic IDs

To send messages to a specific topic within a Telegram group:

```yaml
groups:
  my_group_general:
    id: "-1001234567890"
    topic_id: "1"
    platform: "telegram"
    name: "General Topic"
    
  my_group_content:
    id: "-1001234567890"
    topic_id: "42"
    platform: "telegram"
    name: "Content Topic"
```

Then use the group alias when sending:
```bash
./send.sh message.md my_group_content --dry-run
```

The send.sh script will output `TOPIC_ID: 42` for the caller to use.

## Quick Start

1. **Configure destinations** in `config/rules.yaml`
2. **Manage groups** with `./scripts/group-manager.sh`
3. **Send safely** with `./scripts/send.sh`
4. **Override rules** by including `BOSS_OVERRIDE` in message

## Rule Priority

More specific rules override wildcards:
1. `digest.reddit` (most specific)
2. `digest.*` (wildcard)
3. `*` (global default)
