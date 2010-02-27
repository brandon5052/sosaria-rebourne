# combat.sh
#
# Combat subsystem, includes combat map handling, combat-specific input
# handlers and combat mechanics.
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

# Combat maps are located at data/maps/combat and have the following format:
# 11x11 tile symbol array for the map
# 16 enemy starting locations
#	X location
#	Y location
# 8 player starting locations
#	X location
#	Y location

# Configuration
declare -r _combat_map_width=11
declare -r _combat_map_height=11
declare -r _combat_map_path="$g_static_data_path/maps/combat"
declare -r _combat_num_mobs=16
declare -r _combat_num_chars=8
declare -r _combat_group_spawn_chance=75
declare -r _combat_highlight_color=$COLOR_BLUE
declare -r _combat_target_highlight_color=$COLOR_RED
declare -r _combat_msg_bg=$COLOR_RED
declare -r _combat_msg_fg=$COLOR_WHITE
declare -r _combat_msg_heal_bg=$COLOR_GREEN
declare -r _combat_msg_heal_fg=$COLOR_WHITE
declare -r _combat_ranged_fg=$COLOR_WHITE
declare -r _combat_ranged_bg=$COLOR_BLACK
declare -r _combat_msg_sleep=500
declare -r _combat_mob_move_sleep=250
declare -r _combat_ranged_sleep=2

# Map data
declare -a _combat_map_tile
declare -a _combat_map_starting_location_x
declare -a _combat_map_starting_location_y

# Monster static data
declare -a _combat_monster_tab
declare -a _combat_monster_follower
declare -a _combat_monster_leader

# Combat participants data
declare -a _combat_mob_name
declare -a _combat_mob_tile
declare -a _combat_mob_exp
declare -a _combat_mob_level
declare -a _combat_mob_str
declare -a _combat_mob_dex
declare -a _combat_mob_int
declare -a _combat_mob_dmg
declare -a _combat_mob_ac
declare -a _combat_mob_hp
declare -a _combat_mob_hpmax
declare -a _combat_mob_mp
declare -a _combat_mob_mpmax
declare -a _combat_mob_pos_x
declare -a _combat_mob_pos_y
declare -a _combat_mob_atype
declare -a _combat_target

# Leveling data
declare -a _combat_level_mins
declare -r _combat_level_primary_amount=12
declare -r _combat_level_secondary_amount=8
declare -r _combat_level_third_amount=4
declare -r _combat_level_primary_mod=2
declare -r _combat_level_primary_adjust=0
declare -r _combat_level_secondary_mod=4
declare -r _combat_level_secondary_adjust=1
declare -r _combat_level_third_mod=4
declare -r _combat_level_third_adjust="-1"
declare -r _combat_level_max=16
declare -r _combat_level_max_exp=819200

# Globals
declare _combat_num_party
declare _combat_total_xp_earned

