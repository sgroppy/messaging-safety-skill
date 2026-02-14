# Messaging Safety Skill

Pre-send validation system for OpenClaw to prevent mis-routed messages.

## Features

- ✅ **Hierarchical Rules** — General categories + specific subtypes
- ✅ **Wildcard Support** — `*` matches all subtypes (e.g., `digest.*`)
- ✅ **Granular Control** — Block by message type, content pattern, or destination
- ✅ **Confirmation Flow** — Ask before sending to risky destinations
- ✅ **Content Detection** — Auto-classify messages by regex patterns
- ✅ **Easy YAML Config** — No code changes needed

## Installation

```bash
# Clone/copy to OpenClaw skills directory
cp -r messaging-safety ~/.openclaw/skills/

# Run setup
claw skill setup messaging-safety
```

## Quick Start

1. **Edit config** (`~/.openclaw/skills/messaging-safety/config/rules.yaml`):

```yaml
destinations:
  my_dm:
    id: "123456789"
    name: "My DM"

  work_group:
    id: "-100123456789"
    name: "Work Group"

message_types:
  digest:
    "*":  # All digest types
      allowed_in: [my_dm]
      blocked_in: [work_group]
```

2. **Test a message**:
```bash
claw messaging-safety test "Morning digest" work_group
```

3. **Enable hook** — Add to your `AGENTS.md`:
```yaml
hooks:
  pre-message-send: ~/.openclaw/skills/messaging-safety/hooks/pre-message-send.ts
```

## Configuration

### Message Type Hierarchy

```yaml
message_types:
  digest:                    # Category
    "*":                     # Wildcard (all subtypes)
      allowed_in: [boss]
      blocked_in: [work]
      
    reddit:                  # Specific subtype
      allowed_in: [boss]
      blocked_in: [work, public]
      content_patterns:
        - "r/\w+"
        - "reddit"
```

### Rule Priority

More specific rules override wildcards:
1. `digest.reddit` (most specific)
2. `digest.*` (wildcard)
3. `*` (global default)

### Destinations

```yaml
destinations:
  boss_dm:
    id: "5185778742"        # Telegram chat ID
    type: "telegram"
    name: "Boss"
```

### Detection Rules

Auto-classify messages by content:

```yaml
detection_rules:
  - name: "reddit_content"
    patterns:
      - "r/\w+"
      - "reddit.com"
    classify_as: "digest.reddit"
```

## Examples

### Block all digests in work groups
```yaml
digest:
  "*":
    allowed_in: [my_dm]
    blocked_in: [work_group, public_channel]
```

### Allow weekly summaries with confirmation
```yaml
digest:
  weekly:
    allowed_in: [my_dm, work_group]
    requires_confirmation: [work_group]
```

### Block financial data everywhere except DM
```yaml
business:
  revenue:
    allowed_in: [my_dm]
    blocked_in: [work_group, public_channel]
    reason: "Financial data is sensitive"
```

## Commands

```bash
# Check current rules
claw messaging-safety status

# Test a message (dry run)
claw messaging-safety test "Your message" destination_id

# Reload config after changes
claw messaging-safety reload
```

## Emergency Override

Include `BOSS_OVERRIDE` in any message to skip validation:

```
BOSS_OVERRIDE: Send this immediately
```

## License

MIT
