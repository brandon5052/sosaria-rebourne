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
declare -r _animation_step_sleep=20

# Private data
declare -a _animation_pos_x
declare -a _animation_pos_y
declare -a _animation_source_tile
declare -a _animation_timer
declare -a _animation_proc
declare -a _animation_param1
declare -a _animation_param2
declare -a _animation_param3

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
	_animation_pos_x[0]=$(( $1 * tiles_char_width ))
	_animation_pos_y[0]=$(( $2 * tiles_char_height ))
	_animation_source_tile[0]=$3
	_animation_proc[0]=$4
	_animation_param1[0]="$5"
	_animation_param2[0]="$6"
	_animation_param3[0]="$7"
	_animation_timer[0]=0
	
	while ${_animation_proc[0]} 0; do
		jiffy_sleep $_animation_step_sleep
		(( _animation_timer[0]++ ))
	done
	
	tiles_render ${_animation_pos_x[0]} ${_animation_pos_y[0]} \
		${_animation_source_tile[0]} $COLOR_BLACK
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
