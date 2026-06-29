#!/bin/bash
# @raycast.title Recall Context
# @raycast.description Query Memory Core and copy recalled context to clipboard for AI Commands
# @raycast.icon 🧠
# @raycast.mode silent
# @raycast.packageName Hermes

# Load agentmemory env (agent ID, scopes, base URL)
ENV_FILE="$HOME/.codex/agentmemory.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE" 2>/dev/null
  set +a
fi

BASE_URL="${AGENTMEMORY_CAPTURE_BASE_URL:-${MEMORY_CORE_BASE_URL:-http://memory-core.iris.sys:3111}}"
AGENT_ID="${AGENTMEMORY_AGENT_ID:-mac-raycast}"
RECALL_SCOPE="${AGENTMEMORY_RECALL_SCOPE:-shared}"

# Use current clipboard as the query (compact to 500 chars)
QUERY=$(pbpaste | head -c 500 | tr '\n' ' ' | sed 's/"/\\"/g')

if [ -z "$QUERY" ]; then
  echo "Clipboard empty — nothing to recall against."
  exit 0
fi

# Query the memory core
RESPONSE=$(curl -s -m 8 "${BASE_URL}/recall" \
  -H "Content-Type: application/json" \
  -d "{\"agentId\":\"${AGENT_ID}\",\"recallScope\":\"${RECALL_SCOPE}\",\"query\":\"${QUERY}\"}" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
  echo "Memory Core unreachable at ${BASE_URL} — proceeding without recall."
  exit 0
fi

# Put recalled context on clipboard for the next AI Command to pick up via {clipboard}
echo "$RESPONSE" | pbcopy
echo "Context recalled and copied to clipboard."
