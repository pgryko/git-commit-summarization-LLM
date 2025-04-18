#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Get the diff between current branch and staging
diff_content="Write a commit message in the style of conventional commits specification, using bullet points, for the following: \n $(git --no-pager diff staging)"

echo "Sending diff to Gemini API..."

# Prepare the JSON payload for the Gemini API
payload=$(jq -nc --arg content "$diff_content" '{
    "contents": [
        {
            "role": "user",
            "parts": [
                {
                    "text": $content
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
}')

# Check if the API key is set
if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
  echo "Error: GOOGLE_API_KEY is not set." >&2
  exit 1
fi

# Send request to Gemini API
response=$(curl -sS -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-exp-03-25:generateContent?key=$GOOGLE_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$payload") || { echo "API request failed" >&2; exit 1; }

# Extract and display the response
echo "Gemini's suggested commit message:"
echo $response | jq -r '.candidates[0].content.parts[0].text' 