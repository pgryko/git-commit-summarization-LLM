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

echo "Sending code for review to Gemini API..."

# Use Python to create properly escaped JSON payload
python3 - "$diff_file" > "$payload_file" << 'EOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    diff_content = f.read()

prompt = """Please review the following code changes and provide:
1. A high-level summary of the changes
2. Potential issues or concerns (if any):
   - Security considerations
   - Performance implications
   - Code style and best practices
   - Potential bugs or edge cases
3. Suggestions for improvement
4. Any tests that should be added or modified

Please be specific and reference the actual code changes where relevant.

Here's the git diff to review:
"""

payload = {
    "contents": [
        {
            "role": "user",
            "parts": [
                {
                    "text": prompt + "\n" + diff_content
                }
            ]
        }
    ],
    "model": "gemini-2.5-pro-exp-03-25",
    "generationConfig": {
        "temperature": 0.4,
        "topP": 0.8,
        "topK": 40,
        "maxOutputTokens": 2048
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
echo -e "\n📋 Code Review Results:\n"
if echo "$response" | jq -e '.candidates[0].content.parts[0].text' > /dev/null; then
    echo "$response" | jq -r '.candidates[0].content.parts[0].text'
else
    echo "Error: Unexpected response format" >&2
    echo "Full response:" >&2
    echo "$response" | jq '.' >&2
    exit 1
fi 