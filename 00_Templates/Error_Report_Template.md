---
type: error_report
class: E?
date: {{date}}
macro: {{macro_name}}
persona: {{role}}
status: open
---

# 🚨 Error Report: {{short_id}}

## Classification
- **Class:** E? (E1 Blocker / E2 Tool Failure / E3 Inconsistency / E4 Permission / E5 Saturation)
- **Severity:** (low / medium / high / critical)

## Trigger
- **Macro:** `{{macro_name}}`
- **Step:** (which step in the macro failed)
- **Args:** `{{args}}`

## Observed Failure
```
{{exact error output, command, stack trace, or condition}}
```

## State at Failure
- **Active Persona:** {{role}}
- **Active Project:** [[{{project}}]]
- **Active Task:** [[{{task}}]] (if applicable)
- **Checkpoint File:** `04_Logs/Checkpoints/{{checkpoint}}` (if applicable)

## Recovery Attempted
- [ ] Step 1: ...
- [ ] Step 2: ...
- [ ] Result: (succeeded / escalated)

## Resolution
- **Action Taken:** (filled when status moves to closed)
- **Root Cause:** (filled when status moves to closed)
- **Prevention:** (rule proposal for `/graduate`, if any)

## Cross-References
- **Daily Log:** [[04_Logs/{{date}}]]
- **Originating Task:** [[{{task}}]]
- **Related Errors:** (if recurring)
