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
- For the UI:
  - Python 3.7+ with Flask and Flask-CORS

## Setup

1. Clone this repository to your local machine
2. Make the scripts executable: `chmod +x *.sh`
3. Set the appropriate API key as an environment variable:
   - For OpenAI: `export OPENAI_API_KEY="your-api-key"`
   - For Groq: `export GROQ_API_KEY="your-api-key"`
   - For Google: `export GOOGLE_API_KEY="your-api-key"`

### UI Setup (Optional)

1. Install the required Python packages:
   ```bash
   pip install -r requirements.txt
   ```
2. Run the Flask server:
   ```bash
   python git_diff_server.py
   ```
3. Open your browser and navigate to http://localhost:5000

## Usage

### Command Line Usage

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

### Web UI Usage

1. Ensure the Flask server is running (`python git_diff_server.py`)
2. Navigate to http://localhost:5000 in your browser
3. Select the LLM you want to use from the options at the top
4. Click "Generate Commit Message"
5. View the git diff and the generated commit message in the respective tabs
6. Use the "Copy" button to copy either the diff or the commit message to your clipboard

## How It Works

1. The script captures the git diff between your current branch and the staging branch
2. It formats a prompt asking the LLM to create a conventional commit message
3. The prompt is sent to the respective LLM API
4. The script displays the generated commit message

## Project Structure

- `*.sh` - Shell scripts for different LLM providers
- `git_diff_ui.html` - Frontend UI for the web interface
- `git_diff_server.py` - Flask backend server to connect the UI with the shell scripts
- `requirements.txt` - Python package dependencies

## Contributing

Feel free to add support for additional LLM providers or improve the existing scripts.

## License

See the [LICENSE](LICENSE) file for details.

