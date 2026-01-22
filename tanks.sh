#!/usr/bin/env bash

##########
# source files

# Source tput wrapper from https://github.com/bahamas10/bash-tput
. ./tput

##########
# constants

# color constants
COL_L_TANK=$'\x1b[38;5;28m'
COL_R_TANK=$'\x1b[38;5;124m'
# col_obstacle=
# col_projectile=
# col_trail1=
# col_trail2=
# col_trail3=
COL_NONE=$(tput sgr0)

##########
# global variables

# player turn: true for player 1, false for player 2.
player=1

# find playable size
declare HEIGHT=$(($(tput lines) - 3)) WIDTH=$(($(tput cols) - 2))

#here logic when screen too small
# Set the columns and rows of the playable space (figure out how to make dynamic sigwinch)
# trap 'resize' SIGWINCH
#
# resize() {
#     ROWS=$(tput lines)
#     COLS=$(tput cols)
# }

left_tank_pos=(1 $((HEIGHT - 5)))
right_tank_pos=($((WIDTH - 14)) $((HEIGHT - 5)))

IFS=

read -r -d '' L_TANK <<-"EOF"
     __
   _|__|_//
__/_______\__
\O_O_O_O_O_O/
EOF
L_TANK=$COL_L_TANK$L_TANK$COL_NONE

read -r -d '' R_TANK <<-"EOF"
      __
  \\_|__|_
__/_______\__
\O_O_O_O_O_O/
EOF
R_TANK=$COL_R_TANK$R_TANK$COL_NONE

# special="⋅"

#  ⋅⋅⋅
# ⋅⋅⋅⋅⋅
#  ⋅⋅⋅

##########
# initial state
l_angle=45
r_angle=45
l_power=50
r_power=50

##########
# Functions

# Clean up screen at exit
cleanup() {
    tput cnorm        # restore cursor
    tput rmcup        # go back to primary screen
    stty "$stty_orig" # restore stty
}

# draw a tank
draw-tank() {
    local x=$1
    local y=$2
    local tank=$3
    while read -r line; do
        tput cup "$y" "$x"
        echo -n "$line"
        ((y++))
    done <<<"$tank"
}

# deletes a tank to draw a new one
delete-tank() {
    local x=$1
    local y=$2
    local tank=$3
    local lines=4 # number of lines in tank

    # overwrite each line with spaces
    local i
    for ((i = 0; i < lines; i++)); do
        tput cup $((y + i)) "$x"
        printf '%*s' 13 "" # print enough spaces
    done
}

# draw projectile info
draw-info() {
    local angle=$1
    local power=$2
    local x=$3
    tput cup $((HEIGHT - 1)) "$x"
    # printf "Angle: %3d° - Power: %3d   " "$angle" "$power"
    printf "Angle: %d° - Power: %d\e[K" "$angle" "$power"
}

# move a tank to the right
move-tank-right() {
    if ((player % 2)); then
        delete-tank "${left_tank_pos[@]}" "$L_TANK"
        ((left_tank_pos[0]++))
        draw-tank "${left_tank_pos[@]}" "$L_TANK"
    else
        delete-tank "${right_tank_pos[@]}" "$R_TANK"
        ((right_tank_pos[0]++))
        draw-tank "${right_tank_pos[@]}" "$R_TANK"
    fi
}

# move a tank to the left
move-tank-left() {
    if ((player % 2)); then
        delete-tank "${left_tank_pos[@]}" "$L_TANK"
        ((left_tank_pos[0]--))
        draw-tank "${left_tank_pos[@]}" "$L_TANK"
    else
        delete-tank "${right_tank_pos[@]}" "$R_TANK"
        ((right_tank_pos[0]--))
        draw-tank "${right_tank_pos[@]}" "$R_TANK"
    fi
}

##########
# main game logic

# prepare screen
stty_orig=$(stty -g)
tput smcup                      # switch to alternate screen
stty -echo -icanon min 1 time 0 # change terminal behaviour (no echo and no enter to read)
tput civis                      # hide cursor
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap cleanup EXIT

tput clear # clear to screen to star game

tput cup "$HEIGHT" "$WIDTH"
echo "$WIDTH,$HEIGHT"

# draws initial state
draw-tank "${left_tank_pos[@]}" "$L_TANK"
draw-tank "${right_tank_pos[@]}" "$R_TANK"

while true; do
    draw-info "$l_angle" "$l_power" "0"
    draw-info "$r_angle" "$r_power" $((WIDTH - 22))

    read -rsn1 key
    if [[ $key == $'\e' ]]; then
        read -rsn2 key2
        key+="$key2"
    fi

    case "$key" in
    a | $'\x1b[D') move-tank-left ;;
    d | $'\x1b[C') move-tank-right ;;
    w | $'\x1b[A') if ((player % 2)); then ((l_angle++)); else ((r_angle++)); fi ;;
    s | $'\x1b[B') if ((player % 2)); then ((l_angle--)); else ((r_angle--)); fi ;;
    m) if ((player % 2)); then ((l_power++)); else ((r_power++)); fi ;;
    l) if ((player % 2)); then ((l_power--)); else ((r_power--)); fi ;;
    f | ' ') ((player++)) ;; # fire!
    q) break ;;
    *) continue ;;
    esac
done
