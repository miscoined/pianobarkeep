#!/bin/bash

# Your config folder
d="${XDG_CONFIG_HOME:-$HOME/.config}/pianobar"
# The pianobar executable
pianobar="pianobar"

# FIFO control file
ctlf="$d/ctl"
# Log file
logf="$d/log"

# Send a command to pianobar
cmd () {
    echo -en "$1" > "$ctlf"
}

# Send a notification as received through stdin
# This can be modified, but it must be able to accept input through stdin
# as well as through an argument
notify () {
    notify-send -t 3000 "${1:-$(tr -d '\0' < /dev/stdin)}"
}

# Retrieve input from user
# This must retrieve options from stdin and output the choice to stdout
ask () {
    rofi -dmenu -p "$1"
}

# Retrieve an explanation and send it as a notification
explain () {
    cmd "e"
    sleep 1
    # Find explanation lines
    grep -x "(i) We're playing this track because .*" "$logf" |
        # Get the most recent one
        tail -1 |
        # Format it as a list
        sed "s/(i) //; s/it features/\0,/; s/and and/\nand/; s/,/\n * /g" |
        notify
}

# Get the currently playing station and track
info () {
    cmd "i"
    # Match the current track line and format it nicely
    grep -ox "|>  .*" "$logf" |
        tail -2 |
        sed 's/|>  //' |
        notify
}

# Get the upcoming song list and print it
upcoming () {
    cmd "u"
    # Get the line number of the last call for upcoming songs
    linenum=$(grep -n "^	 0) \|^(i) No songs in queue." "$logf" | tail -1 | cut -d':' -f1)
    # Get the last set of upcoming songs and format it
    tail -n+$linenum "$logf" |
        sed 's/^(i) \|^	 //' |
        notify
}

# Switch stations
switch () {
    cmd "s"
    cmd $(
        # Retrieve the latest station list
        grep -Pzo "	 0\) .. .*\n(	 [1-9][0-9]*\) .. .*\n)*$" "$logf" |
            # Format it nicely
            sed 's/^	 \([0-9]*\)) .. \(.*\)$/\1) \2/' |
            # Remove the last garbage line
            head -n -1 |
            # Retrieve the desired station number
            ask | cut -d')' -f1
        )"\n"
}

# Toggle Quickmix stations
quickmix () {
    cmd "x"
    if grep -zoq '/!\\ Not a QuickMix station\..$' "$logf"; then
        notify "Not a QuickMix station"
    else
        cmd $(
            # Retrieve the latest station list
            grep -Pzo "	 0\) .. .*\n(	 [1-9][0-9]*\) .. .*\n)*$" "$logf" |
                # Remove leading whitespace
                sed 's/^	 //' |
                # Remove the last garbage line
                head -n-1 |
                # Retrieve the desired station number
                ask | cut -d')' -f1)"\n"
        cmd "\n"
    fi
}

# Create a new station
new () {
    cmd "c"
    cmd "$(ask "Create station from artist or title: ")""\n"
    sleep 1
    cmd $(
        # Retrieve the latest station list
        grep -Pzo "	 0\) .*\n(	 [1-9][0-9]*\) .*\n)*\n$" "$logf" |
            # Remove leading whitespace
            sed 's/^	 //' |
            # Remove the last garbage line
            head -n-1 |
            # Retrieve the desired station number
            ask | ask -d')' -f1)"\n"
}

# Launch pianobar on any command
if [[ -z $(pidof $pianobar) ]]; then
    case "$1" in
        toggle|play|next|voldown|volup|volreset| \
            love|ban|tired| \
            explain|info|upcoming| \
            switch|quickmix|new|newfrom|delete|rename|addgenre|addshared| \
            bookmark|history|feedback|settings|"")

            rm "$ctlf" 2>/dev/null
            rm "$logf" 2>/dev/null
            mkfifo "$ctlf"

            # Send pianobar output to log file, filtering out cruft
            $pianobar |
                sed -u 's/\[2K#   -[0-9][0-9]:[0-9][0-9]\/[0-9][0-9]:[0-9][0-9]\|\[2K//g' |
                tee "$logf"
    esac
fi

case "$1" in
    toggle) cmd "p";;
    play)   cmd "P";;
    pause)  cmd "S";;
    next)   cmd "n";;
    voldown)  cmd "(";;
    volup)    cmd ")";;
    volreset) cmd "^";;

    love)   cmd "+";;
    ban)    cmd "-";;
    tired)  cmd "t";;

    explain)  explain;;
    info)     info;;
    upcoming) upcoming;;

    switch) switch;;
    quickmix) quickmix;;
    new) new;;
esac
