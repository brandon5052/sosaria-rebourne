# common.sh
#
# Common functions
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

# Global configuration
declare -r _common_screen_width=97

# Globals
declare -a _common_at_exit_handlers

# Feature detection for the sleep function jiffy_sleep. This function sleeps
# for an amount of time represented in "jiffies", here one millisecond.
#
# Note that if the version of BASH is prior to 4 and the system's sleep
# command does not allow fractional sleep times, the sleep duration will be
# rounded to the nearest second.
#
# $1	The number of jiffies to sleep
#
# In bash 4+ we use read with a timeout because it's a built-in and fairly
# accurate.
if (( BASH_VERSINFO[0] >= 4 )); then
	function jiffy_sleep
	{
		local ms=$(( $1 ))
		printf -v sleep_format "%d.%03d" $(( ms / 1000 )) $(( ms % 1000 ))
		IFS= read -st $sleep_format buffer
	}
# Otherwise use the system sleep function
elif type sleep >/dev/null 2>&1; then
	# Figure out how long it takes to invoke sleep
	declare _common_sleep_invoke_time=0
	function jiffy_sleep_calibrate
	{
		local idx tmpfile tmpfile_contents seconds ms
		tmpfile=$(mktemp)
		
		echo "Calibrating Sleep Routine"
		(time for (( idx=0; idx < 10; idx++ )); do sleep 0; done) 2> $tmpfile
		tmpfile_contents=($(cat $tmpfile) )
		rm -f $tmpfile 2>/dev/null
		seconds=${tmpfile_contents[1]#*m}
		ms=${seconds#*.}
		ms=${ms%s}
		ms=${ms#0}
		ms=${ms#0}
		seconds=${seconds%.*}
		(( ms += seconds * 1000 ))
		(( _common_sleep_invoke_time = ms / 10 ))
	}
	# Sleep is capable of fractional sleep times, yay!
	if sleep 0.1 >/dev/null 2>&1; then
		function jiffy_sleep
		{
			local ms=$(( $1 - _common_sleep_invoke_time ))
			
			# The invokation of sleep will take longer than the sleep time
			if (( ms < 0 )); then
				(( ms *= -1 ))
				# If the overage is greater than the requested sleep time, then
				# we would be delaying at least 2X the requested sleep time. In
				# this case, just return without sleeping.
				if (( ms > $1 )); then return 0; fi
				# Otherwise issue a sleep 0
				echo "jiffy_sleep sleep 0" >&2
				sleep 0
			fi
			
			printf -v sleep_format "%d.%03d" $(( ms / 1000 )) $(( ms % 1000 ))
			sleep "$sleep_format"
		}
	else
		function jiffy_sleep
		{
			local ms=$(( $1 - _common_sleep_invoke_time ))
			
			# Just invoking sleep would delay more than we wanted, so don't.
			if (( ms < 0 )); then return 0; fi
			
			# Round to the nearest hundred
			local jiffies=$1
			if (( jiffies % 100 < 50 )); then
				(( jiffies -= jiffies % 100 ));
			else
				(( jiffies += 100 - (jiffies % 100) ))
			fi
			
			sleep $(( jiffies / 100 ))
		}
	fi
	jiffy_sleep_calibrate
# If all else fails we just won't sleep
else
	function jiffy_sleep
	{
		:
	}
fi

# Set up at_exit trap
trap "do_at_exit" 0

# Execute all at_exit handlers
function do_at_exit
{
	local idx
	
	for (( idx=0; idx < ${#_common_at_exit_handlers[@]}; idx++ )); do
		eval "${_common_at_exit_handlers[$idx]}"
	done
}

# Register an at_exit handler
#
# $1	Command string to execute
function at_exit
{
	_common_at_exit_handlers=(${_common_at_exit_handlers[@]} "$1")
}

# Raise an error
#
# $1	Message text of the error
# $2	Exit code, if non-zero we will exit
function error
{
	vt100_home
	vt100_high
	vt100_fg $COLOR_WHITE
	vt100_bg $COLOR_RED
	echo "ERROR: $1"
	echo -n "Press Enter to Continue"
	read
	
	if [ "$2" -ne 0 ]; then
		exit $2
	fi
}

# Convert the first character of a string to uppercase, and place the new
# string in g_return.
#
# $1	String to uppercase
function uppercase_first_character
{
	local first="${1:0:1}"
	local rest="${1:1}"
	printf -v first_code "%d" "'$first"
	local octal_code
	if (( first_code >= 97 && first_code <= 122 )); then
		(( first_code -= 32 ))
	fi
	printf -v "%o" $first_code
	printf -v first "\\$octal_code"
	g_return="$first$rest"
}

# Place the class string for a class letter in g_return
#
# $1	Class letter
function get_class_string
{
	case $1 in
		A) g_return="Adventurer" ;;
		F) g_return="Fighter" ;;
		R) g_return="Rouge" ;;
		S) g_return="Sorcerer" ;;
		P) g_return="Paladin" ;;
		T) g_return="Thief" ;;
		M) g_return="Mage" ;;
		*) g_return="Monster" ;;
	esac
}

# Create a new save data directory. This sets g_save_data_path to the new save
# path.
function create_new_save
{
	local i=0
	
	while :; do
		if [ -d "$g_dynamic_data_path/$i" ]; then
			(( i++ ))
			continue
		fi
		g_save_data_path="$g_dynamic_data_path/$i"
		mkdir -p "$g_save_data_path/maps"
		cp "$g_static_data_path/party.tab" "$g_save_data_path"
		cp "$g_static_data_path/equipment.tab" "$g_save_data_path"
		cp "$g_static_data_path/inventory.tab" "$g_save_data_path"
		break
	done
}

# Sets g_save_data_path to the newest save path.
#
# Returns non-zero if no save exists
function load_last_save
{
	local dirname
	
	for dirname in $(ls -drt $g_dynamic_data_path/* 2>/dev/null); do
		if [ -d "$dirname" ]; then
			g_save_data_path="$dirname"
			combat_load_from_save
			item_load_from_save
			return 0
		fi
	done
	
	return 1
}

# Calls all save routines for the current save.
function save_game
{
	combat_save
}

# Debug proceedure. Put whatever you need to test here.
function debug_proc
{
	save_game
}
