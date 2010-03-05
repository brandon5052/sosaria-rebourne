# animation.sh
#
# Animation subsystem.
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
declare -r _animation_step_sleep=10
declare -r _animation_max=32

# Private data
declare -a _animation_pos_x
declare -a _animation_pos_y
declare -a _animation_source_tile
declare -a _animation_timer
declare -a _animation_proc
declare -a _animation_param1
declare -a _animation_param2
declare -a _animation_param3
declare _animation_next_idx

# Reset the animation queue
function animation_reset_queue
{
	local idx
	
	_animation_next_idx=0
	for (( idx=0; idx < _animation_max; idx++ )); do
		_animation_proc[$idx]=
	done
}

# Add an animation to the list
#
# $1	X position
# $2	Y position
# $3	Source tile index
# $4	Animation proceedure name
# $5	Parameter 1
# $6	Parameter 2
# $7	Parameter 3
function animation_add_to_queue
{
	_animation_pos_x[$_animation_next_idx]=$(( $1 * tiles_char_width ))
	_animation_pos_y[$_animation_next_idx]=$(( $2 * tiles_char_height ))
	_animation_source_tile[$_animation_next_idx]=$3
	_animation_proc[$_animation_next_idx]=$4
	_animation_param1[$_animation_next_idx]="$5"
	_animation_param2[$_animation_next_idx]="$6"
	_animation_param3[$_animation_next_idx]="$7"
	_animation_timer[$_animation_next_idx]=0
	(( _animation_next_idx++ ))
}

# Run all animations in the queue until all animations are done
function animation_run_all_until_done
{
	local idx all_done
	
	all_done=0
	while (( all_done == 0 )); do
		all_done=1
		for (( idx=0; idx < _animation_max; idx++ )); do
			# If this animation has a proc set, run it
			if [ -n "${_animation_proc[$idx]}" ]; then
				# If the animation proc returns true it is still running
				if ${_animation_proc[$idx]} $idx; then
					(( _animation_timer[$idx]++ ))
					all_done=0
				# Otherwise unset the proc string and refresh the tile
				else
					_animation_proc[$idx]=
					tiles_render ${_animation_pos_x[$idx]} \
						${_animation_pos_y[$idx]} \
						${_animation_source_tile[$idx]} $COLOR_BLACK
				fi
			fi
		done
		ui_park_cursor
		jiffy_sleep $_animation_step_sleep
	done
}

# Play a single animation.
#
# $1	X position
# $2	Y position
# $3	Source tile index
# $4	Animation proceedure name
# $5	Parameter 1
# $6	Parameter 2
# $7	Parameter 3
function animation_single
{
	animation_reset_queue
	animation_add_to_queue "$1" "$2" "$3" "$4" "$5" "$6" "$7"
	animation_run_all_until_done
}

# Random characters animation
#
# $1		Animation index number
# Param1	Background color
# Param2	Foreground color
# Param3	Duration in steps
declare _animation_proc_random_chars_pad="\!|~@#$%^&*()_+[]\;',./{}|:\"<>?\`-="
function animation_proc_random_chars
{
	local px py char char_n
	
	if (( _animation_timer[$1] >= _animation_param3[$1] )); then
		return 1;
	fi
	(( px = RANDOM % tiles_char_width ))
	(( py = RANDOM % tiles_char_height ))
	(( char_n = RANDOM % ${#_animation_proc_random_chars_pad} ))
	char=${_animation_proc_random_chars_pad:$char_n:1}
	vt100_goto $(( _animation_pos_x[$1] + px )) \
		$(( _animation_pos_y[$1] + py ))
	vt100_bg ${_animation_param1[$1]}
	vt100_fg ${_animation_param2[$1]}
	vt100_high
	echo -n "$char"
	
	return 0
}

# Left-to-right background color sweep
#
# $1		Animation index number
# Param1	Background color of the sweep
# Param2	INTERNAL USE ONLY, SET TO 0
# Param3	Duration in sweeps
function animation_proc_bg_sweep
{
	local cy dx1 dx2
	
	# Only proc every 2 steps
	if (( _animation_timer[$1] % 2 != 0 )); then
		return 0
	fi
	
	# Sweep has ended
	if (( _animation_param2[$1] >= tiles_char_width )); then
		# Animation has ended
		if (( _animation_param3[$1] <= 0 )); then
			return 1
		fi
		# Otherwise start a new sweep
		_animation_param2[$1]=0
		(( _animation_param3[$1]-- ))
	fi
	
	# Re-render the tile, then render the bar
	tiles_render ${_animation_pos_x[$1]} ${_animation_pos_y[$1]} \
		${_animation_source_tile[$1]} $COLOR_BLACK
	vt100_high
	vt100_bg ${_animation_param1[$1]}
	(( dx1 = _animation_pos_x[$1] + _animation_param2[$1] ))
	if (( _animation_param2[$1] == 0 )); then
		(( dx2 = dx1 + tiles_char_width - 1 ))
	else
		(( dx2 = dx1 - 1 ))
	fi
	for (( cy=0; cy < tiles_char_height; cy++ )); do
		vt100_goto $dx1 $(( _animation_pos_y[$1] + cy ))
		echo -n " "
		vt100_goto $dx2 $(( _animation_pos_y[$1] + cy ))
		echo -n " "
	done
	
	# Increment the sweep offset
	(( _animation_param2[$1]++ ))
	
	return 0
}
