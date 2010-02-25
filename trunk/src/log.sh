# log.sh
#
# Message log system
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
declare -r _log_x=56
declare -r _log_y=9
declare -r _log_height=24
declare -r _log_width=40
declare -r _log_blank_line="                                        "

# Private data
declare -a _log_lines

# Write a log message
#
# $@	All arguments are stuck together without spaces
function log_write
{
	local format msg idx word
	local -a words
	
	# Build the format string
	while [ $# -gt 0 ]; do
		format="$format$1"
		shift
	done

	# Make sure the message starts with a capitol letter
	uppercase_first_character "$format"
	format="$g_return"

	# Process all words for line wrapping
	words=($format)
	msg=
	for (( idx=0; idx < ${#words[@]}; idx++ )); do
		word="${words[$idx]}"
		# If the length of this line would exceed the log width, break it
		if (( ${#msg} + ${#word} + 1 > _log_width )); then
			log_push_message "$msg"
			msg=" $word "
		else
			msg="$msg$word "
		fi
	done
	log_push_message "$msg"
	log_render
}

# Push a message onto the message array
#
# $1	The message string
function log_push_message
{
	local idx
	
	for(( idx=_log_height-2; idx >= 0; idx-- )); do
		_log_lines[$idx+1]="${_log_lines[$idx]}"
	done
	_log_lines[0]="$1"
}

# Render the log area
function log_render
{
	local ofs_y
	
	for(( idx=0; idx <_log_height; idx++ )); do
		ofs_y=$(( ( _log_height - 1 ) - idx ))
		vt100_goto $_log_x $((_log_y + ofs_y))
		vt100_high
		vt100_bg $COLOR_BLACK
		vt100_fg $COLOR_WHITE
		echo -nE "$_log_blank_line"
		vt100_goto $_log_x $((_log_y + ofs_y))
		echo -nE "${_log_lines[$idx]}"
	done
}
