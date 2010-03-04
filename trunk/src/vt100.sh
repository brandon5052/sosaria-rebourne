# vt100.sh
#
# A (very basic) VT100 terminal control library for BASH
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

# VT100 Color Codes
COLOR_BLACK=0
COLOR_RED=1
COLOR_GREEN=2
COLOR_YELLOW=3
COLOR_BLUE=4
COLOR_PURPLE=5
COLOR_TEAL=6
COLOR_WHITE=7

# Clear the screen
function vt100_clear
{
echo -ne "\e[2J"
}

# Revert to terminal default text attributes
function vt100_defaults
{
	echo -ne "\e[0m"
}

# Move the cursor to a given x / y location
#
# $1	X Location, zero-based
# $2	Y Location, zero-based
function vt100_goto
{
	local x=$(( $1 + 1 ))
	local y=$(( $2 + 1 ))
	echo -ne "\e[${y};${x}H"
}

# Set the foreground color
#
# $1	Foreground color number
function vt100_fg
{
	local fg=$(( $1 + 30 ))
	echo -ne "\e[${fg}m"
}

# Set the background color
#
# $1	Background color number
function vt100_bg
{
	local bg=$(( $1 + 40 ))
	echo -ne "\e[${bg}m"
}

# Set high-intensity mode
function vt100_high
{
	echo -ne "\e[1m"
}

# Save the cursor position
function vt100_save_cursor
{
	echo -ne "\e7"
}

# Restore the cursor position
function vt100_restore_cursor
{
	echo -ne "\e8"
}

# Move the cursor up
#
# $1	The number of lines to move
function vt100_up
{
	echo -ne "\e[${1}A"
}

# Move the cursor down
#
# $1	The number of lines to move
function vt100_down
{
	echo -ne "\e[${1}B"
}

# Move the cursor right
#
# $1	The number of rows to move
function vt100_right
{
	echo -ne "\e[${1}C"
}

# Move the cursor left
#
# $1	The number of rows to move
function vt100_left
{
	echo -ne "\e[${1}D"
}

# Home the cursor
function vt100_home
{
	vt100_goto 0 0
}

# Convert a single-character color code into a color number. The color number
# is placed in g_return.
#
# $1	The color code to convert
function vt100_color_code_to_number
{
	case "$1" in
		k)g_return=0;;
		r)g_return=1;;
		g)g_return=2;;
		y)g_return=3;;
		b)g_return=4;;
		p)g_return=5;;
		t)g_return=6;;
		*)g_return=7;;
	esac
}
