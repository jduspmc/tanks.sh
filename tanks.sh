#!/usr/bin/env bash

####
# Functions

# Clean up screen at exit
cleanup() {
    stty sane  # restore stty
    tput cnorm # restore cursor
    tput rmcup # go back to primary screen
}

# prepare screen
tput smcup                      # switch to alternate screen
stty -echo -icanon min 0 time 0 # change terminal behaviour (no echo and no enter to read)
tput civis                      # hide cursor
trap cleanup EXIT INT TERM

# Source tput wrapper from https://github.com/bahamas10/bash-tput
. ./tput

###
# some constants

# color constants
COL_L_TANK=$'\x1b[38;5;28m'
COL_R_TANK=$'\x1b[38;5;124m'
# col_obstacle=
# col_projectile=
# col_trail1=
# col_trail2=
# col_trail3=
COL_NONE=$'\x1b[0m'

###
# player turn: true for player 1, false for player 2.
player=true

# find playable size
declare -i HEIGHT=$(($(tput lines) - 3)) WIDTH=$(($(tput cols) - 2))

#here logic when screen too small
# Set the columns and rows of the playable space (figure out how to make dynamic sigwinch)
# trap 'resize' SIGWINCH
#
# resize() {
#     ROWS=$(tput lines)
#     COLS=$(tput cols)
# }

left_tank_pos=(1 $((HEIGHT - 4)))
right_tank_pos=($((WIDTH - 14)) $((HEIGHT - 4)))

IFS= read -r -d '' L_TANK <<-"EOF"
     __
   _|__|_//
__/_______\__
\O_O_O_O_O_O/
EOF

IFS= read -r -d '' R_TANK <<-"EOF"
      __
  \\_|__|_
__/_______\__
\O_O_O_O_O_O/
EOF

# special="⋅"

#  ⋅⋅⋅
# ⋅⋅⋅⋅⋅
#  ⋅⋅⋅

###
# initial state
l_angle=45
r_angle=45

draw-tank() {
    local x=$1
    local y=$2
    local tank="$3"

    while IFS= read -r line; do
        tput cup "$y" "$x"
        echo -n "$line"
        ((y++))
    done < <(printf '%s\n' "$tank")
}

draw-left-tank() {
    read -r x y <<<"${left_tank_pos[@]}"
    while IFS= read -r line; do
        tput cup "$y" "$x"
        echo -n "$COL_L_TANK$line$COL_NONE"
        ((y++))
    done <<<"$L_TANK"
}

draw-right-tank() {
    read -r x y <<<"${right_tank_pos[@]}"
    while IFS= read -r line; do
        tput cup "$y" "$x"
        echo -n "$COL_R_TANK$line$COL_NONE"
        ((y++))
    done <<<"$R_TANK"
}

move-tank-right() {
    if [[ $player ]]; then
        ((left_tank_pos[0]++))
    else
        ((right_tank_pos[0]++))
    fi
}

move-tank-left() {
    if $player; then
        ((left_tank_pos[0]--))
    else
        ((right_tank_pos[0]--))
    fi
}

tput clear

tput cup 0 0
echo "0,0"
tput cup "$HEIGHT" 0
echo "0,$HEIGHT"
tput cup 0 "$WIDTH"
echo "0,$WIDTH"
tput cup "$HEIGHT" "$WIDTH"
echo "$WIDTH,$HEIGHT"

while true; do
    draw-tank "${left_tank_pos[@]}" "$COL_L_TANK$L_TANK$COL_NONE"
    draw-tank "${right_tank_pos[@]}" "$COL_R_TANK$R_TANK$COL_NONE"

    # draw-left-tank
    # draw-right-tank
    read -rsn1 key
    case "$key" in
    a)
        move-tank-left
        draw-left-tank
        ;;
    d)
        move-tank-right
        draw-left-tank
        ;;
    q) break ;;
    *) continue ;;
    esac
done

# sleep 10

cleanup

# echo -n "$ESC[25;25H"
# echo -n "$L_TANK"

# echo
C
