#!/usr/bin/env bash

###########################################################################################
# constants

# terminal default settings
STTY_ORIG=$(stty -g)

# ifs
IFS= # set ifs to null

# color constants
COL_L_TANK=$'\x1b[38;5;21m'
COL_R_TANK=$'\x1b[38;5;1m'
COL_OBSTACLE=$'\x1b[38;5;34m'
BB_ON_W=$'\x1b[1;38;5;0;48;5;15m'
COL_PROJECTILE=$'\x1b[38;5;196m'
COL_TRAIL1=$'\x1b[38;5;208m'
COL_TRAIL2=$'\x1b[38;5;220m'
COL_TRAIL3=$'\x1b[38;5;226m'
COL_EXPLOSION=$'\x1b[38;5;226m'
COL_HIDDEN_EXPLOSION=$'\x1b[38;5;0m\e[48;5;0m'
COL_NONE=$(tput sgr0)

read -r -d '' TUTORIAL <<-EOF
The objective is to destroy the enemy tank.
 
Controls:
    Move Tank:       'a' or Left Arrow (move left)
                     'd' or Right Arrow (move right)
    Adjust Angle:    'w' or Up Arrow (increase angle)
                     's' or Down Arrow (decrease angle)
    Adjust Power:    'm' (increase power)
                     'l' (decrease power)
    Fire Projectile: 'f' or Spacebar
    Quit Game:       'q'
EOF

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

# tank dimensions
TANK_LEN=13
TANK_HEIGHT=4

# explosion frames
read -r -d '' FRAME0 <<-"EOF"
⋅
EOF
FRAME0=$COL_EXPLOSION$FRAME0$COL_NONE

read -r -d '' FRAME1 <<-"EOF"
⋅⋅⋅
⋅⋅⋅
⋅⋅⋅
EOF

FRAME1=$COL_EXPLOSION$FRAME1$COL_NONE

read -r -d '' FRAME2 <<-"EOF"
⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅
EOF
H_FRAME=$FRAME2
FRAME2=$COL_EXPLOSION$FRAME2$COL_NONE
H_FRAME=$COL_HIDDEN_EXPLOSION$H_FRAME$COL_NONE

EX_ARR=("$FRAME0"
    "$FRAME1"
    "$FRAME2"
)

# obstacle character
OBSTACLE="${COL_OBSTACLE}X$COL_NONE"

# projectile characters
BULLET="${COL_PROJECTILE}@$COL_NONE"
TRAIL1="${COL_TRAIL1}*$COL_NONE"
TRAIL2="${COL_TRAIL2}*$COL_NONE"
TRAIL3="${COL_TRAIL3}*$COL_NONE"

# obstacle density settings
MAX_DENS=1
MED_DENS=25
MIN_DENS=50

# angle constants
PI=$(echo "scale=10; 4*a(1)" | bc -l)

# gravity
GRAVITY=30

# power constants (initial projectile velocity)
MAX_POWER=110
MIN_POWER=20
MAX_ANGLE=180
MIN_ANGLE=0

# time evolution
TIME_LEN=300
DELTA=0.025

declare -a TIME_ARR

for ((k = 0; k <= TIME_LEN; k++)); do
    TIME_ARR[k]+=$(bc -l <<<"$k*$DELTA")
done

###########################################################################################
# global variables

# player turn
player=1

# find playable size
height=$(tput lines)
width=$(tput cols)
# ensure playable area divisible by 3
width=$((width - width % 3))
# playable area sections
area1=$((width / 3))
area2=$((2 * width / 3))

# initial tank positions
left_tank_pos=($((area1 / 3)) $((height - TANK_HEIGHT)))
right_tank_pos=($((5 * area1 / 2)) $((height - TANK_HEIGHT)))

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

# Clean up screen at exit
cleanup() {
    printf "\x1b[?25h"
    printf "\x1b[?1049l"
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
    local line
    local y=0

    # game instructions
    while read -r line; do
        printf '\x1b[%d;%dH%s' "$((height / 7 + y))" "$((width / 7))" "$line"
        ((y++))
    done <<<"$TUTORIAL"
    # menu loop
    while true; do
        item_col=()
        item_col[number % 3]=$BB_ON_W
        printf '\x1b[%d;%dH%s' "$((2 * height / 3))" "$((width / 5))" "Select obstacle density (press 'q' to exit)"
        printf '\x1b[%d;%dH%s' "$((2 * height / 3 + 1))" "$((width / 5 + 2))" "${item_col[0]}Easy$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((2 * height / 3 + 2))" "$((width / 5 + 2))" "${item_col[1]}Normal$COL_NONE"
        printf '\x1b[%d;%dH%s' "$((2 * height / 3 + 3))" "$((width / 5 + 2))" "${item_col[2]}Hard$COL_NONE"

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
        printf '\x1b[%d;%dH%s' "$y" "$x" "$line"
        ((y++))
    done <<<"$tank"
}

