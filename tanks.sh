#!/usr/bin/env bash

###########################################################################################
# source files

# source constants. This file was getting long.
. ./constants

###########################################################################################
# global variables

# player turn
player=1

# find playable size
height=$(($(tput lines) - 1))
width=$(($(tput cols)))
# ensure playable area divisible by 3
width=$((width - width % 3))

# playable area sections
area1=$((width / 3))
area2=$((2 * width / 3))

# initial tank position
left_tank_pos=(0 $((height - TANK_HEIGHT)))
right_tank_pos=($((width - TANK_LEN)) $((height - TANK_HEIGHT)))

# initial quantities
l_angle=45
r_angle=45
l_angle_rad=$(bc -l <<<"$PI*$l_angle/180")
r_angle_rad=$(bc -l <<<"$PI*$r_angle/180")

l_power=40
r_power=40
density=50

# declare obstacle array
declare -A obstacles_array

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
    stty "$STTY_ORIG" # restore
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

# don't want to deal with resizing. Maybe later
check-resize() {
    cleanup
    echo ""
    echo "Don't resize the terminal window during the game!" >&2
    exit 1
}

# prints menu and sets density
print-menu() {
    local -a item_col
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
        unset item_col
        item_col[number % 3]=$BB_ON_W

        printf '\x1b[%d;%dH%s' "$((height / 2))" "$((width / 5))" "Select obstacle density (press 'q' to exit)"
        printf '\x1b[%d;%dH%s' "$((height / 2 + 1))" "$((width / 5 + 1))" "${item_col[0]}Easy$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((height / 2 + 2))" "$((width / 5 + 1))" "${item_col[1]}Normal$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((height / 2 + 3))" "$((width / 5 + 1))" "${item_col[2]}Hard$COL_NONE"

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key2
            key+="$key2"
        fi
        case "$key" in
        w | $'\x1b[A') ((number += 2)) ;;
        s | $'\x1b[B') ((number++)) ;;
        '') break ;;
        q)
            cleanup
            exit 0
            ;;
        *) continue ;;
        esac
        if ((number % 3 == 0)); then
            density=$MIN_DENS
        elif ((number % 3 == 1)); then
            density=$MED_DENS
        else
            density=$MAX_DENS
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
    tput cup $((height)) "$x"
    printf "Angle: %d° - Power: %d\e[K" "$angle" "$power"
}

# move a tank to the right
move-tank-right() {
    local area_left=$((area1 - TANK_LEN))
    local area_right=$((width - TANK_LEN))
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
    local i
    local xinit=$1
    local yinit=$(($2 + TANK_HEIGHT))
    local tank_shift
    local -a pos_x
    local -a pos_y

    local v_x
    local v_y

    if ((player % 2)); then
        tank_shift=11 # cannon is not corner
        v_x=$(bc -l <<<"$l_power*c($l_angle_rad)")
        v_y=$(bc -l <<<"$l_power*s($l_angle_rad)")
    else
        tank_shift=3 # cannon is not corner
        v_x=$(bc -l <<<"0 - $r_power*c($r_angle_rad)")
        v_y=$(bc -l <<<"$r_power*s($r_angle_rad)")
    fi

    aplay ./sound/explosion_2.wav &>/dev/null & # play sound
    for ((i = 0; i <= TIME_LEN; i++)); do
        pos_x[i]=$(bc -l <<<"$tank_shift+$xinit+$v_x*${TIME_ARR[$i]}")
        pos_x[i]=$(printf '%.0f' "${pos_x[i]}") # turn into integer
        pos_y[i]=$(bc -l <<<"$height - ($yinit + $v_y*${TIME_ARR[$i]} - 0.5*$GRAVITY*(${TIME_ARR[$i]})^2)")
        pos_y[i]=$(printf '%.0f' "${pos_y[i]}")
        if ((pos_y[i] > height - 1)); then break; fi
        if ((pos_x[i] >= width || pos_x[i] <= 0)); then break; fi
        # echo "$i - ${pos_x[i]} - ${pos_y[i]}" >>data.dat
        # check collision
        collision "${pos_x[i]}" "${pos_y[i]}" || return # if there is a collision return
        tank-collision "${pos_x[i]}" "${pos_y[i]}"      # if there is a collision with tank and end

        # Print the bullet
        ((pos_y[i] > 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i]}" "${pos_x[i]}" "$BULLET"
        # add trail
        ((i > 0 && pos_y[i - 1] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 1]}" "${pos_x[i - 1]}" "$TRAIL1"
        ((i > 1 && pos_y[i - 2] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 2]}" "${pos_x[i - 2]}" "$TRAIL2"
        ((i > 2 && pos_y[i - 3] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 3]}" "${pos_x[i - 3]}" "$TRAIL3"

        # sleep animation
        sleep 0.015 # figure out what number is best

        # Erase the bullet by printing a space in the same spot
        ((pos_y[i] > 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i]}" "${pos_x[i]}" " "
        # remove trail
        ((i > 0 && pos_y[i - 1] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 1]}" "${pos_x[i - 1]}" " "
        ((i > 1 && pos_y[i - 2] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 2]}" "${pos_x[i - 2]}" " "
        ((i > 2 && pos_y[i - 3] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 3]}" "${pos_x[i - 3]}" " "
    done
    draw-tank "${right_tank_pos[@]}" "$R_TANK"
    draw-tank "${left_tank_pos[@]}" "$L_TANK"
}

