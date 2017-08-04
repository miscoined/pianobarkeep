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
    grep -ox "|>  .*" "$logf" | tail -2 | sed 's/|>  //' | notify
}

# Get the upcoming song list and print it
upcoming () {
    cmd "u"
    # Get the line number of the last call for upcoming songs
    linenum=$(grep -n "^	 0) \|^(i) No songs in queue." "$logf" | tail -1 | cut -d':' -f1)
    # Get the last set of upcoming songs and format it
    tail -n+$linenum "$logf" | sed 's/^(i) \|^	 //' | notify
}

# Retrieve the latest station list in a readable format
askstation () {
    grep -Pzo "\t 0\) .*\n(\t ?[1-9][0-9]*\) .*\n)*$" "$logf" |
        # Trim leading whitespace
        sed 's/^\s\+//' |
        # Remove null line at EOF
        head -n-1 |
        # Retrieve the desired station number
        ask | cut -d')' -f1
}

# Switch stations
switch () {
    cmd "s"
    cmd $(askstation)"\n"
}

# Toggle Quickmix stations
quickmix () {
    cmd "x"
    if grep -zoq '/!\\ Not a QuickMix station\..$' "$logf"; then
        notify "Not a QuickMix station"
    else
        cmd $(askstation)"\n"
        cmd "\n"
    fi
}

# Create a new station
create () {
    cmd "c"
    query="$(ask "Create station from artist or title: ")\n"
    cmd "$query"
    [[ $query == "\n" ]] && return
    sleep 3
    cmd $(askstation)"\n"
}

# Get the current station
# Note that this relies on sending a command to FIFO, and so
# cannot be performed in the middle of a query
getstation () {
    # Ask for station
    cmd "i"
    # Find the station entry
    grep -ox '|>  Station ".*"' "$logf" |
        # Get the relevent part
        tail -1 |
        # Filter out other cruft
        sed 's/^|>  Station "\(.*\)"$/\1/'
}

# Get the current song and artist
# Note that this relies on sending a command to FIFO, and so
# cannot be performed in the middle of a query
getinfo () {
    cmd "i"
    info="$(grep -ox "|>  .*" "$logf" | tail -1 | sed 's/|>  //')"
    song="song) $(echo -e $info | sed 's/^"\([^"]*\)" by.*$/\1/')"
    artist="artist) $(echo -e $info | sed 's/^.*by "\([^"]*\)".*$/\1/')"
    echo -e "$song\n$artist"
}

# Create a new station from the current song or artist
createfrom () {
    prompt="$(getinfo)"
    cmd "v"
    cmd "$(echo -e "$prompt" | ask "Create station from song, or artist? " | cut -c1)\n"
}

# Create a new genre station
creategenre () {
    cmd "g"
    cmd $(askstation)"\n"
    cmd $(askstation)"\n"
}

# Create a new station from a shared one
createshared () {
    cmd "j"
    cmd "$(ask "Station ID: ")\n"
}

# Delete the current station
delete () {
    station="$(getstation)"
    cmd "d"
    cmd $(echo -e "Yes\nNo" | ask "Really delete '$station'? " | cut -c1)"\n"
    sleep 2
    switch
}

# Rename the current station
rename () {
    station="$(getstation)"
    cmd "r"
    cmd "$(ask "Rename '$station' to: ")\n"
}

# Add music to the current station
add () {
    station="$(getstation)"
    cmd "a"
    query="$(ask "Add artist or song to '$station': ")\n"
    cmd "$query"
    [[ $query == "\n" ]] && return
    sleep 3
    cmd $(askstation)"\n"
}

# Bookmark a song or artist
bookmark () {
    prompt="$(getinfo)"
    cmd "b"
    cmd "$(echo -e "$prompt" | ask "Create station from song, or artist? " | cut -c1)\n"
}

# Delete seeds or feedback
deletemeta () {
    cmd "="
    # TODO allow for differentiating when there's only one to delete
    cmd "$(echo -e "Seeds\nFeedback" | ask "Delete seeds, or feedback? ")"
    sleep 1
    cmd "$(askstation)\n"
}


# Launch pianobar on any command
if [[ -z $(pidof $pianobar) ]]; then
    case "$1" in
        toggle|play|pause|quit| \
            voldown|volup|volreset| \
            next|love|ban|tired| \
            explain|info|upcoming| \
            switch|quickmix|delete|rename|add| \
            create|createfrom|creategenre|createshared| \
            bookmark|history|deletemeta|"")

            rm "$ctlf" 2>/dev/null
            rm "$logf" 2>/dev/null
            mkfifo "$ctlf"

            # Send pianobar output to log file, filtering out cruft
            $pianobar |
                tee >(sed -u 's/\[2K#   -[0-9][0-9]:[0-9][0-9]\/[0-9][0-9]:[0-9][0-9]\|\[2K\|[]//g' > "$logf")
    esac
fi

case "$1" in
    toggle) cmd "p";;
    play)   cmd "P";;
    pause)  cmd "S";;
    quit)   cmd "q";;

    volup)    cmd ")";;
    voldown)  cmd "(";;
    volreset) cmd "^";;

    next)   cmd "n";;
    love)   cmd "+";;
    ban)    cmd "-";;
    tired)  cmd "t";;

    explain)  explain;;
    info)     info;;
    upcoming) upcoming;;

    create) create;;
    createfrom) createfrom;;
    creategenre) creategenre;;
    createshared) createshared;;

    switch) switch;;
    quickmix) quickmix;;
    delete) delete;;
    rename) rename;;
    add) add;;
    bookmark) bookmark;;
    deletemeta) deletemeta;;
    #history
esac
