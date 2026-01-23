# draw-left-tank() {
#     read -r x y <<<"${left_tank_pos[@]}"
#     while IFS= read -r line; do
#         tput cup "$y" "$x"
#         echo -n "$COL_L_TANK$line$COL_NONE"
#         ((y++))
#     done <<<"$L_TANK"
# }
#
# draw-right-tank() {
#     read -r x y <<<"${right_tank_pos[@]}"
#     while IFS= read -r line; do
#         tput cup "$y" "$x"
#         echo -n "$COL_R_TANK$line$COL_NONE"
#         ((y++))
#     done <<<"$R_TANK"
# }
# pdraw_obstacles_frame() {
#     local i j row frame=""
#     local minx=$area1
#     local width=$((area2 - area1 + 1))
#
#     for ((j = 1; j <= height; j++)); do
#         row=""
#         for ((i = area1; i <= area2; i++)); do
#             if ((RANDOM % 3 == 0)); then
#                 obstacles["$i,$j"]="X"
#                 row+="X"
#             else
#                 unset 'obstacles["$i,$j"]'
#                 row+=" "
#             fi
#         done
#         frame+="$row"$'\n'
#     done
#
#     tput cup 1 "$area1"
#     printf '%b' "$frame"
# }
#
