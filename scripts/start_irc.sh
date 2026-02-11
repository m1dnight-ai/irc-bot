#!/bin/bash
# Starts a local ngircd server for development/testing
# Usage: ./scripts/start_irc.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONF="$PROJECT_DIR/priv/ngircd/ngircd.conf"

echo "Starting ngircd with config: $CONF"
exec ngircd -f "$CONF" -n
