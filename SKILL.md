---
name: messaging-safety
version: "1.0.0"
description: |
  Pre-send validation system to prevent mis-routed messages.
  Supports granular rules, wildcards, and hierarchical message classification.
  
  Features:
  - Block messages by type, content pattern, or destination
  - Hierarchical rules (general → specific)
  - Wildcard support for message categories
  - Confirmation prompts for risky sends
  - Easy YAML configuration

author: Expert Claw
license: MIT

hooks:
  pre-message-send:
    handler: ./hooks/pre-message-send.ts
    description: Validates every message before sending

config:
  path: ./config/rules.yaml
  description: Message routing rules and destination definitions

commands:
  messaging-safety:
    description: Manage messaging safety rules
    subcommands:
      - status: Show current rules and recent blocks
      - test: Test a message against rules without sending
      - reload: Reload rules from config file

setup: ./scripts/setup.ts
