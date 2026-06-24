#!/bin/bash
# dev-squad: PreToolUse hook for AskUserQuestion.
# In --auto mode, block the question and tell the agent to infer + log to the ledger.
# No-op in interactive mode or when no workflow is active.

WORKFLOW_FILE=".dev-squad/workflow-active"
[ -f "$WORKFLOW_FILE" ] || exit 0

MODE=$(python3 -c "import json,sys; print(str(json.load(open(sys.argv[1])).get('mode') or '').strip().lower())" "$WORKFLOW_FILE" 2>/dev/null)
[ "$MODE" = "auto" ] || exit 0

echo "AUTO MODE: do not ask the user. Infer this decision from the project description and conservative defaults, then append it to .dev-squad/assumption-ledger.md (with confidence: high|med|low + rationale + risk-if-wrong). For irreversible decisions (tenancy, identity hierarchy, billing/payment provider, compliance scope) pick the conservative default and mark confidence: low. Then continue. See commands/build.md 'Auto Mode' rules."
exit 2
