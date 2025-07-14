#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Create temporary files
payload_file=$(mktemp)
diff_file=$(mktemp)
trap 'rm -f "$payload_file" "$diff_file"' EXIT

# Get the diff either from the environment variable or directly from git
if [[ -n "${DIFF_FILE:-}" ]] && [[ -f "$DIFF_FILE" ]]; then
    cat "$DIFF_FILE" > "$diff_file"
else
    git --no-pager diff --cached > "$diff_file"
fi

echo "Sending diff to OpenRouter API..."

# Use Python to create properly escaped JSON payload
python3 - "$diff_file" > "$payload_file" << 'EOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    diff_content = f.read()

payload = {
    "model": "google/gemini-2.5-flash-lite-preview-06-17",  # You can change this to any model available on OpenRouter
    "messages": [
        {
            "role": "user",
            "content": "Write a commit message in the style of conventional commits specification, using bullet points, for the following git diff:\n" + diff_content
        }
    ],
    "temperature": 0,
    "top_p": 0.8,
    "max_tokens": 500
}

print(json.dumps(payload))
EOF

# Check if the API key is set
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "Error: OPENROUTER_API_KEY is not set." >&2
  echo "Get your API key from https://openrouter.ai/keys" >&2
  exit 1
fi

# For debugging, print the payload (commented out for security)
# echo "Debug - Payload:"
# cat "$payload_file"

# Send request to OpenRouter API
response=$(curl -sS -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: https://github.com/yourusername/yourrepo" \
    -H "X-Title: Git Commit Message Generator" \
    --data @"$payload_file") || { echo "API request failed" >&2; exit 1; }

# Check if response contains error
if echo "$response" | jq -e 'has("error")' > /dev/null; then
    echo "Error from OpenRouter API:" >&2
    echo "$response" | jq -r '.error.message' >&2
    exit 1
fi

# For debugging, print the full response (commented out by default)
# echo "Debug - Full response:"
# echo "$response" | jq '.'

# Extract and display the response
echo "OpenRouter's suggested commit message:"
if echo "$response" | jq -e '.choices[0].message.content' > /dev/null; then
    echo "$response" | jq -r '.choices[0].message.content'
else
    echo "Error: Unexpected response format" >&2
    echo "Full response:" >&2
    echo "$response" | jq '.' >&2
    exit 1
fi