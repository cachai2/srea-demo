#!/usr/bin/env python3
"""
Scaling Guardrail — PostToolUse Command Hook

Paste this script into the hook editor at sre.azure.com:
  Hooks → Create hook → PostToolUse → Command → Python

Settings:
  - Event type: PostToolUse
  - Hook type: Command
  - Language: Python
  - Activation mode: Always
  - Fail mode: Block
  - Timeout: 30

Enforces a max replica ceiling on Container App scaling commands.
Deterministic — the LLM cannot bypass this.
"""
import sys, json, re, datetime

MAX_REPLICAS = 10

context = json.load(sys.stdin)
command = context.get('tool_input', {}).get('command', '')

replica_patterns = [
    (r'--min-replicas\s+(\d+)', 'min-replicas'),
    (r'--max-replicas\s+(\d+)', 'max-replicas'),
]

for pattern, label in replica_patterns:
    match = re.search(pattern, command)
    if match:
        count = int(match.group(1))
        if count > MAX_REPLICAS:
            print(json.dumps({
                "decision": "block",
                "hookSpecificOutput": {
                    "reason": f"POLICY VIOLATION: {label}={count} exceeds scaling ceiling of {MAX_REPLICAS}. "
                              f"Reduce to {MAX_REPLICAS} or fewer and retry."
                }
            }))
            sys.exit(0)

ts = datetime.datetime.utcnow().isoformat() + "Z"
print(json.dumps({
    "decision": "allow",
    "hookSpecificOutput": {
        "additionalContext": f"[SCALING AUDIT {ts}] Command within policy (max {MAX_REPLICAS} replicas): {command}"
    }
}))
