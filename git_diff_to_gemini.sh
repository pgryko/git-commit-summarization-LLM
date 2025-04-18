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
    git --no-pager diff staging > "$diff_file"
fi

echo "Sending diff to Gemini API..."

# Use Python to create properly escaped JSON payload
python3 - "$diff_file" > "$payload_file" << 'EOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    diff_content = f.read()

payload = {
    "contents": [
        {
            "role": "user",
            "parts": [
                {
                    "text": "Write a commit message in the style of conventional commits specification, using bullet points, for the following git diff:\n" + diff_content
                }
            ]
        }
    ],
    "model": "gemini-2.5-pro-exp-03-25",
    "generationConfig": {
        "temperature": 0.4,
        "topP": 0.8,
        "topK": 40
    }
}

print(json.dumps(payload))
EOF

# Check if the API key is set
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Error: GEMINI_API_KEY is not set." >&2
  exit 1
fi

# For debugging, print the payload (commented out for security)
# echo "Debug - Payload:"
# cat "$payload_file"

# Send request to Gemini API
response=$(curl -sS -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-exp-03-25:generateContent?key=$GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    --data @"$payload_file") || { echo "API request failed" >&2; exit 1; }

# Check if response contains error
if echo "$response" | jq -e 'has("error")' > /dev/null; then
    echo "Error from Gemini API:" >&2
    echo "$response" | jq -r '.error.message' >&2
    exit 1
fi

# For debugging, print the full response (commented out by default)
# echo "Debug - Full response:"
# echo "$response" | jq '.'

# Extract and display the response
echo "Gemini's suggested commit message:"
if echo "$response" | jq -e '.candidates[0].content.parts[0].text' > /dev/null; then
    echo "$response" | jq -r '.candidates[0].content.parts[0].text'
else
    echo "Error: Unexpected response format" >&2
    echo "Full response:" >&2
    echo "$response" | jq '.' >&2
    exit 1
fi 