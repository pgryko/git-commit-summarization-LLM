#!/usr/bin/env python3
"""
Simple Flask server to provide a backend for the Git Commit Summarization UI.
It executes the shell scripts and returns the results to the UI.
"""

import os
import subprocess
import json
import tempfile
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Path to the script directory - adjust this to your setup
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

@app.route('/')
def index():
    """Serve the main HTML UI"""
    return send_from_directory('.', 'git_diff_ui.html')

@app.route('/api/generate', methods=['POST'])
def generate_commit_message():
    """Execute the specified script and return the results"""
    data = request.json
    model = data.get('model', 'gemini')
    
    script_map = {
        'gpt4': 'git_diff_to_gpt4.sh',
        'groq': 'git_diff_to_groq.sh',
        'deepseek': 'git_diff_to_deepseek.sh',
        'gemini': 'git_diff_to_gemini.sh'
    }
    
    script = script_map.get(model)
    if not script:
        return jsonify({'error': 'Invalid model specified'}), 400
    
    script_path = os.path.join(SCRIPT_DIR, script)
    
    try:
        # Get the git diff for display
        diff_process = subprocess.run(
            ['git', '--no-pager', 'diff', 'staging'], 
            capture_output=True, 
            text=True,
            check=True
        )
        diff_output = diff_process.stdout
        
        # Create a temporary directory for working files
        with tempfile.TemporaryDirectory() as temp_dir:
            # Save the diff to a temporary file
            diff_file = os.path.join(temp_dir, 'diff.txt')
            with open(diff_file, 'w') as f:
                f.write(diff_output)
            
            # Set environment variable for the script to use
            env = os.environ.copy()
            env['DIFF_FILE'] = diff_file
            
            # Execute the script
            process = subprocess.run(
                [script_path],
                capture_output=True,
                text=True,
                check=True,
                env=env
            )
            
            # The last line of output should be the commit message
            lines = process.stdout.strip().split('\n')
            commit_message = lines[-1] if lines else ''
            
            return jsonify({
                'diff': diff_output,
                'message': commit_message,
                'model': model
            })
    
    except subprocess.CalledProcessError as e:
        error_message = f"Error executing script: {e.stderr}"
        return jsonify({'error': error_message}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print(f"Starting server at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True) 