# deletes a tank to draw a new one
delete-tank() {
    local x=$1
    local y=$2
    local i
    # overwrite each line with spaces
    for ((i = 0; i <= TANK_HEIGHT; i++)); do
        printf '\x1b[%d;%dH%*s' "$((y + i))" "$x" "$TANK_LEN" ""
    done
}

# draw projectile info
draw-info() {
    local angle=$1
    local power=$2
    local x=$3
    printf '\x1b[%d;%dHAngle: %d° - Power: %d\x1b[K' "$height" "$x" "$angle" "$power"
}

# move a tank to the right
move-tank-right() {
    local area_left=$((area1 - TANK_LEN))
    local area_right=$((width - TANK_LEN))
    if ((player % 2)); then
        if ((left_tank_pos[0] == area_left + 1)); then return; fi # make sure tank does not leave area
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
        if ((left_tank_pos[0] == 0)); then return; fi
        delete-tank "${left_tank_pos[@]}" "$L_TANK"
        ((left_tank_pos[0]--))
        draw-tank "${left_tank_pos[@]}" "$L_TANK"
    else
        if ((right_tank_pos[0] == area2 + 1)); then return; fi
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

        sleep 0.015 # sleep animation

        # Erase the bullet by printing a space in the same spot
        ((pos_y[i] > 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i]}" "${pos_x[i]}" " "
        # remove trail
        ((i > 0 && pos_y[i - 1] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 1]}" "${pos_x[i - 1]}" " "
        ((i > 1 && pos_y[i - 2] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 2]}" "${pos_x[i - 2]}" " "
        ((i > 2 && pos_y[i - 3] >= 0)) && printf '\x1b[%d;%dH%s' "${pos_y[i - 3]}" "${pos_x[i - 3]}" " "
    done
}

# collision with obstacle
collision() {
    local blt_x=$1
    local blt_y=$2
    if [[ -v obstacles_array["$blt_x,$blt_y"] ]]; then
        aplay ./sound/explosion_4.wav &>/dev/null & # play sound
        explosion "$blt_x" "$blt_y"
        # update obstacle
        for ((i = blt_x - 2; i <= blt_x + 2; i++)); do
            for ((j = blt_y - 3; j <= blt_y + 1; j++)); do
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
    if ((blt_y > height - 4)); then
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
    printf "\x1b[H\x1b[2J" # clear
    printf '\x1b[%d;%dH%s' "$((height / 2))" "$((width / 2 - ${#msg}))" "$msg"
    sleep 3
    cleanup
    main
}

lose() {
    local msg
    msg="Player $1 killed himself!"
    printf "\x1b[H\x1b[2J" # clear
    printf '\x1b[%d;%dH%s' "$((height / 2))" "$((width / 2 - ${#msg}))" "$msg"
    sleep 3
    cleanup
    main
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
            printf '\x1b[%d;%dH%s' "$((row + mv_frame_v))" "$((x + mv_frame_h))" "$line"
            ((row++))
        done <<<"$frame"
        ((mv_frame_v--))
        ((mv_frame_h--))
        sleep 0.05
    done
    row=$((y - 1))
    while read -r line; do
        printf '\x1b[%d;%dH%s' "$((row + mv_frame_v + 1))" "$((x + mv_frame_h + 1))" "$line"
        ((row++))
    done <<<"$H_FRAME"
}

###########################################################################################
# main game logic

# prepare screen
main() {
    local key
    local key2

    screen-too-small # check if the screen is acceptable
    # trap signals
    trap 'check-resize' WINCH
    trap 'cleanup; exit 130' INT
    trap 'cleanup; exit 143' TERM
    trap cleanup EXIT

    # prepare screen for game
    printf "\x1b[?1049h"            # switch to alternate screen
    stty -echo -icanon min 1 time 0 # change terminal behaviour (no echo and no enter to read)
    printf "\x1b[?25l"              # hide cursor
    printf "\x1b[H\x1b[2J"          # clear to screen to menu
    # Print initial menu
    print-menu
    printf "\x1b[H\x1b[2J" # clear to screen to start game
    # draw obstacle
    set-obstacles "$density"
    draw-obstacles
    # draws initial state
    draw-tank "${left_tank_pos[@]}" "$L_TANK"
    draw-tank "${right_tank_pos[@]}" "$R_TANK"
    # main game loop
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