# collision logic
# collision with obstacle
collision() {
    local blt_x=$1
    local blt_y=$2
    if [[ -v obstacles_array["$blt_x,$blt_y"] ]]; then
        aplay ./sound/explosion_4.wav &>/dev/null & # play sound
        explosion "$blt_x" "$blt_y"
        # update obstacle
        for ((i = blt_x - 2; i <= blt_x + 2; i++)); do
            for ((j = blt_y - 2; j <= blt_y + 2; j++)); do
                unset "obstacles_array[$i,$j]"
            done
        done
        draw-obstacles
        return 1
    fi
}

# collision bullet-tank
tank-collision() {
    local blt_x=$1
    local blt_y=$2

    # if bullet is where tank is then explosion.
    if ((blt_y > height - 5)); then
        if ((blt_x >= right_tank_pos[0] && blt_x <= right_tank_pos[0] + TANK_LEN)); then
            aplay ./sound/mechanical_explosion.wav &>/dev/null &
            explosion "$blt_x" "$blt_y"
            if ((player % 2)); then
                # win condition
                win 1
            else
                # suicide
                lose 2
            fi
        fi
        if ((blt_x >= left_tank_pos[0] && blt_x <= left_tank_pos[0] + TANK_LEN)); then
            aplay ./sound/mechanical_explosion.wav &>/dev/null &
            explosion "$blt_x" "$blt_y"
            if ((player % 2)); then
                # suicide
                lose 1
            else
                # win condition
                win 2
            fi
        fi
    fi
}

win() {
    local msg
    msg="Player $1 wins!"
    tput clear
    printf '\x1b[%d;%dH%s' "$((height / 2))" "$((width / 2 - ${#msg}))" "$msg"
    sleep 2
    cleanup
    exit 0
}

lose() {
    local msg
    msg="Player $1 killed himself!"
    tput clear
    printf '\x1b[%d;%dH%s' "$((height / 2))" "$((width / 2 - ${#msg}))" "$msg"
    sleep 2
    cleanup
    exit 0
}

# print explosions
explosion() {
    local x=$1
    local y=$2
    local frame line row i j
    local mv_frame_v=0
    local mv_frame_h=0
    for frame in "${EX_ARR[@]}"; do
        row=$((y - 1))
        while read -r line; do
            tput cup "$((row + mv_frame_v))" "$((x + mv_frame_h - 1))"
            printf '%s' "$line"
            ((row++))
        done <<<"$frame"
        ((mv_frame_v--))
        ((mv_frame_h--))
        sleep 0.06
    done
    row=$((y - 1))
    while read -r line; do
        tput cup "$((row + mv_frame_v + 1))" "$((x + mv_frame_h))"
        printf '%s' "$line"
        ((row++))
    done <<<"$H_FRAME"
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

    # Print initial menu
    print-menu

    tput clear # clear to screen to star game

    # draw obstacle
    set-obstacles "$density"
    draw-obstacles

    # draws initial state
    draw-tank "${left_tank_pos[@]}" "$L_TANK"
    draw-tank "${right_tank_pos[@]}" "$R_TANK"

    while true; do
        draw-info "$l_angle" "$l_power" "0"
        draw-info "$r_angle" "$r_power" $((width - 23))

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
            ((l_angle < MAX_ANGLE ? l_angle++ : l_angle))
            l_angle_rad=$(bc -l <<<"$PI*$l_angle/180")
        else
            ((r_angle < MAX_ANGLE ? r_angle++ : r_angle))
            r_angle_rad=$(bc -l <<<"$PI*$r_angle/180")
        fi ;;
        s | $'\x1b[B') if ((player % 2)); then
            ((l_angle > MIN_ANGLE ? l_angle-- : l_angle))
            l_angle_rad=$(bc -l <<<"$PI*$l_angle/180")
        else
            ((r_angle > MIN_ANGLE ? r_angle-- : r_angle))
            r_angle_rad=$(bc -l <<<"$PI*$r_angle/180")
        fi ;;
        f | ' ')
            if ((player % 2)); then fire-bullet "${left_tank_pos[0]}"; else fire-bullet "${right_tank_pos[0]}"; fi
            ((player++))
            ;; # fire!
        q) break ;;
        *) continue ;;
        esac
    done
}

main
