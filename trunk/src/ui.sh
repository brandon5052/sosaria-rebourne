# ui.sh
#
# Common user interface functions
#
# This file is part of Sosaria Rebourne. See authors.txt for copyright
# details.
#
# Sosaria Rebourne is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sosaria Rebourne is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Sosaria Rebourne.  If not, see <http://www.gnu.org/licenses/>.

# Configuration
declare -r _ui_roster_x=56
declare -r _ui_roster_y=0
declare -r _ui_inform_x=56
declare -r _ui_inform_y=8
declare -r _ui_help_x=0
declare -r _ui_help_y=33
declare -r _ui_park_x=96
declare -r _ui_park_y=33
declare -r _ui_inventory_lines=8
declare -r _ui_inventory_fg=$COLOR_WHITE
declare -r _ui_inventory_bg=$COLOR_BLACK
declare -r _ui_inventory_hlfg=$COLOR_WHITE
declare -r _ui_inventory_hlbg=$COLOR_BLUE
declare -r _ui_inventory_dsfg=$COLOR_BLACK
declare -r _ui_inventory_dsbg=$COLOR_BLACK

# Park the cursor
function ui_park_cursor
{
	vt100_goto $_ui_park_x $_ui_park_y
}

# Print a new help line
#
# $1	Text of the help line
function ui_new_help_line
{
	local msg_len
	
	# Blank the existing help line
	vt100_high
	vt100_fg $COLOR_WHITE
	vt100_bg $COLOR_BLACK
	vt100_goto $_ui_help_x $_ui_help_y
	echo -n "                                                                                               "
	vt100_goto $_ui_help_x $_ui_help_y
	
	# If we have a message, center it on scren and print it
	if [ -n "$1" ]; then
		msg_len=${#1}
		vt100_goto $(( _ui_help_x + (_common_screen_width - msg_len) / 2 )) \
			$_ui_help_y
		echo -n "$1"
	fi
}

# Render the inform line
#
# $1	Text of the inform line
function ui_inform
{
	local xofs
	
	vt100_fg $COLOR_WHITE
	vt100_bg $COLOR_BLACK
	vt100_high
	vt100_goto $_ui_inform_x $_ui_inform_y
	echo -n "$_log_blank_line"
	
	(( xofs = (${#_log_blank_line} - ${#1}) / 2 ))
	vt100_goto $((_ui_inform_x + xofs)) $_ui_inform_y
	echo -n "$1"
}

# Ask a yes or no question on the help line
#
# $1	The question text
# Returns non-zero if the answer is no
function ui_ask_yes_no
{
	ui_new_help_line "$1 Y/N"
	
	# Input loop
	while :; do
		input_get_key
		case $g_return in
		y|Y) return 0 ;;
		n|N|ESCAPE|SPACE) return 1 ;;
		esac
	done
}

# Render the roster
#
# $1	If present, the monster index of the selected party member
function ui_render_roster
{
	local idx selection
	
	if [ -z "$1" ]; then
		selection="-1"
	else
		selection=$1
	fi
	
	vt100_high
	for (( idx=_combat_num_mobs; \
		idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
		vt100_goto $_ui_roster_x \
			$(( _ui_roster_y + ( idx - _combat_num_mobs ) ))
		if (( selection == idx )); then
			vt100_fg $_ui_inventory_hlfg
			vt100_bg $_ui_inventory_hlbg
		else
			vt100_fg $_ui_inventory_fg
			vt100_bg $_ui_inventory_bg
		fi
		echo -n "$_log_blank_line"
		vt100_goto $_ui_roster_x \
			$(( _ui_roster_y + ( idx - _combat_num_mobs ) ))
		if [ -n "${_combat_mob_name[$idx]}" ]; then
			printf "%-16s " "${_combat_mob_name[$idx]}"
			vt100_fg $COLOR_YELLOW
			printf "%3d " ${_combat_mob_hp[$idx]}
			vt100_fg $COLOR_TEAL
			printf "%3d" ${_combat_mob_mp[$idx]}
		fi
	done
}

# Select a party member from the roster. The selected party member's monster
# index is placed in g_return.
#
# Returns non-zero if the user canceles.
function ui_select_party_member
{
	local select_step=1 cur_target
	(( cur_target=_combat_num_mobs - 1 ))
	
	ui_new_help_line "[Move: ARROWS/jk] [Confirm: ENTER/A] [Cancel: ESCAPE/SPACE]"
	
	while :; do
		# Selection stepping
		(( cur_target += select_step ))
		
		# Selection wrapping
		if (( cur_target >= $_combat_num_mobs + \
			_combat_num_chars )); then
			(( cur_target = _combat_num_mobs - 1 ))
			continue
		fi
		if (( cur_target < $_combat_num_mobs )); then
			(( cur_target= _combat_num_mobs + _combat_num_chars ))
			continue
		fi
		
		# No character check
		if [ -z "${_combat_mob_name[$cur_target]}" ]; then
			continue
		fi
		
		# Display
		ui_render_roster $cur_target

		# Input handling
		while :; do
			input_get_key
			case "$g_return" in
			k|K|UP|LEFT) select_step=-1; break ;;
			j|J|DOWN|RIGHT|TAB) select_step=1; break ;;
			ENTER|a|A)
				ui_render_roster
				g_return=$cur_target
				return 0
			;;
			ESCAPE|SPACE)
				ui_render_roster
				return 1
			;;
			esac
		done
	done
}

# Display the character status screen for a monster
#
# $1	The monster index of the monster
function ui_display_status
{
	local mob_idx=$1 next_level next_exp
	
	# Bind minimum experiance for next level
	if (( _combat_mob_level[$1] >= _combat_level_max )); then
		next_exp="MAX LV"
	else
		(( next_level = _combat_mob_level[$1] + 1 ))
		next_exp="${_combat_level_mins[$next_level]}"
	fi
	
	get_class_string ${_combat_mob_class[$mob_idx]}
	vt100_high
	vt100_fg $COLOR_WHITE
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 0 )); printf "%-16s  Level %2d  %-12s" "${_combat_mob_name[$mob_idx]}" ${_combat_mob_level[$mob_idx]} $g_return
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 1 )); printf "Strength      %-2d            HP: %3d/%-3d " ${_combat_mob_str[$mob_idx]} ${_combat_mob_hp[$mob_idx]} ${_combat_mob_hpmax[$mob_idx]}
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 2 )); printf "Dexderity     %-2d            MP: %3d/%-3d " ${_combat_mob_dex[$mob_idx]} ${_combat_mob_mp[$mob_idx]} ${_combat_mob_mpmax[$mob_idx]}
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 3 )); printf "Intelligence  %-2d                        " ${_combat_mob_int[$mob_idx]}
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 4 )); printf "Armor Class   %-2d            Gold 100000 " ${_combat_mob_ac[$mob_idx]}
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 5 )); printf "Base Damage   %-2d            Food 100000 " ${_combat_mob_dmg[$mob_idx]}
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 6 )); printf "Experiance    %-6d                    " ${_combat_mob_exp[$mob_idx]}
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 7 )); printf "Next Level    %-6s                    " "$next_exp"
}

