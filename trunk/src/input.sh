# input.sh
#
# Input library
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

# Feature detection
if (( BASH_VERSINFO[0] >= 4 )); then
	declare -r _input_nonblocking_read_timeout="0.1"
	# If we have the stty utility available, we use it to do the following:
	# Disable local echo. This prevents display issues when holding down a key
	# Use a single-character buffer mode, enables us to flush the buffer
	if type stty >/dev/null 2>&1; then
		declare -r _input_stty_opts=$(stty --save)
		stty -echo -icanon min 1 time 0
		at_exit "stty $_input_stty_opts"
		declare -r _input_use_buffer_flush=1
	else
		declare -r _input_use_buffer_flush=0
	fi
else
	declare -r _input_nonblocking_read_timeout=1
fi

# Get a single input key code from the terminal, returning a string describing
# the key in g_return.
function input_get_key
{
	local buffer code
	
	# Flush the input buffer if we can
	ui_park_cursor
	if (( _input_use_buffer_flush > 0 )); then
		# This is not working
		while read -rst 0 buffer; do
			IFS= read -rsn 1 buffer
		done
	fi

	# Read the character and convert to a code number
	IFS= read -rsn 1 buffer
	printf -v code "%d" "'$buffer"

	case $code in
	0) g_return="ENTER" ;;
	8) g_return="BACKSPACE" ;;
	9) g_return="TAB" ;;
	27)
		if read -rsn 1 -t $_input_nonblocking_read_timeout \
			buffer; then
			printf -v code "%d" "'$buffer"
		# Single escape with pause
		else
			g_return="ESCAPE"
			return 0
		fi

		case $code in
		# Double-escape
		27) g_return="ESCAPE" ;;
		# Special character sequence
		91)
			if read -rsn 1 -t $_input_nonblocking_read_timeout \
				buffer; then
				printf -v code "%d" "'$buffer"
			# Something bad happened here
			else
				g_return="ERROR"
				return 0
			fi
			case $code in
			65) g_return="UP" ;;
			66) g_return="DOWN" ;;
			67) g_return="RIGHT" ;;
			68) g_return="LEFT" ;;
			# Something we don't handle yet
			*) g_return="ERROR" ;;
			esac
		;;
		*) g_return="$buffer" ;;
		esac
	;;
	32) g_return="SPACE" ;;
	*) g_return="$buffer" ;;
	esac
}
