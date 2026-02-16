# AGENTS.md — Messaging Safety Project

## Project Topology

```
~/code/messaging-safety/
├── config/
│   └── rules.yaml              # CANONICAL SOURCE — Single source of truth for all Telegram IDs
├── lib/
│   ├── types.ts                # TypeScript type definitions
│   └── validator.ts            # Core validation logic (reads rules.yaml directly)
├── hooks/
│   └── pre-message-send.ts     # OpenClaw hook (reads rules.yaml directly)
├── scripts/
│   ├── group-manager.sh        # CLI for managing groups (MODIFIES rules.yaml)
│   ├── send.sh                 # CLI for sending with validation (READS rules.yaml)
│   └── setup.ts                # Initial setup script
├── examples/
│   └── advanced-rules.yaml     # Example configuration (MUST stay in sync with rules.yaml schema)
├── SKILL.md                    # Skill metadata for OpenClaw
└── README.md                   # User-facing documentation

CONSUMERS:
├── ~/.openclaw/skills/messaging-safety -> ~/code/messaging-safety (symlink)
├── ~/code/content-research/content-monitor.sh (calls send.sh)
└── ~/.openclaw/workspace-expertclawbutler/lib/messaging-safety.ts (reads rules.yaml)
```

## Architecture Boundaries

### 1. Single Source of Truth
**ONLY** `~/code/messaging-safety/config/rules.yaml` contains hardcoded Telegram IDs.
- **NO** IDs in scripts
- **NO** IDs in TypeScript files
- **NO** IDs in documentation examples (use placeholders like `<your-chat-id>`)

### 2. Two Interfaces, One File
| Interface | Purpose | Direction |
|-----------|---------|-----------|
| **Skill Hook** (`pre-message-send.ts`) | Runtime validation | READS rules.yaml directly |
| **CLI Scripts** (`group-manager.sh`, `send.sh`) | Human/script management | MODIFIES or READS rules.yaml |

### 3. Validation Layers
```
Message Request
    ↓
CLI/send.sh (optional — for scripts) → Validates via bash
    ↓
Skill Hook (automatic — for all sends) → Validates via TypeScript
    ↓
rules.yaml ← Single source of truth
```

### 4. File Integrity
- `rules.yaml` **MUST** remain valid YAML at all times
- CLI scripts **MUST NOT** corrupt the file (no stdout pollution, proper escaping)
- All modifications **MUST** preserve existing structure

---

## Change Workflow (MANDATORY)

When making ANY change to this project:

### 1. Write Tests
```bash
# Create test script in tests/<feature>.sh
cat > tests/my_feature.sh << 'EOF'
#!/bin/bash
set -e
cd ~/code/messaging-safety/scripts

# Test your change
./group-manager.sh add test_feature -999999999 telegram 42
./send.sh /tmp/test.txt test_feature --dry-run
./group-manager.sh remove test_feature

echo "✓ All tests passed"
EOF
chmod +x tests/my_feature.sh
```

### 2. Test Every CLI Command
```bash
cd ~/code/messaging-safety/scripts

# Test ALL commands
./group-manager.sh list
./group-manager.sh add test_cmd -111111111 telegram 99
./group-manager.sh get test_cmd
./group-manager.sh update test_cmd -222222222
./group-manager.sh remove test_cmd

./send.sh /tmp/test.txt boss_dm --dry-run
./send.sh /tmp/test.txt expertclaw_ops --dry-run  # Should block
```

### 3. Validate YAML After Each Command
```bash
# After EVERY modification, verify:
python3 -c "import yaml; yaml.safe_load(open('~/code/messaging-safety/config/rules.yaml'))" && echo "✓ YAML valid"

# Check for corruption
grep -E '\[0;|INFO|WARN' ~/code/messaging-safety/config/rules.yaml && echo "✗ CORRUPTED" || echo "✓ Clean"
```

### 4. Update examples/advanced-rules.yaml
Ensure the example reflects any schema changes:
- New fields (e.g., `topic_id`)
- Changed structure (e.g., `groups` section)
- New options (e.g., `requires_approval`)

### 5. Update README.md
- Document new features
- Update CLI usage examples
- Keep placeholder IDs (never real ones)

### 6. APPEND Learnings to This File
**Format:**
```markdown
## Learning: YYYY-MM-DD — Brief Title

**Problem:** What went wrong

**Root Cause:** Why it happened

**Fix:** What was changed

**Prevention:** How to avoid in future
```

---

## Critical Learnings (APPEND ONLY — Do Not Delete)

### 2026-02-16 — CLI Log Output Corrupting YAML

**Problem:** Color codes and log messages appearing in `rules.yaml` file, breaking parsing.

**Root Cause:** `group-manager.sh` log functions wrote to stdout instead of stderr. The `sed` command in `cmd_add` captured log output when inserting new groups.

**Fix:**
- Changed all log functions to redirect to stderr: `>&2`
- Rewrote `cmd_remove` to use `awk` instead of `sed` for safer group removal

**Prevention:**
- Always redirect logs to stderr in scripts that modify files
- Never use `sed -i` with complex multi-line operations — use `awk` or temp files
- Run YAML validation after every modification

---

### 2026-02-16 — Duplicate Rule Systems

**Problem:** Multiple files contained hardcoded IDs and conflicting rules:
- `MESSAGING_RULES.md`
- `MESSAGING_DEFAULTS.md`
- `proposals/pre-send-safety-config.md`
- `lib/messaging-safety.ts` (embedded defaults)

**Root Cause:** Evolution of the system left legacy files scattered.

**Fix:**
- Deleted all duplicate/legacy files
- Made `rules.yaml` the single source of truth
- Updated `lib/messaging-safety.ts` to read from `rules.yaml` instead of embedded defaults
- Created symlink from `~/.openclaw/skills/` to canonical location

**Prevention:**
- Audit for duplicates during major refactors
- Document the canonical location in AGENTS.md
- Update all consumers to read from canonical location

---

### 2026-02-16 — Topic ID Support Added

**Feature:** Added support for Telegram topic IDs (threads within groups).

**Implementation:**
- Added `topic_id` field to group configuration
- Updated `group-manager.sh` to accept optional topic_id parameter
- Updated `send.sh` to output `TOPIC_ID` for caller to use
- Updated all documentation

**Schema Changes:**
```yaml
groups:
  my_group_topic:
    id: "-1001234567890"
    topic_id: "42"  # NEW
    platform: "telegram"
```

---

## Quick Reference

### Validate Current State
```bash
cd ~/code/messaging-safety
python3 -c "import yaml; yaml.safe_load(open('config/rules.yaml'))" && echo "✓ Valid"
```

### Test Full Flow
```bash
cd ~/code/messaging-safety/scripts
./group-manager.sh add test -999999999 telegram 42
./send.sh /tmp/test.txt test --dry-run
./group-manager.sh remove test
```

### Check for Hardcoded IDs
```bash
grep -r "5185778742\|1003732570253" \
  ~/code/messaging-safety/ \
  ~/.openclaw/workspace-expertclawbutler/ \
  --include="*.ts" --include="*.sh" --include="*.md"
```

---

**Last Updated:** 2026-02-16  
**Canonical Rules:** `~/code/messaging-safety/config/rules.yaml`  
**Status:** ✅ All 4 phases complete, v1.1.0 operational
