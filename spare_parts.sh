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
