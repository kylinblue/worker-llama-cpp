#!/bin/bash
# Start the llama.cpp server (assumed to support a chat endpoint) on port 8000 in the background
cd /llama.cpp
./main --server --port 8000 &

# Allow some time for the llama.cpp server to initialize
sleep 5

# Launch the RunPod serverless handler (this call will block and serve incoming jobs)
python3 src/handler.py