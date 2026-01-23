#!/usr/bin/env bash

###########################################################################################
# source files

# Source tput wrapper from https://github.com/bahamas10/bash-tput
. ./tput

###########################################################################################
# constants

STTY_ORIG=$(stty -g)

# ifs
IFS= # set ifs to null

# color constants
COL_L_TANK=$'\x1b[38;5;28m'
COL_R_TANK=$'\x1b[38;5;124m'
COL_OBSTACLE=$'\x1b[38;5;44m'
BB_ON_W=$'\x1b[1;38;5;0;48;5;15m'
# col_projectile=
# col_trail1=
# col_trail2=
# col_trail3=
COL_NONE=$(tput sgr0)

# left tank
read -r -d '' L_TANK <<-"EOF"
     __
   _|__|_//
__/_______\__
\O_O_O_O_O_O/
EOF
L_TANK=$COL_L_TANK$L_TANK$COL_NONE

# right tank
read -r -d '' R_TANK <<-"EOF"
      __
  \\_|__|_
__/_______\__
\O_O_O_O_O_O/
EOF
R_TANK=$COL_R_TANK$R_TANK$COL_NONE

# obstacle character
OBSTACLE=X
OBSTACLE=$COL_OBSTACLE$OBSTACLE$COL_NONE

# power constants (initial projectile velocity)
MAX_POWER=100
MIN_POWER=20

###########################################################################################
# global variables

# player turn
player=1

# find playable size
height=$(($(tput lines) - 3))
width=$(($(tput cols) - 2))
# ensure playable area divisible by 3
width=$((width - width % 3))

# playable area sections
tank_len=13
area1=$((width / 3))
area2=$((2 * width / 3))

# initial tank position
left_tank_pos=(1 $((height - 5)))
right_tank_pos=($((width - 14)) $((height - 5)))
# initial state
l_angle=45
r_angle=45
l_power=50
r_power=50
density=50

# declare obstacle array
declare -A obstacles_array

# special="⋅"

#  ⋅⋅⋅
# ⋅⋅⋅⋅⋅
#  ⋅⋅⋅

###########################################################################################
# Functions

# game instructions
usage() {
    cat <<EOF
# Here instructions

EOF
}

# Clean up screen at exit
cleanup() {
    tput cnorm        # restore cursor
    tput rmcup        # go back to primary screen
    stty "$STTY_ORIG" # restore stty
}

# draw obstacle
draw-obstacles() {
    local i j line
    local dens=$1
    local minx=$area1

    for ((j = 1; j <= height; j++)); do
        line=""

        for ((i = area1; i <= area2; i++)); do
            if ((RANDOM % dens == 0)); then
                obstacles_array["$i,$j"]="$OBSTACLE"
                line+="$OBSTACLE"
            else
                line+=" "
            fi
        done
        printf '\e[%d;%dH%s' "$j" "$minx" "$line"
    done
}

# if screen too small we can't play
screen-too-small() {
    if ((width < 60 || height < 24)); then
        cleanup
        echo ""
        echo "Terminal is too small to play." >&2
        echo "Please resize to at least 60 columns and 24 lines and try again." >&2
        exit 1
    fi
}

check-resize() {
    cleanup
    echo ""
    echo "Don't resize the terminal window during the game!" >&2
    exit 1
}

# prints menu and sets density
print-menu() {
    local col_1 col_2 col_3
    local number=0

    printf '\x1b[%d;%dH%s' "$((height / 3))" "$((width / 4))" "The objective is to destroy the enemy tank."
    printf '\x1b[%d;%dH%s' "$((height / 3 + 1))" "$((width / 4))" "Press a, d or left, down to move the tank. Pres m, l to"
    printf '\x1b[%d;%dH%s' "$((height / 3 + 2))" "$((width / 4))" "adjust projectile power. Press w, s or up, down to"
    printf '\x1b[%d;%dH%s' "$((height / 3 + 3))" "$((width / 4))" "adjust firing angle. Press q to quit."

    while true; do
        if ((number % 3 == 0)); then
            col_1=$BB_ON_W
            col_2=
            col_3=
        elif ((number % 3 == 1)); then
            col_1=
            col_2=$BB_ON_W
            col_3=
        else
            col_1=
            col_2=
            col_3=$BB_ON_W
        fi
        printf '\x1b[%d;%dH%s' "$((height - height / 3))" "$((width / 4))" "Select obstacle density (press 'q' to exit)"
        printf '\x1b[%d;%dH%s' "$((height - height / 3 + 1))" "$((width / 4 + 1))" "${col_1}Easy$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((height - height / 3 + 2))" "$((width / 4 + 1))" "${col_2}Normal$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((height - height / 3 + 3))" "$((width / 4 + 1))" "${col_3}Hard$COL_NONE"

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key2
            key+="$key2"
        fi
        case "$key" in
        w | $'\x1b[A') ((number--)) ;;
        s | $'\x1b[B') ((number++)) ;;
        '') break ;;
        q) exit 0 ;;
        *) continue ;;
        esac
        if ((number % 3 == 0)); then
            density=50
        elif ((number % 3 == 1)); then
            density=20
        else
            density=1
        fi
    done
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
    tput cup $((height - 1)) "$x"
    # printf "Angle: %3d° - Power: %3d   " "$angle" "$power"
    printf "Angle: %d° - Power: %d\e[K" "$angle" "$power"
}

