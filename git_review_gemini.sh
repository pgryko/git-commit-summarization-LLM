#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Create temporary files
payload_file=$(mktemp)
diff_file=$(mktemp)
files_changed_file=$(mktemp)
trap 'rm -f "$payload_file" "$diff_file" "$files_changed_file"' EXIT

# Get list of changed files
git diff --name-status staging > "$files_changed_file"

# Get the diff either from the environment variable or directly from git
if [[ -n "${DIFF_FILE:-}" ]] && [[ -f "$DIFF_FILE" ]]; then
    cat "$DIFF_FILE" > "$diff_file"
else
    git --no-pager diff staging > "$diff_file"
fi

# Check if there are any changes
if [[ ! -s "$diff_file" ]]; then
    echo "No changes found between current branch and staging."
    exit 0
fi

echo "Sending code for review to Gemini API..."

# Use Python to create properly escaped JSON payload
python3 - "$diff_file" "$files_changed_file" > "$payload_file" << 'EOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    diff_content = f.read()

with open(sys.argv[2], 'r') as f:
    files_changed = f.read()

prompt = """You are an experienced code reviewer. Please analyze the following code changes and provide a detailed review.

Files changed:
{}

Please provide your review in the following format:

## 📝 Summary of Changes
[Provide a clear, high-level overview of what has been changed and why these changes appear to have been made]

## 🔍 Detailed Review

### 🛡️ Security Considerations
- List any security implications, vulnerabilities, or concerns
- Mention if any sensitive data handling needs review
- Note any authentication/authorization concerns

### ⚡ Performance Impact
- Analyze any performance implications
- Note any potential bottlenecks
- Suggest optimizations if applicable

### 📚 Code Style and Best Practices
- Comment on code organization and readability
- Note any deviations from common best practices
- Suggest improvements in code structure

### 🐛 Potential Issues
- List any potential bugs or edge cases
- Note any error handling concerns
- Highlight any race conditions or concurrency issues

### ✅ Testing Recommendations
- Suggest specific test cases to add
- Note which scenarios should be covered
- Recommend integration or end-to-end tests if neede3

### 💡 Suggestions for Improvement
- Provide specific, actionable recommendations
- Suggest alternative approaches if applicable
- Note any opportunities for code reuse or refactoring

Here's the git diff to review:
""".format(files_changed)

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
        "temperature": 0,
        "topP": 0.8,
        "topK": 40,
        "maxOutputTokens": 22096
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
if echo "$response" | jq -e '.candidates[0].content.parts[0].text' > /dev/null; then
    echo -e "\n🔍 Code Review Results"
    echo -e "===================="
    echo
    echo "$response" | jq -r '.candidates[0].content.parts[0].text'
    echo -e "\n===================="
else
    echo "Error: Unexpected response format" >&2
    echo "Full response:" >&2
    echo "$response" | jq '.' >&2
    exit 1
fi 