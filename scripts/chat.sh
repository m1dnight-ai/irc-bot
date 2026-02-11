#!/bin/bash
# Mini IRC client for testing the bot.
# Usage: ./scripts/chat.sh [nick]
#
# Type messages and press Enter. Bot replies appear inline.
# Ctrl-C to quit.

NICK="${1:-tester}"
HOST="localhost"
PORT=6667
CHANNEL="#general"

TMPDIR=$(mktemp -d)
FIFO_IN="$TMPDIR/in"
FIFO_OUT="$TMPDIR/out"
mkfifo "$FIFO_IN" "$FIFO_OUT"

cleanup() {
    echo -e "QUIT :bye\r" >&3 2>/dev/null
    kill "$NC_PID" 2>/dev/null
    wait 2>/dev/null
    exec 3>&- 4<&- 2>/dev/null
    rm -rf "$TMPDIR"
    exit 0
}
trap cleanup INT TERM EXIT

nc "$HOST" "$PORT" < "$FIFO_IN" > "$FIFO_OUT" &
NC_PID=$!
sleep 0.3

if ! kill -0 "$NC_PID" 2>/dev/null; then
    echo "Cannot connect to $HOST:$PORT"
    exit 1
fi

exec 3>"$FIFO_IN"
exec 4<"$FIFO_OUT"

irc_send() {
    echo -e "$1\r" >&3
}

irc_send "NICK $NICK"
irc_send "USER $NICK 0 * :$NICK"

while IFS= read -r line <&4; do
    line="${line%%$'\r'}"
    [[ "$line" == PING* ]] && irc_send "PONG ${line#PING }"
    [[ "$line" == *" 001 "* ]] && break
done

irc_send "JOIN $CHANNEL"

while IFS= read -r -t 3 line <&4; do
    line="${line%%$'\r'}"
    [[ "$line" == *" 366 "* ]] && break
done

echo ""
echo "--- Connected as $NICK in $CHANNEL ---"
echo "--- Type messages and press Enter. Ctrl-C to quit. ---"
echo ""

# Single event loop: poll both IRC (fd 4) and stdin (fd 0)
while kill -0 "$NC_PID" 2>/dev/null; do
    # Try to read from IRC (non-blocking with short timeout)
    if IFS= read -r -t 0.1 line <&4; then
        line="${line%%$'\r'}"
        if [[ "$line" == PING* ]]; then
            irc_send "PONG ${line#PING }"
        elif [[ "$line" =~ ^:([^!]+)![^\ ]+\ PRIVMSG\ [^\ ]+\ :(.*) ]]; then
            sender="${BASH_REMATCH[1]}"
            text="${BASH_REMATCH[2]}"
            [[ "$sender" != "$NICK" ]] && echo "<$sender> $text"
        elif [[ "$line" =~ ^:([^!]+)![^\ ]+\ JOIN ]]; then
            who="${BASH_REMATCH[1]}"
            [[ "$who" != "$NICK" ]] && echo "* $who joined"
        elif [[ "$line" =~ ^:([^!]+)![^\ ]+\ PART ]]; then
            who="${BASH_REMATCH[1]}"
            echo "* $who left"
        fi
    fi

    # Try to read from stdin (non-blocking with short timeout)
    if IFS= read -r -t 0.1 input <&0; then
        [[ -n "$input" ]] && irc_send "PRIVMSG $CHANNEL :$input"
    fi
done

echo "--- Connection lost ---"
cleanup
