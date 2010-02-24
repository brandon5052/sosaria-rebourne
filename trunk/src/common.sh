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

# Feature detection for the sleep function
# In bash 4+ we use read with a timeout
if (( BASH_VERSINFO[0] >= 4 )); then
	function jiffy_sleep
	{
		local buffer
		IFS= read -st $1 buffer
	}
elif type sleep >/dev/null 2>&1; then
	if sleep 0.1 >/dev/null 2>&1; then
		function jiffy_sleep
		{
			sleep $1
		}
	else
		function jiffy_sleep
		{
			local to_sleep=${1%.*}
			if (( to_sleep < 1 )); then
				to_sleep=1
			fi
			sleep $to_sleep
		}
	fi
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
	
	for dirname in `ls -drt $g_dynamic_data_path/* 2>/dev/null`; do
		if [ -d "$dirname" ]; then
			g_save_data_path="$dirname"
			combat_load_from_save
			item_load_from_save
			return 0
		fi
	done
	
	return 1
}

# Debug proceedure. Put whatever you need to test here.
function debug_proc
{
	item_equip_equipment 17 H 1
}
