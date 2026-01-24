#!/usr/bin/env bash

###########################################################################################
# source files

# source constants. This file was getting long.
. ./constants

###########################################################################################
# Functions

# tput wrapper taken and modified from https://github.com/bahamas10/bash-tput (that guy is awesome)
tput() {

    local opt OPTIND OPTARG
    while getopts 'ST:' opt; do
        case "$opt" in
        S)
            command tput "$@"
            return $?
            ;;
        T) true ;;
        *) exit 2 ;;
        esac
    done
    shift "$((OPTIND - 1))"

    local ESC=$'\x1b'

    case "$1" in
    bel) printf '%s' $'\x7' ;;
    sgr0 | me) printf '%s' "${ESC}[0m" ;;
    bold) printf '%s' "${ESC}[1m" ;;
    dim) printf '%s' "${ESC}[2m" ;;
    rev) printf '%s' "${ESC}[7m" ;;
    blink) printf '%s' "${ESC}[5m" ;;
    setaf | AF) printf '%s' "${ESC}[38;5;$2m" ;;
    setab | AB) printf '%s' "${ESC}[48;5;$2m" ;;
    sc) printf '%s' "${ESC}7" ;;
    rc) printf '%s' "${ESC}8" ;;
    cnorm) printf '%s' "${ESC}[?25h" ;;
    civis) printf '%s' "${ESC}[?25l" ;;
    smcup) printf '%s' "${ESC}[?1049h" ;;
    rmcup) printf '%s' "${ESC}[?1049l" ;;
    clear) printf '%s%s' "${ESC}[H" "${ESC}[2J" ;;
    home) printf '%s' "${ESC}[H" ;;
    cuu) printf '%s' "${ESC}[$2A" ;;
    cud) printf '%s' "${ESC}[$2B" ;;
    cuf) printf '%s' "${ESC}[$2C" ;;
    cub) printf '%s' "${ESC}[$2D" ;;
    cup)
        local row=$(($2 + 1))
        local col=$(($3 + 1))
        printf '%s[%d;%dH' "$ESC" "$row" "$col"
        ;;
    *)
        command tput "$@"
        return $?
        ;;
    esac
}

# Clean up screen at exit
cleanup() {
    tput cnorm        # restore cursor
    tput rmcup        # go back to primary screen
    stty "$STTY_ORIG" # restore stty
}

# set obstacles
set-obstacles() {
    local i j line
    local dens=$1
    local minx=$((area1 + 1))

    for ((j = 1; j <= height; j++)); do
        for ((i = minx; i <= area2; i++)); do
            if ((RANDOM % dens == 0)); then
                obstacles_array["$i,$j"]="$OBSTACLE"
            fi
        done
    done
}

# draw obstacles
draw-obstacles() {
    local i j line
    local minx=$((area1 + 1))

    for ((j = 1; j <= height; j++)); do
        line=""
        for ((i = minx; i <= area2; i++)); do
            if [[ -v obstacles_array["$i,$j"] ]]; then
                line+="${obstacles_array["$i,$j"]}"
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

    # game instructions
    printf '\x1b[%d;%dH%s' "$((height / 7))" "$((width / 7))" "The objective is to destroy the enemy tank."
    printf '\x1b[%d;%dH%s' "$((height / 7 + 2))" "$((width / 7))" "Controls:"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 3))" "$((width / 7))" "Move Tank:       'a' or Left Arrow (move left)"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 4))" "$((width / 7))" "                 'd' or Right Arrow (move right)"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 5))" "$((width / 7))" "Adjust Angle:    'w' or Up Arrow (increase angle)"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 6))" "$((width / 7))" "                 's' or Down Arrow (decrease angle)"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 7))" "$((width / 7))" "Adjust Power:    'm' (increase power)"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 8))" "$((width / 7))" "                 'l' (decrease power)"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 9))" "$((width / 7))" "Fire Projectile: 'f' or Spacebar"
    printf '\x1b[%d;%dH%s' "$((height / 7 + 10))" "$((width / 7))" "Quit Game:       'q'"

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
        printf '\x1b[%d;%dH%s' "$((height / 2))" "$((width / 5))" "Select obstacle density (press 'q' to exit)"
        printf '\x1b[%d;%dH%s' "$((height / 2 + 1))" "$((width / 5 + 1))" "${col_1}Easy$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((height / 2 + 2))" "$((width / 5 + 1))" "${col_2}Normal$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((height / 2 + 3))" "$((width / 5 + 1))" "${col_3}Hard$COL_NONE"

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
        printf '%s' "$line"
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

