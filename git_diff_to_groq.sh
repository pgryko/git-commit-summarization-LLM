#!/bin/bash

diff_content="Write a commit message in the style of conventional commits specification, using bullet points, for the following: \n $(git --no-pager diff --cached)"

echo $diff_content

payload=$(jq -nc --arg content "$diff_content" '{
    "model": "deepseek-r1-distill-llama-70b",
    "messages": [
        {"role": "system", "content": "You are ChatGPT, a large language model trained by OpenAI. Carefully heed the users instructions"},
        {
            "role": "user",
            "content": $content
        }
    ],
   "temperature": 1
}')

if [[ -z "${GROQ_API_KEY:-}" ]]; then
  echo "Error: GROQ_API_KEY is not set." >&2
  exit 1
fi

# Pass the payload to the OpenAI API chat completions endpoint
response=$(curl -sS -X POST https://api.groq.com/openai/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    --data "$payload") || { echo "API request failed" >&2; exit 1; }
echo $response 
echo $response | jq -r '.choices[0].message.content'

