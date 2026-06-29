#!/bin/bash
# @raycast.title Log Status
# @raycast.description Parse AI output from clipboard and append to status-log.jsonl
# @raycast.icon 📋
# @raycast.mode silent
# @raycast.packageName Hermes

LOG_DIR="$HOME/.codex/jarvis"
LOG_FILE="${LOG_DIR}/status-log.jsonl"

mkdir -p "$LOG_DIR"

INPUT=$(pbpaste)
if [ -z "$INPUT" ]; then
  echo "Clipboard empty — nothing to log."
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Compact to 300 chars, escape quotes and newlines for JSON
COMPACT=$(echo "$INPUT" | tr -s ' \n' ' ' | head -c 300 | sed 's/\\/\\\\/g; s/"/\\"/g')

# Append as JSONL
echo "{\"timestamp\":\"${TIMESTAMP}\",\"agent\":\"raycast\",\"summary\":\"${COMPACT}\"}" >> "$LOG_FILE"

echo "Status logged to ${LOG_FILE}"
