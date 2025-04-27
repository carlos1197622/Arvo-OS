#!/bin/bash

# Test Arvo OS CLI
# This script tests the Arvo OS CLI by running it with various commands

# Set environment variables
export JULIA_SERVER_HOST=${JULIA_SERVER_HOST:-localhost}
export JULIA_SERVER_PORT=${JULIA_SERVER_PORT:-8052}
export JULIA_SERVER_URL=${JULIA_SERVER_URL:-http://${JULIA_SERVER_HOST}:${JULIA_SERVER_PORT}}

# Check if Arvo OS server is running
echo "Checking if Arvo OS server is running..."
if curl -s "$JULIA_SERVER_URL/health" > /dev/null; then
    echo "Arvo OS server is running"
else
    echo "Arvo OS server is not running. Starting Arvo OS server..."
    ./scripts/run-arvo-server.sh &
    # Wait for server to start
    echo "Waiting for Arvo OS server to start..."
    for i in {1..30}; do
        if curl -s "$JULIA_SERVER_URL/health" > /dev/null; then
            echo "Arvo OS server started"
            break
        fi
        sleep 1
        echo -n "."
    done
    if ! curl -s "$JULIA_SERVER_URL/health" > /dev/null; then
        echo "Failed to start Arvo OS server. Exiting."
        exit 1
    fi
fi

# Run CLI
echo "Running CLI..."
node scripts/interactive.cjs