# fires the bullet
fire-bullet() {
    local i j
    local x=$1 # 11 from cursor
    local y=$2 # actual y position of tank

    ((y = y + 1))

    if ((player % 2)); then ((x = x + 11)); else ((x = x + 3)); fi # adjust bullet initial position

    if ((player % 2)); then # Player 1's bullet
        for ((i = x; i < width; i++)); do
            # Print the bullet
            printf '\x1b[%d;%dH%s' "$y" "$i" "$BULLET"

            # add trail
            if ((i > x + 1)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i - 1))" "$TRAIL1"
            fi
            if ((i > x + 2)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i - 2))" "$TRAIL2"
            fi
            if ((i > x + 3)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i - 3))" "$TRAIL3"
            fi

            # sleep animation
            sleep 0.015 # figure out what number is best

            # Erase the bullet by printing a space in the same spot
            printf '\x1b[%d;%dH%s' "$y" "$i" " "
            if ((i > x + 1)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i - 1))" " "
            fi
            if ((i > x + 2)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i - 2))" " "
            fi
            if ((i > x + 3)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i - 3))" " "
            fi
        done
        # draw-tank "${right_tank_pos[@]}" "$R_TANK"
    else
        # Player 2's bullet
        for ((i = x; i > 0; i--)); do

            printf '\x1b[%d;%dH%s' "$y" "$i" "$BULLET"

            # add trail
            if ((i < x - 1)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i + 1))" "$TRAIL1"
            fi
            if ((i < x - 2)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i + 2))" "$TRAIL2"
            fi
            if ((i < x - 3)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i + 3))" "$TRAIL3"
            fi

            # sleep animation
            sleep 0.015 # figure out what number is best

            # Erase the bullet by printing a space in the same spot
            printf '\x1b[%d;%dH%s' "$y" "$i" " "
            if ((i < x - 1)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i + 1))" " "
            fi
            if ((i < x - 2)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i + 2))" " "
            fi
            if ((i < x - 3)); then
                printf '\x1b[%d;%dH%s' "$y" "$((i + 3))" " "
            fi
        done
        # draw-tank "${left_tank_pos[@]}" "$L_TANK"
    fi
}

# collision logic

# take bullet current position. check if there is obstacle. trigger explosion.
collision() {
    local bullet_x=$1
    local bullet_y=$2
    if [[ -v obstacles_array["$bullet_x,$bullet_y"] ]]; then
        explosion "$" "$" #   explosion
    fi
}

explosion() {

    for fr in "${EX_ARR[@]}"; do
        tput
        printf '%s' "$fr"
    done
}

# calculate parabolic motion

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

    # Print initial menu
    print-menu

    tput clear # clear to screen to star game

    # draw obstacle
    set-obstacles "$density"
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
        m) if ((player % 2)); then ((l_power < MAX_POWER ? l_power++ : l_power)); else ((r_power < MAX_POWER ? r_power++ : r_power)); fi ;;
        l) if ((player % 2)); then ((l_power > MIN_POWER ? l_power-- : l_power)); else ((r_power > MIN_POWER ? r_power-- : r_power)); fi ;;
        a | $'\x1b[D') move-tank-left ;;
        d | $'\x1b[C') move-tank-right ;;
        w | $'\x1b[A') if ((player % 2)); then
            ((l_angle < 180 ? l_angle++ : l_angle))
            l_angle_rad=$(bc -l <<<"$PI*$l_angle/180")
        else
            ((r_angle < 180 ? r_angle++ : r_angle))
            r_angle_rad=$(bc -l <<<"$PI*$r_angle/180")
        fi ;;
        s | $'\x1b[B') if ((player % 2)); then
            ((l_angle > 0 ? l_angle-- : l_angle))
            l_angle_rad=$(bc -l <<<"$PI*$l_angle/180")
        else
            ((r_angle > 0 ? r_angle-- : r_angle))
            r_angle_rad=$(bc -l <<<"$PI*$r_angle/180")
        fi ;;
        f | ' ')
            if ((player % 2)); then fire-bullet "${left_tank_pos[@]}"; else fire-bullet "${right_tank_pos[@]}"; fi
            ((player++))
            ;; # fire!
        q) break ;;
        *) continue ;;
        esac
    done
}

main
