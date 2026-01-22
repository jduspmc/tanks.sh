#!/usr/bin/env bash

cleanup() {
    stty sane  # restore stty
    tput cnorm # restore cursor
    tput rmcup # go back to primary screen
    exit 0
}

IFS= read -r -d '' L_TANK <<-"EOF"
     __
   _|__|_//
__/_______\__
\O_O_O_O_O_O/
EOF

COL_L_TANK=$'\x1b[38;5;28m'
COL_NONE=$'\x1b[0m'

L_TANK=$COL_L_TANK$L_TANK$COL_NONE

# echo "$L_TANK"

draw-tank() {
    local tank=$1

    # tput cup "$y" "$x"
    # printf '%s\n' "$tank"
    # echo "$tank"
    printf '%*s' 20 "x"

    # while IFS= read -r line; do
    #     tput cup "$y" "$x"
    #     echo -n "$line"
    #     ((y++))
    # done < <(printf '%s\n' "$tank")
}

tput smcup                      # switch to alternate screen
stty -echo -icanon min 0 time 0 # change terminal behaviour (no echo and no enter to read)
tput civis                      # hide cursor
trap cleanup EXIT SIGINT TERM

tput clear # clear to screen to star game

printf '%*s' 10 "x"
printf "%s%.0s" "$L_TANK" {1..10}

# printf 'x%.0s' {1..10}

while true; do
    read -rsn1 key
    case "$key" in
    d)
        tput cup 25 0
        draw-tank "$L_TANK"
        ;;
    q) break ;;
    esac
done

cleanup