# move a tank to the right
move-tank-right() {
    local area_left=$((area1 - tank_len))
    local area_right=$((width - tank_len))
    if ((player % 2)); then
        if ((left_tank_pos[0] == area_left)); then return; fi # make sure tank does not leave area
        delete-tank "${left_tank_pos[@]}" "$L_TANK"
        ((left_tank_pos[0]++))
        draw-tank "${left_tank_pos[@]}" "$L_TANK"
    else
        if ((right_tank_pos[0] == area_right)); then return; fi
        delete-tank "${right_tank_pos[@]}" "$R_TANK"
        ((right_tank_pos[0]++))
        draw-tank "${right_tank_pos[@]}" "$R_TANK"
    fi
}

# move a tank to the left
move-tank-left() {
    if ((player % 2)); then
        if ((left_tank_pos[0] == 1)); then return; fi
        delete-tank "${left_tank_pos[@]}" "$L_TANK"
        ((left_tank_pos[0]--))
        draw-tank "${left_tank_pos[@]}" "$L_TANK"
    else
        if ((right_tank_pos[0] == area2)); then return; fi
        delete-tank "${right_tank_pos[@]}" "$R_TANK"
        ((right_tank_pos[0]--))
        draw-tank "${right_tank_pos[@]}" "$R_TANK"
    fi
}

###########################################################################################
# main game logic

# prepare screen
main() {

    # trap signals
    trap 'check-resize' SIGWINCH
    trap 'cleanup; exit 130' INT
    trap 'cleanup; exit 143' TERM
    trap cleanup EXIT

    local key
    local key2

    screen-too-small # check if the screen is acceptable

    # prepare screen for game
    tput smcup                      # switch to alternate screen
    stty -echo -icanon min 1 time 0 # change terminal behaviour (no echo and no enter to read)
    tput civis                      # hide cursor
    tput clear                      # clear to screen to menu

    print-menu

    tput clear # clear to screen to star game

    # draw obstacle
    draw-obstacles "$density"
    # draws initial state
    draw-tank "${left_tank_pos[@]}" "$L_TANK"
    draw-tank "${right_tank_pos[@]}" "$R_TANK"

    while true; do
        draw-info "$l_angle" "$l_power" "0"
        draw-info "$r_angle" "$r_power" $((width - 22))

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key2
            key+="$key2"
        fi

        case "$key" in
        a | $'\x1b[D') move-tank-left ;;
        d | $'\x1b[C') move-tank-right ;;
        w | $'\x1b[A') if ((player % 2)); then ((l_angle < 180 ? l_angle++ : l_angle)); else ((r_angle < 180 ? r_angle++ : r_angle)); fi ;;
        s | $'\x1b[B') if ((player % 2)); then ((l_angle > 0 ? l_angle-- : l_angle)); else ((r_angle > 0 ? r_angle-- : r_angle)); fi ;;
        m) if ((player % 2)); then ((l_power < MAX_POWER ? l_power++ : l_power)); else ((r_power < MAX_POWER ? r_power++ : r_power)); fi ;;
        l) if ((player % 2)); then ((l_power > MIN_POWER ? l_power-- : l_power)); else ((r_power > MIN_POWER ? r_power-- : r_power)); fi ;;
        f | ' ') ((player++)) ;; # fire!
        q) break ;;
        *) continue ;;
        esac
    done
}

main