# Display the equipment of a monster
#
# $1	The monster index of the monster
# $2	If present, the highlighted slot number
function ui_display_equipment
{
	local item_idx mob_idx=$1 selected
	
	if [ -z "$2" ]; then
		selected="-1"
	else
		selected=$2
	fi

	get_class_string ${_combat_mob_class[$mob_idx]}
	vt100_high
	vt100_fg $_ui_inventory_fg
	vt100_bg $_ui_inventory_bg
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 0 )); printf "%-16s  Level %2d  %-12s" "${_combat_mob_name[$mob_idx]}" ${_combat_mob_level[$mob_idx]} $g_return
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 1 )); echo -n "$_log_blank_line"
	item_idx=${_item_mob_head[$mob_idx]}
	if (( selected == 0 )); then vt100_fg $_ui_inventory_hlfg; vt100_bg $_ui_inventory_hlbg; else vt100_fg $_ui_inventory_fg; vt100_bg $_ui_inventory_bg; fi
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 2 )); printf "Head       %-24s %2d " "${_item_name[$item_idx]#* }" ${_item_param[$item_idx]}
	item_idx=${_item_mob_body[$mob_idx]}
	if (( selected == 1 )); then vt100_fg $_ui_inventory_hlfg; vt100_bg $_ui_inventory_hlbg; else vt100_fg $_ui_inventory_fg; vt100_bg $_ui_inventory_bg; fi
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 3 )); printf "Body       %-24s %2d " "${_item_name[$item_idx]#* }" ${_item_param[$item_idx]}
	item_idx=${_item_mob_shield[$mob_idx]}
	if (( selected == 2 )); then vt100_fg $_ui_inventory_hlfg; vt100_bg $_ui_inventory_hlbg; else vt100_fg $_ui_inventory_fg; vt100_bg $_ui_inventory_bg; fi
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 4 )); printf "Shield     %-24s %2d " "${_item_name[$item_idx]#* }" ${_item_param[$item_idx]}
	item_idx=${_item_mob_weapon[$mob_idx]}
	if (( selected == 3 )); then vt100_fg $_ui_inventory_hlfg; vt100_bg $_ui_inventory_hlbg; else vt100_fg $_ui_inventory_fg; vt100_bg $_ui_inventory_bg; fi
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 5 )); printf "Weapon     %-24s %2d " "${_item_name[$item_idx]#* }" ${_item_param[$item_idx]}
	item_idx=${_item_mob_accessory1[$mob_idx]}
	if (( selected == 4 )); then vt100_fg $_ui_inventory_hlfg; vt100_bg $_ui_inventory_hlbg; else vt100_fg $_ui_inventory_fg; vt100_bg $_ui_inventory_bg; fi
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 6 )); printf "Accessory  %-24s    " "${_item_name[$item_idx]#* }"
	item_idx=${_item_mob_accessory2[$mob_idx]}
	if (( selected == 5 )); then vt100_fg $_ui_inventory_hlfg; vt100_bg $_ui_inventory_hlbg; else vt100_fg $_ui_inventory_fg; vt100_bg $_ui_inventory_bg; fi
	vt100_goto $_ui_roster_x $(( _ui_roster_y + 7 )); printf "Accessory  %-24s    " "${_item_name[$item_idx]#* }"
}

