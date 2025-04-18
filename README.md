# Git Commit Summarization with LLMs

This repository contains a collection of shell scripts that use various Large Language Models (LLMs) to automatically generate commit messages based on git diffs. These scripts compare your changes against a reference branch (typically staging) and use AI to create conventional commit messages with bullet points.

## Available Scripts

- `git_diff_to_gpt4.sh` - Uses OpenAI's GPT-4 model
- `git_diff_to_groq.sh` - Uses Groq's DeepSeek Llama 70B model
- `git_diff_to_deepseek.sh` - Uses DeepSeek's model
- `git_diff_to_gemini.sh` - Uses Google's Gemini 2.5 Pro Experimental model

## Prerequisites

- `jq` for JSON processing
- An API key for the LLM service you wish to use:
  - OpenAI API key for GPT-4
  - Groq API key for Groq
  - Google API key for Gemini

## Setup

1. Clone this repository to your local machine
2. Make the scripts executable: `chmod +x *.sh`
3. Set the appropriate API key as an environment variable:
   - For OpenAI: `export OPENAI_API_KEY="your-api-key"`
   - For Groq: `export GROQ_API_KEY="your-api-key"`
   - For Google: `export GOOGLE_API_KEY="your-api-key"`

## Usage

Run any script directly:
```bash
./git_diff_to_gemini.sh
```

Or add convenient aliases to your shell configuration (e.g., `~/.zshrc`):

```bash
alias gdiff="git --no-pager diff --cached"
alias gdiffgpt4="$HOME/path/to/git_diff_to_gpt4.sh"
alias gdiffgroq="$HOME/path/to/git_diff_to_groq.sh"
alias gdiffdeep="$HOME/path/to/git_diff_to_deepseek.sh"
alias gdiffgemini="$HOME/path/to/git_diff_to_gemini.sh"

alias gs="git status"
alias glog="git --no-pager log HEAD ^staging"
```

## How It Works

1. The script captures the git diff between your current branch and the staging branch
2. It formats a prompt asking the LLM to create a conventional commit message
3. The prompt is sent to the respective LLM API
4. The script displays the generated commit message

## Contributing

Feel free to add support for additional LLM providers or improve the existing scripts.

## License

See the [LICENSE](LICENSE) file for details.

