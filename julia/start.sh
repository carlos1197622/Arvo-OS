#!/bin/bash

# Source environment variables if they exist
if [ -f .env ]; then
    source .env
fi

# Start the Arvo OS server
julia --project=. server/julia_server.jl "$@"