# Display the status screen
#
# $1	Initial screen
function ui_zstats
{
	local mob_idx screen mob_mod=0 screen_mod=0 class_string
	
	if [ -n "$1" ]; then
		screen=$1
	else
		screen=0
	fi
	
	ui_select_party_member
	if (( $? != 0 )); then
		return 1
	fi
	mob_idx=$g_return
	
	ui_new_help_line "[Character: UP/DOWN/k/j] [Screen: LEFT/RIGHT/h/l] [Cancel: ESCAPE/SPACE]"

	while :; do
		# Character selection bounding
		(( mob_idx += mob_mod ))
		if (( mob_idx >= _combat_num_mobs + _combat_num_chars )); then
			mob_idx=$_combat_num_mobs
		elif (( mob_idx < _combat_num_mobs )); then
			mob_idx=$(( _combat_num_mobs + _combat_num_chars - 1 ))
		fi
		
		# Valid character check
		if [ -z "${_combat_mob_name[$mob_idx]}" ]; then
			continue
		fi
		mob_mod=0
		
		# Bound screen
		(( screen += screen_mod ))
		if (( screen > 1 )); then
			screen=0
		elif (( screen < 0 )); then
			screen=1
		fi
		screen_mod=0
		
		# Render the screen
		case $screen in
		0) ui_display_status $mob_idx ;;
		1) ui_display_equipment $mob_idx ;;
		esac
		
		while :; do
			input_get_key
			case "$g_return" in
			# Change screen, just ignore for now
			k|K|UP) mob_mod=-1; break ;;
			j|J|DOWN) mob_mod=1; break ;;
			h|H|LEFT) screen_mod=-1; break ;;
			l|L|RIGHT) screen_mod=1; break ;;
			ESCAPE|SPACE)
				# Re-render the roster before exiting
				ui_render_roster
				return 0
			;;
			esac
		done
	done
}