# Pre-compile all map files if needed
# Load monster stats table
# Load combat groups table
function combat_init
{
	local map idx follower leader tab exp
	
	echo "Loading combat data"
	
	# Pre-compile all map files if needed
	for map in $_combat_map_path/*.cbm; do
		if [ $map -nt $map.bin ]; then
			echo "Compiling $map"
			combat_compile_map < $map > $map.bin
		fi
	done
	
	# Load monster stats table
	while read idx follower leader tab; do
		if [ "$idx" = "#" ]; then continue; fi
		_combat_monster_follower[$idx]=$follower
		_combat_monster_leader[$idx]=$leader
		_combat_monster_tab[$idx]="$tab"
	done < "$g_static_data_path/monsters.tab"
	
	# Load leveling data
	while read idx exp; do
		if [ "$idx" = "#" ]; then continue; fi
		_combat_level_mins[$idx]=$exp
	done < "$g_static_data_path/levels.tab"
}

# Load party data from the current save
function combat_load_from_save
{
	local idx name tile exp str con dex int hp hpmax mp mpmax class
	 
	# Null out all party members
	for (( idx=_combat_num_mobs; \
		idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
		_combat_mob_name[$idx]=
	done
	 
	_combat_num_party=0
	while read idx name tile exp level str dex int dmg ac hp hpmax mp mpmax \
		class; do
		if [ "$idx" = "#" ]; then continue; fi
		(( _combat_num_party++ ))
		(( idx += _combat_num_mobs ))
		_combat_mob_name[$idx]="${name//_/ }"
		_combat_mob_tile[$idx]=$tile
		_combat_mob_exp[$idx]=$exp
		_combat_mob_level[$idx]=$level
		_combat_mob_str[$idx]=$str
		_combat_mob_dex[$idx]=$dex
		_combat_mob_int[$idx]=$int
		_combat_mob_dmg[$idx]=$dmg
		_combat_mob_ac[$idx]=$ac
		_combat_mob_hp[$idx]=$hp
		_combat_mob_hpmax[$idx]=$hpmax
		_combat_mob_mp[$idx]=$mp
		_combat_mob_mpmax[$idx]=$mpmax
		_combat_mob_class[$idx]=$class
	done < "$g_save_data_path/party.tab"
}

# Load a combat group for a monster
#
# $1	Index of the monster to load a group for
function combat_load_group
{
	local idx to_spawn out_idx=0
	
	# Null out all of the monsters
	for (( idx=0; idx < _combat_num_mobs; idx++ )); do
		_combat_mob_name[$idx]=
		_combat_mob_pos_x[$idx]=-1
		_combat_mob_target[$idx]=-1
	done

	# Determine total number to spawn
	(( to_spawn = RANDOM % 16 + 1 ))
	while (( to_spawn > _combat_num_party * 2 || \
		to_spawn < _combat_num_party - 2 )); do
		(( to_spawn = RANDOM % 16 + 1 ))
	done
	
	# TODO - Leader spawn
	
	# TODO - Follower spawn
	
	# Spawn base monster
	for (( idx=0; idx < to_spawn; idx++ )); do
		combat_spawn_monster $1 $out_idx
		(( out_idx++ ))
	done
}

# Spawn a monster into the combat map
#
# $1	The id of the monster to spawn
# $2	The index this monster will occupy
function combat_spawn_monster
{
	local -a tab
	
	tab=(${_combat_monster_tab[$1]})
	# Convert underscores to spaces
	_combat_mob_name[$2]="${tab[0]//_/ }"
	_combat_mob_tile[$2]=${tab[1]}
	_combat_mob_exp[$2]=${tab[2]}
	_combat_mob_level[$2]=1
	_combat_mob_str[$2]=${tab[3]}
	_combat_mob_dex[$2]=${tab[4]}
	_combat_mob_int[$2]=${tab[5]}
	_combat_mob_dmg[$2]=${tab[6]}
	_combat_mob_ac[$2]=${tab[7]}
	_combat_mob_hp[$2]=${tab[8]}
	_combat_mob_hpmax[$2]=${tab[8]}
	_combat_mob_mp[$2]=${tab[9]}
	_combat_mob_mpmax[$2]=${tab[9]}
	_combat_mob_atype[$2]=${tab[10]}
	_combat_mob_class[$2]=X
	_combat_mob_pos_x[$2]=${_combat_map_starting_location_x[$2]}
	_combat_mob_pos_y[$2]=${_combat_map_starting_location_y[$2]}
}

# Load a combat map from disk
#
# $1	Map name
function combat_load_map
{
	local pos_x pos_y
	
	# I/O redirection block
	while :; do
		# Load tile array
		read -r -a _combat_map_tile

		# Load starting locations
		out_idx=0
		while read -r pos_x pos_y; do
			_combat_map_starting_location_x[$out_idx]=$pos_x
			_combat_map_starting_location_y[$out_idx]=$pos_y
			(( out_idx++ ))
		done
		break
	done < "$_combat_map_path/$1.cbm.bin"
}

# Compile a map from source
#
# stdin		Input file
# stdout	Output file
function combat_compile_map
{
	local buffer row_count=0 out_idx=0 symbol_dec
	local -a tile_map
	
	# Load tile array
	while read -rn 1 buffer; do
		if [ "$buffer" = "" ]; then
			(( row_count++ ))
			if (( row_count >= _combat_map_height )); then
				break
			fi
			continue
		fi
		symbol_dec=$(printf '%d' "'$buffer")
		tile_map[$out_idx]=${tiles_symbol_xref[$symbol_dec]}
		(( out_idx++ ))
	done
	
	# Echo the tile array as tile indicies on one line for easy loading
	echo -E "${tile_map[@]}"
	
	# Just re-echo all of the position lines
	while read -r buffer; do
		echo -E "$buffer"
	done
}

# Render some text over a monster
#
# $1	Monster index
# $2	Line number
# $3	Text
# $4	Background Color
# $5	Foreground Color
function combat_render_mob_text
{
	local out_string out_string_width offset_x
	
	out_string_width=${#3}
	if (( out_string_width > tiles_char_width )); then
		out_string="${2:0:$tiles_char_width}"
		out_string_width=$tiles_char_width
	fi
	(( offset_x = (tiles_char_width - out_string_width) / 2 ))
	
	vt100_goto $(( _combat_mob_pos_x[$1] * tiles_char_width + offset_x )) \
		$(( _combat_mob_pos_y[$1] * tiles_char_height + $2 ))
	vt100_bg $4
	vt100_fg $5
	vt100_high
	echo -n "$3"
	ui_park_cursor
}

# Renders a map position, checking for monsters.
#
# $1	X position
# $2	Y position
# $3	Highlight color
function combat_render_position
{
	if combat_get_mob_at $1 $2; then
		combat_render_mob $g_return $3
	else
		combat_render_tile $1 $2 $3
	fi
}

# Render a monster
#
# $1	Monster index
# $2	Highlight color
function combat_render_mob
{
	if (( _combat_mob_pos_x[$1] < 0 || _combat_mob_pos_y[$1] < 0 )); then
		return
	fi
	tiles_render $(( _combat_mob_pos_x[$1] * tiles_char_width )) \
		$(( _combat_mob_pos_y[$1] * tiles_char_height )) \
		${_combat_mob_tile[$1]} $2
}

# Render a map tile
#
# $1	X position
# $2	Y position
# $3	Highlight color
function combat_render_tile
{
	local tilemap_ofs
	
	tilemap_ofs=$(( $2 * _combat_map_width + $1 ))
	tiles_render $(( $1 * tiles_char_width )) $(( $2 * tiles_char_height )) \
		${_combat_map_tile[$tilemap_ofs]} $3
}

# Render the combat map
function combat_render_map
{
	local row col idx=0
	
	# Render out the tile map
	for (( row=0; row < _combat_map_height; row++ )); do
		for (( col=0; col < _combat_map_width; col++ )); do
			tiles_render $(( col * tiles_char_width )) \
				$(( row * tiles_char_height )) ${_combat_map_tile[$idx]} \
				$COLOR_BLACK
			(( idx++ ))
		done
	done
	
	# Now render all monsters
	for (( idx=0; idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
		if [ -n "${_combat_mob_name[$idx]}" -a \
			${_combat_mob_pos_x[$idx]} -ge 0 ]; then
			combat_render_mob $idx $COLOR_BLACK
		fi
	done
}

# Render the interface
function combat_render_help
{
	ui_new_help_line ""
	echo -n "["
	vt100_fg $COLOR_TEAL
	echo -n "M"
	vt100_fg $COLOR_WHITE
	echo -n "ove] ["
	vt100_fg $COLOR_TEAL
	echo -n "A"
	vt100_fg $COLOR_WHITE
	echo -n "ttack] ["
	vt100_fg $COLOR_TEAL
	echo -n "C"
	vt100_fg $COLOR_WHITE
	echo -n "ast Spell] ["
	vt100_fg $COLOR_TEAL
	echo -n "U"
	vt100_fg $COLOR_WHITE
	echo -n "se Item] ["
	vt100_fg $COLOR_TEAL
	echo -n "P"
	vt100_fg $COLOR_WHITE
	echo -n "ass] ["
	vt100_fg $COLOR_TEAL
	echo -n "Z"
	vt100_fg $COLOR_WHITE
	echo -n "-Stats] ["
	vt100_fg $COLOR_TEAL
	echo -n "I"
	vt100_fg $COLOR_WHITE
	echo -n "nventory] ["
	vt100_fg $COLOR_TEAL
	echo -n "E"
	vt100_fg $COLOR_WHITE
	echo -n "quip]"
}

# Puts the monster index number of the monster at a position in g_return.
#
# $1	X position
# $2	Y position
# Returns non-zero if there is no monster at that position
function combat_get_mob_at
{
	local idx
	
	g_return=-1
	for (( idx=0; idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
		if (( _combat_mob_pos_x[$idx] == $1 && \
			_combat_mob_pos_y[$idx] == $2)); then
			g_return=$idx
		fi
	done
	
	if (( g_return < 0 )); then return 1; fi
	return 0
}

# Attempts to move a monster to a given point. If the move is successfull,
# this function also handles the rendering.
#
# $1	The monster's index number
# $2	The new X position
# $3	The new Y position
# $4	If present, suppress logging and do monster move animations
# Returns non-zero if the move was not performed
function combat_move
{
	local tilemap_ofs
	
	# Move out of bounds
	if (( $2 < 0 || $2 >= _combat_map_width || \
		$3 < 0 || $3 >= _combat_map_height )); then
		log_write "${_combat_mob_name[$1]} fled the battle!"
		# Render the map tile from the old location
		tilemap_ofs=$(( _combat_mob_pos_y[$1] * _combat_map_width + \
			_combat_mob_pos_x[$1] ))
		tiles_render $(( _combat_mob_pos_x[$1] * tiles_char_width )) \
			$(( _combat_mob_pos_y[$1] * tiles_char_height )) \
			${_combat_map_tile[$tilemap_ofs]} $COLOR_BLACK
		# Move the monster off-screen
		_combat_mob_pos_x[$1]=-1
		return 0
	fi
	
	# TODO - Walkability check
	
	# Obstruction check
	if combat_get_mob_at $2 $3; then
		if [ -z "$4" ]; then
			log_write "${_combat_mob_name[$g_return]} is in your way."
		fi
		return 1
	fi
	
	# Monster selection animation
	if [ -n "$4" ]; then
		combat_render_mob $1 $_combat_highlight_color
		ui_park_cursor
		jiffy_sleep "$_combat_mob_move_sleep"
	fi
	
	# Render the monster in its new location
	tiles_render $(( $2 * tiles_char_width )) $(( $3 * tiles_char_height )) \
		${_combat_mob_tile[$1]} $COLOR_BLACK
	# Render the map tile from the old location
	combat_render_tile ${_combat_mob_pos_x[$1]} ${_combat_mob_pos_y[$1]} \
		$COLOR_BLACK
	
	_combat_mob_pos_x[$1]=$2
	_combat_mob_pos_y[$1]=$3
	
	# TODO - Tile proc
	
	return 0
}

# Input handler for moving
#
# $1	The monster index of the player
# $2	If this is present, skip the first get_key call
# Returns non-zero on cancel
function combat_player_move_handler
{
	if [ -z "$2" ]; then
		# Help string
		ui_new_help_line "[Move: ARROWS/hjkl] [Cancel: ESCAPE/SPACE]"
		input_get_key
	fi
	
	while :; do
		case "$g_return" in
		k|K|UP) combat_move $1 ${_combat_mob_pos_x[$1]} \
			$(( _combat_mob_pos_y[$1] - 1 )) ;;
		j|J|DOWN) combat_move $1 ${_combat_mob_pos_x[$1]} \
			$(( _combat_mob_pos_y[$1] + 1 )) ;;
		h|H|LEFT) combat_move $1 $(( _combat_mob_pos_x[$1] - 1 )) \
			${_combat_mob_pos_y[$1]} ;;
		l|L|RIGHT) combat_move $1 $(( _combat_mob_pos_x[$1] + 1 )) \
			${_combat_mob_pos_y[$1]} ;;
		ESCAPE|SPACE) return 1 ;;
		*)
			input_get_key
			continue
		;;
		esac
		return $?
	done
}

# Return the "square distance" between two monsters. The value is in g_return
#
# $1	The first monster index
# $2	The second monster index, or arbitrary x position
# $3	Arbitrary y position
function combat_square_distance
{
	local distance_x distance_y rx ry
	
	if [ -z "$3" ]; then
		rx=${_combat_mob_pos_x[$2]}
		ry=${_combat_mob_pos_y[$2]}
	else
		rx=$2
		ry=$3
	fi
	
	(( distance_x = _combat_mob_pos_x[$1] - rx ))
	if (( distance_x < 0 )); then
		(( distance_x *= -1 ))
	fi
	(( distance_y = _combat_mob_pos_y[$1] - ry ))
	if (( distance_y < 0 )); then
		(( distance_y *= -1 ))
	fi
	if (( distance_x > distance_y )); then
		g_return=$distance_x
	else
		g_return=$distance_y
	fi
}

# Input handler for selecting a target. The targeted monster index will be
# placed in g_return.
#
# $1	The monster index of the player
# $2	Target type, may be any of "ranged" or "close"
# $3	Valid target set, may be any of "monster", "player" or "any"
# Returns non-zero if the player cancels
function combat_player_target_handler
{
	local cur_x cur_y next_x next_y last_x last_y last_target valid_target=0
	local idx

	# Help string
	ui_new_help_line "[Move: ARROWS/hjkl] [Confirm: ENTER/A] [Cancel: ESCAPE/SPACE]"
	
	# Last target handling
	last_target=${_combat_mob_target[$1]}
	if (( last_target < 0 )); then
		last_target=$1
	elif (( _combat_mob_pos_x[$last_target] < 0 )); then
		last_target=$1
	fi
	# If the last target is out of range, default to the player
	if [ "$2" = "close" ]; then
		combat_square_distance $1 $last_target
		if (( g_return > 1 )); then
			last_target=$1
		fi
	fi
	# If we have targeted a player for a "monster" target type, find a monster
	if [ "$3" = "monster" ]; then
		if (( last_target >= _combat_num_mobs )); then
			for (( idx=0; idx < _combat_num_mobs; idx++ )); do
				# Ignore invalid targets
				if (( _combat_mob_pos_x[$idx] < 0 )); then
					continue
				fi
				if [ "$2" = "close" ]; then
					combat_square_distance $1 $idx
					if (( g_return <= 1 )); then
						last_target=$idx
						break
					fi
				else
					last_target=$idx
					break
				fi
			done
		fi
	fi
	
	# Initial positioning
	cur_x=${_combat_mob_pos_x[$last_target]}
	cur_y=${_combat_mob_pos_y[$last_target]}
	next_x=$cur_x
	next_y=$cur_y
	last_x=$cur_x
	last_y=$cur_y
	combat_render_position $cur_x $cur_y $_combat_target_highlight_color
	
	# Targeting loop
	while :; do
		# Out of bounds, ignore
		if (( next_x < 0 || next_x >= _combat_map_width || \
			next_y < 0 || next_y >= _combat_map_height )); then
			next_x=$cur_x
			next_y=$cur_y
		# Close target type
		elif [ "$2" = "close" ]; then
			combat_square_distance $1 $next_x $next_y
			# Target is not close, ignore
			if (( g_return > 1 )); then
				next_x=$cur_x
				next_y=$cur_y
			fi
		fi
		last_x=$cur_x
		last_y=$cur_y
		cur_x=$next_x
		cur_y=$next_y
		
		# Rendering
		if (( cur_x != last_x || cur_y != last_y )); then
			combat_render_position $cur_x $cur_y \
				$_combat_target_highlight_color
			combat_render_position $last_x $last_y $COLOR_BLACK
		fi
		
		# Inform line
		if combat_get_mob_at $cur_x $cur_y; then
			ui_inform "${_combat_mob_name[$g_return]}"
		else
			ui_inform ""
		fi
		
		# Input
		while :; do
			input_get_key
			case "$g_return" in
			k|K|UP) (( next_y-- )); break ;;
			j|J|DOWN) (( next_y++ )); break ;;
			h|H|LEFT) (( next_x-- )); break ;;
			l|L|RIGHT)(( next_x++ )); break ;;
			ESCAPE|SPACE)
				combat_render_position $cur_x $cur_y $COLOR_BLACK
				ui_inform ""
				return 1
			;;
			ENTER|a|A)
				# If we are here, cur_x cur_y is a valid target location.
				if combat_get_mob_at $cur_x $cur_y; then
					# If this is true, the mob's index is already in g_return
					if [ "$3" = "monster" ]; then
						if (( g_return < _combat_num_mobs )); then
							valid_target=1
						fi
					elif [ "$3" = "player" ]; then
						if (( g_return >= _combat_num_mobs )); then
							valid_target=1
						fi
					# "any" case
					else
						valid_target=1
					fi
				fi
				# If we get here without returning we have an invalid target
			;;
			esac
			
			# If we have a valid target, handle it
			if (( valid_target == 1 )); then
				combat_render_mob $g_return
				_combat_mob_target[$1]=$g_return
				ui_inform ""
				return 0
			fi
		done
	done
}

# Have a monster take damage, and report on death or status. If the monster
# dies we will take care of moving it out of bounds and re-rendering the
# map tile.
#
# $1	The monster index of the monster being damaged
# $2	The amount of damage (negative for healing)
function combat_take_damage
{
	local status_string 
	
	# Damage animation
	if (( $2 >= 0 )); then
		combat_render_mob_text $1 1 "$2" $_combat_msg_bg $_combat_msg_fg
	else
		combat_render_mob_text $1 1 "$(( $2 * -1 ))" $_combat_msg_heal_bg \
			$_combat_msg_heal_fg
	fi
	
	(( _combat_mob_hp[$1] -= $2 ))
	
	# Over maximum HP
	if (( _combat_mob_hp[$1] > _combat_mob_hpmax[$1] )); then
		_combat_mob_hp[$1]=${_combat_mob_hpmax[$1]}
	fi
	
	# Mob is dead
	if (( _combat_mob_hp[$1] < 0 )); then
		# Death message animation
		log_write "${_combat_mob_name[$1]} died!"
		combat_render_mob_text $1 2 "Dead!" $_combat_msg_bg $_combat_msg_fg
		jiffy_sleep $_combat_msg_sleep
		
		# Clear the mob and move it offscreen
		combat_render_tile ${_combat_mob_pos_x[$1]} ${_combat_mob_pos_y[$1]} \
			$COLOR_BLACK
		(( _combat_mob_pos_x[$1] = -1 ))

		# If this was not a player, add this monster's EXP to the total
		if (( $1 < _combat_num_mobs )); then
			(( _combat_total_xp_earned += _combat_mob_exp[$1] ))
		fi
	# Mob is not dead
	else
		# Finalize the damage animation
		jiffy_sleep $_combat_msg_sleep
		combat_render_mob $1 $COLOR_BLACK
	fi
}

# Do a ranged attack animation. If the points indicated by $1,$2 $3,$4 are not
# far enough away to need a ranged animation, do not do one.
#
# $1	X position of source
# $2	Y position of source
# $3	X position of destination
# $4	Y position of destination
# $5	Character to use for the projectile
# $6	Background color for the projectile
# $7	Foreground color for the projectile
function combat_ranged_animation
{
	local Ax Ay Bx By travel_x travel_y abs_tx abs_ty steps step_x step_y idx
	local cur_x cur_y stepped_x stepped_y
	local dx dy

	# Distance check
	(( dx = $3 - $1 ))
	(( dy = $4 - $2 ))
	if (( dx < 0 )); then (( dx *= -1 )); fi
	if (( dy < 0 )); then (( dy *= -1 )); fi
	if (( dx <= 1 && dy <= 1 )); then return 0; fi
	
	# Go from the center of the source tile to the center of the destination
	(( Ax = $1 * tiles_char_width + ( tiles_char_width / 2 ) ))
	(( Ay = $2 * tiles_char_height + ( tiles_char_height / 2 ) ))
	(( Bx = $3 * tiles_char_width + ( tiles_char_width / 2 ) ))
	(( By = $4 * tiles_char_height + ( tiles_char_height / 2 ) ))
	
	# Travel and step calculations
	(( travel_x = Bx - Ax ))
	(( travel_y = By - Ay ))
	if (( travel_x < 0 )); then
		(( abs_tx = travel_x * -1 ))
	else
		abs_tx=$travel_x
	fi
	if (( travel_y < 0 )); then
		(( abs_ty = travel_y * -1 ))
	else
		abs_ty=$travel_y
	fi
	if (( abs_tx > abs_ty )); then
		steps=$abs_tx
	else
		steps=$abs_ty
	fi
	(( step_x = ( travel_x * 1000 ) / steps ))
	(( step_y = ( travel_y * 1000 ) / steps ))
	
	# Stepping
	cur_x=$Ax
	cur_y=$Ay
	(( stepped_x = cur_x * 1000 ))
	(( stepped_y = cur_y * 1000 ))
	for (( idx=0; idx < steps; idx++ )); do
		(( stepped_x += step_x ))
		(( stepped_y += step_y ))
		(( cur_x = stepped_x / 1000 ))
		(( cur_y = stepped_y / 1000 ))
		vt100_goto $cur_x $cur_y
		vt100_fg $7
		vt100_bg $6
		vt100_high
		echo -n "$5"
		ui_park_cursor
		jiffy_sleep $_combat_ranged_sleep
		combat_render_position $(( cur_x / tiles_char_width )) \
			$(( cur_y / tiles_char_height ))
	done
	
	return 0
}

# Perform an attack.
#
# $1	The monster index of the attacking monster
# $2	The monster index of the defending monster
function combat_attack
{
	local effective_ac to_hit hit_roll crit=0 damage_mod effective_damage
	local range_x range_y damaged_mob
	
	# If the attacking monster is not a player, highlight that monster
	if (( $1 < _combat_num_mobs )); then
		combat_render_mob $1 $_combat_highlight_color
		jiffy_sleep $_combat_mob_move_sleep
	fi
	
	# Combat calculations
	effective_ac=$(( _combat_mob_ac[$2] + ( _combat_mob_dex[$2] / 2 ) ))
	to_hit=$(( effective_ac - ( _combat_mob_dex[$1] / 2 ) ))
	hit_roll=$(( ( RANDOM % 20 ) + 1 ))

	# Ranged attack 
	combat_square_distance $1 $2
	if (( g_return > 1 )); then
		# If we missed, choose an adjacent tile to hit
		if (( hit_roll == 1 || hit_roll < to_hit )); then
			range_x="-1"
			range_y="-1"
			while (( range_x < 0 || range_x >= _combat_map_width || \
				range_y < 0 || range_y >= _combat_map_width || \
				( \
					range_x == _combat_mob_pos_x[$2] && \
					range_y == _combat_mob_pos_y[$2] \
				) )); do
				(( range_x = _combat_mob_pos_x[$2] + (RANDOM % 3 - 1) ))
				(( range_y = _combat_mob_pos_y[$2] + (RANDOM % 3 - 1) ))
			done
			log_write "Miss hit $range_x $range_y"
			# If there is a monster where our missed shot landed, damage them.
			if combat_get_mob_at $range_x $range_y; then
				damaged_mob=$g_return
			else
				damaged_mob="-1"
			fi
		else
			range_x=${_combat_mob_pos_x[$2]}
			range_y=${_combat_mob_pos_y[$2]}
			damaged_mob=$2
		fi
		
		# Animation
		combat_ranged_animation ${_combat_mob_pos_x[$1]} \
			${_combat_mob_pos_y[$1]} $range_x $range_y "*" $COLOR_BLACK \
			$COLOR_WHITE
		
		# Miss display on target
		if (( hit_roll == 1 || hit_roll < to_hit )); then
			log_write "${_combat_mob_name[$1]} missed."
			combat_render_mob_text $2 1 "Miss" $_combat_msg_bg \
				$_combat_msg_fg
		# Crit display on target
		elif (( hit_roll == 20 )); then
			combat_render_mob_text $2 0 "Crit!" $_combat_msg_bg \
				$_combat_msg_fg
			crit=1
		fi
		
		# Crit on damaged mob display
		if (( hit_roll == 1 && damaged_mob >= 0 )); then
			combat_render_mob_text $damaged_mob 0 "Crit!" $_combat_msg_bg \
				$_combat_msg_fg
			crit=1
		fi
		
		# If we missed and didn't hit anyone else, delay and return
		if (( damaged_mob < 0 )); then
			jiffy_sleep $_combat_msg_sleep
			combat_render_mob $2 $COLOR_BLACK
			combat_render_mob $1 $COLOR_BLACK
			return
		fi			
	# Close attack
	else
		damaged_mob=$2
		# Cirt / Fail / Miss handling
		if (( hit_roll == 20 )); then
			combat_render_mob_text $2 0 "Crit!" $_combat_msg_bg \
				$_combat_msg_fg
			crit=1
		elif (( hit_roll == 1 )); then
			log_write "${_combat_mob_name[$1]} fails missurably."
			combat_render_mob_text $2 1 "Fail!" $_combat_msg_bg \
				$_combat_msg_fg
			jiffy_sleep $_combat_msg_sleep
			combat_render_mob $2 $COLOR_BLACK
			combat_render_mob $1 $COLOR_BLACK
			return
		elif (( hit_roll < to_hit )); then
			log_write "${_combat_mob_name[$1]} missed."
			combat_render_mob_text $2 1 "Miss" $_combat_msg_bg \
				$_combat_msg_fg
			jiffy_sleep $_combat_msg_sleep
			combat_render_mob $2 $COLOR_BLACK
			combat_render_mob $1 $COLOR_BLACK
			return
		fi
	fi
	
	# If we get here we need to do damage
	damage_mod=$(( RANDOM % ( _combat_mob_dmg[$1] / 4 + 1 ) ))
	(( effective_damage = _combat_mob_dmg[$1] - damage_mod ))
	(( effective_damage += _combat_mob_str[$1] / 2 ))
	(( effective_damage -= _combat_mob_str[$damaged_mob] / 4 ))
	if (( effective_damage < 1 )); then
		effective_damage=1
	fi
	
	log_write "${_combat_mob_name[$1]} hit ${_combat_mob_name[$damaged_mob]} causing $effective_damage damage."
	combat_take_damage $damaged_mob $effective_damage
	combat_render_mob $1 $COLOR_BLACK
	if (( damaged_mob != $2 )); then
		combat_render_mob $2 $COLOR_BLACK
	fi
}

# Input handler for attacking
#
# $1	The monster index of the player
function combat_player_attack_handler
{
	local target_type weapon_idx weapon_type
	
	# Determine target type
	weapon_idx=${_item_mob_weapon[$1]}
	weapon_type=${_item_type[$weapon_idx]}
	if [ "$weapon_type" = "R" -o "$weapon_type" = "r" ]; then
		target_type="ranged"
	else
		target_type="close"
	fi
	
	# Get the target
	combat_player_target_handler $1 $target_type "monster"
	if [ $? -ne 0 ]; then return 1; fi
	
	# Do the attack
	combat_attack $1 $g_return
}

# Input handler for using an item
#
# $1	The monster index of the player
function combat_player_use_item
{
	local item_idx target_idx

	# If we cancel the item selection, cancel
	if ! ui_inventory "C" $1; then
		return 1
	fi
	item_idx=$g_return

	# Get a target
	item_get_target_type $item_idx
	case $g_return in
	P)
		# If we cancel target selection, cancel
		if ! ui_select_party_member; then
			return 1
		fi
		target_idx=$g_return
	;;
	M)
		# If we cancel target selection, cancel
		if ! combat_player_target_handler $1 "ranged" "monster"; then
			return 1
		fi
		target_idx=$g_return
	;;
	*) return 1 ;;
	esac

	# Ranged animation
	combat_ranged_animation ${_combat_mob_pos_x[$1]} ${_combat_mob_pos_y[$1]} \
		${_combat_mob_pos_x[$target_idx]} ${_combat_mob_pos_y[$target_idx]} \
		"*" $COLOR_RED $COLOR_BLACK

	# Use the item
	item_use_item $item_idx $1 $target_idx
	
	return 0
}

# Perform a player round
#
# $1	The monster index of the player
function combat_do_player_round
{
	while :; do
		# Highlight the player character
		combat_render_mob $1 $_combat_highlight_color
		
		# Handle input
		combat_render_help
		input_get_key
		case "$g_return" in
		# Quick-move keys
		k|K|UP) combat_player_move_handler $1 "TRUE" ;;
		j|J|DOWN) combat_player_move_handler $1 "TRUE" ;;
		h|H|LEFT) combat_player_move_handler $1 "TRUE" ;;
		l|L|RIGHT) combat_player_move_handler $1 "TRUE" ;;
		# Move
		m|M) combat_player_move_handler $1 ;;
		# Attack
		a|A) combat_player_attack_handler $1 ;;
		# Use Item
		u|U) combat_player_use_item $1 ;;
		# Pass
		p|P|SPACE) true ;;
		# Z-Stats
		z|Z)
			ui_zstats
			# Prevent this from costing us a round
			false
		;;
		# Inventory
		i|I)
			ui_inventory "X" 17
			# Prevent this from costing us a round
			false
		;;
		# Equipment change
		e|E)
			ui_equip_change $1 "Y"
		;;
		d|D) debug_proc; false ;;
		*) false ;;
		esac
		
		# If the input handler was successful, break. Otherwise continue
		if [ $? -eq 0 ]; then break; fi
	done
	# Un-highlight the player character
	combat_render_mob $1 $COLOR_BLACK
	
	ui_render_roster
}

# Find the closest target to a monster. Place that monster's index in g_return.
# This function only looks at player monsters as targets.
#
# $1	The monster index of the center monster
# Returns non-zero if the closest monster is not "close".
function combat_find_closest_target
{
	local target=-1 target_square=100 idx
	
	for (( idx=_combat_num_mobs; idx < _combat_num_mobs + _combat_num_chars; \
		idx++ )); do
		# Skip invalid targets
		if (( _combat_mob_pos_x[$idx] < 0 )); then
			continue
		fi
		combat_square_distance $1 $idx
		if (( g_return < target_square )); then
			target_square=$g_return
			target=$idx
		elif (( g_return == target_square && (RANDOM % 2) == 1 )); then
			target_square=$g_return
			target=$idx
		fi
	done
	
	g_return=$target
	# Return true if the target is "close"
	if (( target_square <= 1 )); then
		return 0
	fi
	return 1
}

# Move one monster towards another
#
# $1	The monster index of the mover
# $2	The monster index of the target
# Return non-zero if the move failed
function combat_move_towards
{
	local mod_x mod_y
	
	# Figure out which way we need to be moving
	if (( _combat_mob_pos_x[$1] < _combat_mob_pos_x[$2] )); then
		mod_x=1
	elif (( _combat_mob_pos_x[$1] > _combat_mob_pos_x[$2] )); then
		mod_x="-1"
	else
		mod_x=0
	fi
	if (( _combat_mob_pos_y[$1] < _combat_mob_pos_y[$2] )); then
		mod_y=1
	elif (( _combat_mob_pos_y[$1] > _combat_mob_pos_y[$2] )); then
		mod_y="-1"
	else
		mod_y=0
	fi
	
	# Straight line cases
	if (( mod_x == 0 )); then
		# If we can't move in a straight line, sidestep
		if ! combat_move $1 $(( _combat_mob_pos_x[$1] )) \
			$(( _combat_mob_pos_y[$1] + mod_y )) "Y"; then
			mod_x=1
			if (( RANDOM % 2 == 1 )); then
				(( mod_x * -1 ))
			fi
			if ! combat_move $1 $(( _combat_mob_pos_x[$1] + mod_x )) \
				$(( _combat_mob_pos_y[$1] )) "Y"; then
				(( mod_x * -1 ))
				combat_move $1 $(( _combat_mob_pos_x[$1] + mod_x )) \
				$(( _combat_mob_pos_y[$1] )) "Y";
			fi
		fi
	elif (( mod_y == 0 )); then
		# If we can't move in a straight line, sidestep
		if ! combat_move $1 $(( _combat_mob_pos_x[$1] + mod_x)) \
			$(( _combat_mob_pos_y[$1] )) "Y"; then
			mod_y=1
			if (( RANDOM % 2 == 1 )); then
				(( mod_y * -1 ))
			fi
			if ! combat_move $1 $(( _combat_mob_pos_x[$1] )) \
				$(( _combat_mob_pos_y[$1] + mod_y )) "Y"; then
				(( mod_y * -1 ))
				combat_move $1 $(( _combat_mob_pos_x[$1] )) \
				$(( _combat_mob_pos_y[$1] + mod_y )) "Y";
			fi
		fi
	# Non-straight case
	else
		if (( RANDOM % 2 == 1 )); then
			if ! combat_move $1 $(( _combat_mob_pos_x[$1] + mod_x)) \
				$(( _combat_mob_pos_y[$1] )) "Y"; then
				combat_move $1 $(( _combat_mob_pos_x[$1] )) \
				$(( _combat_mob_pos_y[$1] + mod_y )) "Y"
			fi
		else
			if ! combat_move $1 $(( _combat_mob_pos_x[$1] )) \
				$(( _combat_mob_pos_y[$1] + mod_y )) "Y"; then
				combat_move $1 $(( _combat_mob_pos_x[$1] + mod_x )) \
				$(( _combat_mob_pos_y[$1] )) "Y"
			fi
		fi
	fi
}

# Perform an AI monster round
#
# $1	The monster index of the monster
function combat_do_monster_round
{
	local target atype
	
	# Current target validation
	target=${_combat_mob_target[$1]}
	atype=${_combat_mob_atype[$1]}
	if (( target >= 0 )); then
		if [ -z "${_combat_mob_name[$target]}" -o \
			${_combat_mob_pos_x[$target]} -lt 0 ]; then
			target="-1"
		fi
	fi

	# If we have a current target
	if (( target >= 0 )); then
		# Close attack type
		if [ "$atype" = "C" ]; then
			# If the target is still close, attack
			combat_square_distance $1 $target
			if (( g_return <= 1 )); then
				combat_attack $1 $target
			# Otherwise we either start attacking another close target or
			# follow our previous target. 50% chance.
			else
				if combat_find_closest_target $1; then
					if (( RANDOM % 2 == 1 )); then
						_combat_mob_target[$1]=$g_return
						combat_attack $1 $g_return
					else
						combat_move_towards $1 $target
					fi
				else
					combat_move_towards $1 $target
				fi
			fi
		# TODO - Close / Ranged attack type
		elif [ "$atype" = "r" ]; then
			# If target is close
				# Attack
			# Else if find_closest_target && rand(3)
				# Attack
			# Else
				# Follow last target
			:
		# TODO - Ranged attack type
		else
			# If rand(5)
				# find_closest_target
				# Attack
			# Else
				# Attack target
			:
		fi
	# Looking for a new target
	else
		# Close attack type
		if [ "$atype" = "C" ]; then
			# If there is a target in range, attack it
			if combat_find_closest_target $1; then
				_combat_mob_target[$1]=$g_return
				combat_attack $1 $g_return
			# Otherwise start following the closest target
			else
				_combat_mob_target[$1]=$g_return
				combat_move_towards $1 $g_return
			fi
		# TODO - Close / Ranged attack type
		elif [ "$atype" = "r" ]; then
			# If find_close_target
				# attack
			# Else
				# find_closest_target
				# If distance < 2
					# Follow
				# Else
					# Attack
			:
		# TODO - Ranged attack type
		else
			# find_closest_target
			# Attack
			:
		fi		
	fi
	
	ui_render_roster
}

# Called when a monster levels up. This MUST be called once per level up.
#
# $1	The monster's index number
# $2	The monster's new level
function combat_on_level_up
{
	log_write "${_combat_mob_name[$1]} gained a level!"
	
	# Should increase primary attribute
	if (( ($2 + _combat_level_primary_adjust) % \
		_combat_level_primary_mod == 0 )); then
		if [ "${_combat_mob_class[$1]}" = "F" -o \
			"${_combat_mob_class[$1]}" = "P" ]; then
			(( _combat_mob_str[$1]++ ))
		elif [ "${_combat_mob_class[$1]}" = "R" -o \
			"${_combat_mob_class[$1]}" = "T" ]; then
			(( _combat_mob_dex[$1]++ ))
		elif [ "${_combat_mob_class[$1]}" = "S" -o \
			"${_combat_mob_class[$1]}" = "M" ]; then
			(( _combat_mob_int[$1]++ ))
		fi
	# Should increase secondary attribute
	elif (( ($2 + _combat_level_secondary_adjust) % \
		_combat_level_secondary_mod == 0 )); then
		if [ "${_combat_mob_class[$1]}" = "R" -o \
			"${_combat_mob_class[$1]}" = "M" ]; then
			(( _combat_mob_str[$1]++ ))
		elif [ "${_combat_mob_class[$1]}" = "F" -o \
			"${_combat_mob_class[$1]}" = "S" ]; then
			(( _combat_mob_dex[$1]++ ))
		elif [ "${_combat_mob_class[$1]}" = "P" -o \
			"${_combat_mob_class[$1]}" = "T" ]; then
			(( _combat_mob_int[$1]++ ))
		fi
	# Should increase third attribute
	elif (( ($2 + _combat_level_third_adjust) % \
		_combat_level_third_mod == 0 )); then
		if [ "${_combat_mob_class[$1]}" = "S" -o \
			"${_combat_mob_class[$1]}" = "T" ]; then
			(( _combat_mob_str[$1]++ ))
		elif [ "${_combat_mob_class[$1]}" = "P" -o \
			"${_combat_mob_class[$1]}" = "M" ]; then
			(( _combat_mob_dex[$1]++ ))
		elif [ "${_combat_mob_class[$1]}" = "F" -o \
			"${_combat_mob_class[$1]}" = "R" ]; then
			(( _combat_mob_int[$1]++ ))
		fi
	fi
}


# Called to add experiance to a monster
#
# $1	The monster's index number
# $2	The amount of experiance to award
function combat_award_experiance
{
	local next_level
	(( _combat_mob_exp[$1] += $2 ))
	if (( _combat_mob_exp[$1] > _combat_level_max_exp )); then
		_combat_mob_exp[$1]=$_combat_level_max_exp
	fi
	
	# Level check
	while :; do
		if ((  _combat_mob_level[$1] < _combat_level_max )); then
			(( next_level = _combat_mob_level[$1] + 1 ))
			if (( _combat_mob_exp[$1] >= \
				_combat_level_mins[$next_level] )); then
				(( _combat_mob_level[$1]++ ))
				combat_on_level_up $1 ${_combat_mob_level[$1]}
			else
				break
			fi
		else
			break
		fi
	done
}

# Called when a battle is won
function combat_victory_handler
{
	local idx award_count=0 award_amount
	
	log_write "Victory!"
	
	# Award experiance to all characters still in-bounds
	for (( idx=_combat_num_mobs; \
		idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
		if (( _combat_mob_pos_x[$idx] >= 0 )); then
			(( award_count++ ))
		fi
	done
	(( award_amount = _combat_total_xp_earned / award_count ));
	# If we have some fractional XP left, round up
	if (( _combat_total_xp_earned % award_count > 0 )); then
		(( award_amount++ ))
	fi
	
	# Do the award
	log_write "Remaining party members gained $award_amount experiance."
	for (( idx=_combat_num_mobs; \
		idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
		if (( _combat_mob_pos_x[$idx] >= 0 )); then
			combat_award_experiance $idx $award_amount
		fi
	done	
}

# Combat mode handler. Places a status code in g_return before returning.
#
# Status Codes:
#	D	The party has been defeated with all members dead
#	R	The party has ran away
#	V	The party has achieved victory
#
# $1	The combat map to load
# $2	The monster type to spawn
function combat_mode
{
	local idx mob_idx victory=0 defeat=0
	
	_combat_total_xp_earned=0
	
	combat_load_map $1
	combat_load_group $2
	
	# Position party members
	for (( idx=_combat_num_mobs; \
		idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
		if [ -z "${_combat_mob_name[$idx]}" ]; then
			_combat_mob_pos_x[$idx]=-1
			_combat_mob_pos_y[$idx]=-1
		else
			_combat_mob_pos_x[$idx]=${_combat_map_starting_location_x[$idx]}
			_combat_mob_pos_y[$idx]=${_combat_map_starting_location_y[$idx]}
		fi
		_combat_mob_target[$idx]=-1
	done
	
	# Initial rendering
	combat_render_map
	ui_render_roster
	combat_render_help
	
	# Main input loop
	while :; do
		mob_idx=_combat_num_mobs
		while :; do
			# Wrapping    
			if (( mob_idx >= _combat_num_mobs + _combat_num_chars )); then
				mob_idx=0
			fi
			
			# Player turns
			if (( mob_idx >= _combat_num_mobs )); then
				if [ -n "${_combat_mob_name[$mob_idx]}" -a \
					${_combat_mob_pos_x[$mob_idx]} -ge 0 ]; then
					combat_do_player_round $mob_idx
				fi
			# Monster turns
			else
				if (( mob_idx == _combat_num_mobs )); then break; fi
				if [ -n "${_combat_mob_name[$mob_idx]}" -a \
					${_combat_mob_pos_x[$mob_idx]} -ge 0 ]; then
					combat_do_monster_round $mob_idx
				fi
			fi
			(( mob_idx++ ))
		
			# Defeat check. If there are any party member still in bounds we
			# have not yet been defeated.
			defeat=1
			for (( idx=_combat_num_mobs; \
				idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
				if (( _combat_mob_pos_x[$idx] >= 0 )); then
					defeat=0
				fi
			done
			if (( defeat == 1 )); then
				g_return="D"
				# Run check. If any party member is still alive, we ran.
				for (( idx=_combat_num_mobs; \
					idx < _combat_num_mobs + _combat_num_chars; idx++ )); do
					if [ -n "${_combat_mob_name[$idx]}" ]; then
						if [ ${_combat_mob_hp[$idx]} -gt 0 ]; then
							echo "$idx HP=${_combat_mob_hp[$idx]}"
							g_return="R"
						fi
					fi
				done
				if [ $g_return = "R" ]; then
					log_write "The party escaped the battle!"
				else
					log_write "The party has been defeated."
				fi
				return 0
			fi

			# Victory check
			victory=1
			for (( idx=0; idx < _combat_num_mobs; idx++ )); do
				# If any monster is still in bounds we have not won.
				if (( _combat_mob_pos_x[$idx] >= 0 )); then
					victory=0
				fi
			done
			if (( victory == 1 )); then
				combat_victory_handler
				g_return="V"
				return 0
			fi
		done
	done
}
