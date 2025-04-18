#!/bin/bash

# Preappend the desired text
diff_content="Write a commit message in the style of conventional commits specification, use bullet points where reasonable, for the following: \n $(git --no-pager diff --cached)"

echo $diff_content

payload=$(jq -nc --arg content "$diff_content" '{
    "model": "deepseek-coder",
    "messages": [
        {"role": "system", "content": "You are deepseek, a large language model trained. Carefully heed the users instructions Respond using Markdown."},
        {
            "role": "user",
            "content": $content
        }
    ],
   "temperature": 0.7
}')

# Pass the payload to the OpenAI API chat completions endpoint
response=$(curl -s -X POST https://api.deepseek.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
    --data "$payload")

echo $response | jq -r '.choices[0].message.content'