# Display the party inventory screen and select an item if requested. If a
# selection is requested and made, the selected item's index number is placed
# in g_return and we return zero.
#
# $1	Display only items who's item type codes matches this argument. The
#		following special cases apply:
#		"X" All items regardless of type
#		"W" All weapons
#		"w" Only one-handed weapons
# $2	If this is present, allow selection, but only for items that this
#		monster index can use.
# $3	If this is present, insert a "None" item at the top of the list.
# $4	If this is present this is the initially selected index
# Returns non-zero unless a selection is requested and made.
function ui_inventory
{
	local idx item_idx party_idx yofs top=0 selection=0 sel_dir
	local sub_idx sub_item sub_party did_sort amount
	local -a valid_idx
	local -a enabled
	local -a list_item_idx
	local -a list_item_amount
	
	# Build the set of valid items
	for (( idx=0; idx < ${#_item_party_idx[@]}; idx++ )); do
		item_idx=${_item_party_idx[$idx]}
		# Handle special cases
		if [ "$1" = "X" ]; then
			valid_idx=(${valid_idx[@]} $idx)
		# All weapons
		elif [ "$1" = "W" ]; then
			if [ "${_item_type[$item_idx]}" = "M" -o \
				"${_item_type[$item_idx]}" = "m" -o \
				"${_item_type[$item_idx]}" = "R" -o \
				"${_item_type[$item_idx]}" = "r" ]; then
				valid_idx=(${valid_idx[@]} $idx)
			fi
		# All one-handed weapons
		elif [ "$1" = "w" ]; then
			if [ "${_item_type[$item_idx]}" = "M" -o \
				"${_item_type[$item_idx]}" = "R" ]; then
				valid_idx=(${valid_idx[@]} $idx)
			fi
		# Strict type matching
		elif [ "$1" = "${_item_type[$item_idx]}" ]; then
			valid_idx=(${valid_idx[@]} $idx)
		fi
	done
	
	# Bubble sort list of items based on item IDX
	idx=1
	while :; do
		if (( idx >= ${#valid_idx[@]} )); then break; fi
		party_idx=${valid_idx[$idx]}
		item_idx=${_item_party_idx[$party_idx]}
		sub_idx=$(( idx - 1 ))
		did_sort=0
		while :; do
			if (( sub_idx < 0 )); then break; fi
			sub_party=${valid_idx[$sub_idx]}
			sub_item=${_item_party_idx[$sub_party]}
			if (( item_idx < sub_item )); then
				did_sort=1
				valid_idx[$(( sub_idx + 1 ))]=$sub_party
				valid_idx[$sub_idx]=$party_idx
			else
				break
			fi
			(( sub_idx-- ))
		done
		if (( did_sort == 0 )); then
			(( idx++ ))
		fi
	done
	
	# Insert a None item at the top of the list if requested
	if [ -n "$3" ]; then
		list_item_idx=(0)
		list_item_amount=(0)
	fi
	
	# Build the item list
	for (( idx=0; idx < ${#valid_idx[@]}; idx++ )); do
		party_idx=${valid_idx[$idx]}
		item_idx=${_item_party_idx[$party_idx]}
		amount=${_item_party_amount[$party_idx]}
		list_item_idx=(${list_item_idx[@]} $item_idx)
		list_item_amount=(${list_item_amount[@]} $amount)
	done
	
	# Set enabled flags
	for (( idx=0; idx < ${#list_item_idx[@]}; idx++ )); do
		item_idx=${list_item_idx[$idx]}
		if [ -n "$2" ]; then
			if item_can_monster_use $2 $item_idx; then
				enabled[$idx]=1
			else
				enabled[$idx]=0
			fi
		else
			enabled[$idx]=1
		fi
	done
	
	# Empty set special case
	if (( ${#list_item_idx[@]} <= 0 )); then
		ui_new_help_line "[Cancel: ESCAPE/SPACE]"
		vt100_fg $_ui_inventory_fg
		vt100_bg $_ui_inventory_bg
		vt100_high
		for (( idx=0; idx < _ui_inventory_lines; idx++ )); do
			vt100_goto $_ui_roster_x $(( _ui_roster_y + idx ))
			echo -n "$_log_blank_line"
		done
		vt100_goto $_ui_roster_x $_ui_roster_y
		echo -n "None"
		while :; do
			input_get_key
			case "$g_return" in
			ESCAPE|SPACE)
				# Re-render the roster before exiting
				ui_render_roster
				return 1
			;;
			esac
		done
	fi
	
	# Main loop
	if [ -n "$4" ]; then
		selection=$4
	else
		selection=0
	fi
	if [ -z "$2" ]; then
		ui_new_help_line "[Move: ARROWS/jk] [Cancel: ESCAPE/SPACE] [Drop: D] [Drop All: Z]"
	else
		ui_new_help_line "[Move: ARROWS/jk] [Confirm: ENTER/A] [Cancel: ESCAPE/SPACE] [Drop: D] [Drop All: Z]"
	fi
	sel_dir=0
	while :; do
		# Apply the selection direction
		(( selection += sel_dir ))
		
		# Handle looping
		if (( selection < 0 )); then
			(( selection = ${#list_item_idx[@]} - 1 ))
			(( top = ${#list_item_idx[@]} - _ui_inventory_lines ))
			if (( top < 0 )); then
				top=0
			fi
		elif (( selection >= ${#list_item_idx[@]} )); then
			selection=0
			top=0
		# Handle scrolling
		else
			if (( sel_dir < 0 && selection < top)); then
				top=$selection
			elif (( sel_dir > 0 && selection >= top + _ui_inventory_lines ))
			then
				(( top = selection - (_ui_inventory_lines - 1) ))
			fi
		fi
		sel_dir=0
		
		# Display the list
		for (( idx = top; idx < top + _ui_inventory_lines; idx++ )); do
			(( yofs = idx - top ))
			vt100_high
			vt100_goto $_ui_roster_x $(( _ui_roster_y + yofs ))
			item_idx=${list_item_idx[$idx]}
			item_get_type_string ${_item_type[$item_idx]}
			# Past end of list
			if (( idx >= ${#list_item_idx[@]} )); then
				vt100_fg $_ui_inventory_fg
				vt100_bg $_ui_inventory_bg
				echo -n "$_log_blank_line"
			else
				# Selected item
				if (( selection == idx )); then
					vt100_bg $_ui_inventory_hlbg
					if (( enabled[$idx] != 1 )); then
						vt100_fg $_ui_inventory_dsfg
					else
						vt100_fg $_ui_inventory_hlfg
					fi
				# Disabled item
				elif (( enabled[$idx] != 1 )); then
					vt100_fg $_ui_inventory_dsfg
					vt100_bg $_ui_inventory_dsbg
				# Enabled item
				else
					vt100_fg $_ui_inventory_fg
					vt100_bg $_ui_inventory_bg
				fi
				
				# Print item line
				if (( item_idx == 0 )); then
					printf "    %-24s           " "${_item_name[$item_idx]#* }"
				else
					printf "%3d %-24s %-10s" "${list_item_amount[$idx]}" \
						"${_item_name[$item_idx]#* }" "$g_return"
				fi
			fi
		done
		
		# Handle input
		while :; do
			input_get_key
			case "$g_return" in
			k|K|UP) sel_dir="-1"; break ;;
			j|J|DOWN) sel_dir=1; break ;;
			d|D)
				item_idx=${list_item_idx[$selection]}
				if ui_ask_yes_no "Drop ${_item_name[$item_idx]}?"; then
					item_remove_from_inventory $item_idx
				fi
				ui_inventory "$1" "$2" "$3" "$selection"
				return $?
			;;
			z|Z)
				item_idx=${list_item_idx[$selection]}
				if ui_ask_yes_no "Drop EVERY ${_item_name[$item_idx]#* }?"; then
					item_remove_from_inventory $item_idx 99999
				fi
				ui_inventory "$1" "$2" "$3" "$selection"
				return $?
			;;
			a|A|ENTER)
				if (( enabled[$selection] > 0 )); then
					g_return=${list_item_idx[$selection]}
					# Re-render the roster before exiting
					ui_render_roster
					return 0				
				fi
			;;
			ESCAPE|SPACE)
				# Re-render the roster before exiting
				ui_render_roster
				return 1
			;;
			esac
		done
	done
}

# Equipment change UI
#
# $1	The monster index of the player to change equipment for
# $2	If this is present, return after one equipment change
# Returns non-zero if an equipment change was not actually made
function ui_equip_change
{
	local equip_slot=0 equip_type_code slot_code equip_slot_dir=0
	
	while :; do
		# Apply slot delta
		(( equip_slot += equip_slot_dir ))
		
		# Loop slot
		if (( equip_slot < 0 )); then
			equip_slot=5
		elif (( equip_slot > 5 )); then
			equip_slot=0
		fi
		equip_slot_dir=0
		
		# Bind slot code
		case $equip_slot in
		0) equip_type_code="H"; slot_code="H" ;;
		1) equip_type_code="B"; slot_code="B" ;;
		2) equip_type_code="S"; slot_code="S" ;;
		3) equip_type_code="W"; slot_code="W" ;;
		4) equip_type_code="A"; slot_code="A1" ;;
		5) equip_type_code="A"; slot_code="A2" ;;
		esac
		
		# Display
		ui_display_equipment $1 $equip_slot
		ui_new_help_line "[Move: ARROWS/jk] [Confirm: ENTER/A] [Cancel: ESCAPE/SPACE]"
		
		# Input loop
		while :; do
			input_get_key
			case $g_return in
			k|K|UP) equip_slot_dir="-1"; break ;;
			j|J|DOWN) equip_slot_dir=1; break ;;
			a|A|ENTER)
				if ui_inventory $equip_type_code $1 "Y"; then
					if item_equip_equipment $1 $slot_code $g_return; then
						if [ -n "$2" ]; then
							return 0
						fi
					fi
				fi
				break
			;;
			ESCAPE|SPACE)
				# Re-render the roster before exiting
				ui_render_roster
				return 1
			;;
			esac
		done
	done
}
