#!/bin/bash
# Quick test of the wrapper script

cd /Users/dodessy/Library/CloudStorage/OneDrive-Cisco/splunk-github/splunk-mcp
source .env

# Create a test message
TEST_MSG='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'

# Run the wrapper
SPLUNK_HOST=localhost SPLUNK_PORT=8089 SPLUNK_TOKEN="test-token" node scripts/splunk-mcp-wrapper.js <<< "$TEST_MSG" 2>&1 &
WRAPPER_PID=$!

# Wait a bit and kill
sleep 1
kill $WRAPPER_PID 2>/dev/null || true
wait $WRAPPER_PID 2>/dev/null || true
