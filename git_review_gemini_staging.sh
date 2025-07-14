#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# --- CONFIGURATION ---
# Set your OpenRouter API Key as an environment variable:
# export OPENROUTER_API_KEY="your_openrouter_api_key_here"
#
# Choose your model on OpenRouter.
# Examples: "google/gemini-pro-1.5", "google/gemini-flash-1.5", "openai/gpt-4o", "anthropic/claude-3-opus"
# See https://openrouter.ai/models for all available models and their pricing.
OPENROUTER_MODEL_NAME="google/gemini-2.5-pro-preview" # Or your preferred model

# Optional: For OpenRouter to better track your usage/app
# You can set these to your project name or URL
HTTP_REFERER_HEADER="your-app-name-or-project-url.com" # Replace with your site/app
X_TITLE_HEADER="Code Review Script" # Replace with your app's name or purpose
# --- END CONFIGURATION ---


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

echo "Preparing code review request for OpenRouter (using model: $OPENROUTER_MODEL_NAME)..."

# Use Python to create properly escaped JSON payload
python3 - "$diff_file" "$files_changed_file" "$OPENROUTER_MODEL_NAME" > "$payload_file" << 'EOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    diff_content = f.read()

with open(sys.argv[2], 'r') as f:
    files_changed = f.read()

openrouter_model_name = sys.argv[3]

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
- Recommend integration or end-to-end tests if needed

### 💡 Suggestions for Improvement
- Provide specific, actionable recommendations
- Suggest alternative approaches if applicable
- Note any opportunities for code reuse or refactoring

Here's the git diff to review:
""".format(files_changed)

payload = {
    "model": openrouter_model_name,
    "messages": [
        {
            "role": "user",
            "content": prompt + "\n" + diff_content
        }
    ],
    # Parameters compatible with OpenAI API. Check OpenRouter docs for model-specific limits.
    "temperature": 0, # Controls randomness. 0 for deterministic.
    "top_p": 0.8,     # Nucleus sampling.
    # "max_tokens": 8192, # Max tokens for the *output*. Adjust as needed based on model.
                          # Gemini 1.5 Pro has a very large context window (input+output),
                          # but output token limits still apply.
                          # The original 22096 was likely for Gemini's specific config.
                          # OpenRouter models might have different max_tokens for output.
                          # Let's let the model decide the output length by default unless specified.
}

# Some models (like Anthropic's) might require max_tokens, check model specific docs if issues
# if "claude" in openrouter_model_name:
# payload["max_tokens"] = 4096 # Example for Claude

print(json.dumps(payload))
EOF

# Check if the API key is set
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "Error: OPENROUTER_API_KEY is not set." >&2
  echo "Please set it as an environment variable: export OPENROUTER_API_KEY=\"your_key_here\"" >&2
  exit 1
fi

# For debugging, print the payload (uncomment to see)
# echo "Debug - Payload:"
# cat "$payload_file"
# echo "--- End of Payload ---"

echo "Sending request to OpenRouter API..."

# Send request to OpenRouter API
# Using -f to fail on HTTP errors (4xx or 5xx)
response=$(curl -sSf -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: $HTTP_REFERER_HEADER" \
    -H "X-Title: $X_TITLE_HEADER" \
    --data @"$payload_file")

# The `|| { ... }` block for curl error is removed because -f handles it by exiting.
# If curl fails due to -f, the script will exit there.

# For debugging, print the full response (uncomment by default)
# echo "Debug - Full response:"
# echo "$response" | jq '.'
# echo "--- End of Full Response ---"

# Check if response is empty (can happen if curl fails silently without -f and without error message)
if [[ -z "$response" ]]; then
    echo "Error: Empty response from API. Curl might have failed silently." >&2
    exit 1
fi

# Check for OpenRouter API error in JSON (sometimes errors are 200 OK with error object)
if echo "$response" | jq -e 'has("error")' > /dev/null; then
    echo "Error from OpenRouter API:" >&2
    echo "$response" | jq '.' >&2 # Print the full error JSON
    exit 1
fi

# Extract and display the response
# OpenRouter (OpenAI compatible) uses choices[0].message.content
if echo "$response" | jq -e '.choices[0].message.content' > /dev/null; then
    echo -e "\n🔍 Code Review Results (from $OPENROUTER_MODEL_NAME via OpenRouter)"
    echo -e "=================================================================="
    echo
    echo "$response" | jq -r '.choices[0].message.content'
    echo -e "\n=================================================================="
else
    echo "Error: Unexpected response format from OpenRouter API." >&2
    echo "Full response:" >&2
    echo "$response" | jq '.' >&2
    exit 1
fi
