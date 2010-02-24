#! /bin/bash
#
# terminal_test.sh
#
# VT100 terminal validation script
# Use this script when evaluating a new terminal for use with the vt100.sh
# library to ensure that it will be 100% compatible.
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

. ./src/vt100.sh

# HIGH and CLEAR
vt100_high
echo "Welcome to the vt100.sh test suite. As this is a test of the visual "
echo "output of your terminal, this is an interactive process."
echo
echo "This text should be bright white. If not, vt100_high does not work."
echo
echo "Press ENTER. The screen should clear. If it does not, vt100_clear"
echo "does not work."
read
vt100_clear

# FOREGROUND
echo "The text below should be black but readable."
vt100_fg $COLOR_BLACK
echo "This should be BLACK"
vt100_fg $COLOR_RED
echo "This should be RED"
vt100_fg $COLOR_GREEN
echo "This should be GREEN"
vt100_fg $COLOR_BLUE
echo "This should be BLUE"
vt100_fg $COLOR_YELLOW
echo "This should be YELLOW"
vt100_fg $COLOR_TEAL
echo "This should be TEAL"
vt100_fg $COLOR_PURPLE
echo "This should be PURPLE"
vt100_fg $COLOR_WHITE
echo "This should be WHITE"
echo
echo "If any of the above are not correct, vt100_fg does not work."
echo "Press ENTER to continue"
read
vt100_clear

# BACKGROUND
echo "The text below should be white but readable."
vt100_bg $COLOR_WHITE
echo "This should be WHITE"
vt100_bg $COLOR_RED
echo "This should be RED"
vt100_bg $COLOR_GREEN
echo "This should be GREEN"
vt100_bg $COLOR_BLUE
echo "This should be BLUE"
vt100_bg $COLOR_YELLOW
echo "This should be YELLOW"
vt100_bg $COLOR_TEAL
echo "This should be TEAL"
vt100_bg $COLOR_PURPLE
echo "This should be PURPLE"
vt100_bg $COLOR_BLACK
echo "This should be BLACK"
echo
echo "If any of the above are not correct, vt100_bg does not work."
echo "Press ENTER to continue"
read
vt100_clear

# GOTO
vt100_goto 4 9
echo "This text should be at 10, 5. If it is not, vt100_goto does not work."
echo
echo "Press ENTER to continue"
read
vt100_clear

# UP / DOWN / LEFT / RIGHT
vt100_home
vt100_down 10
vt100_right 20
vt100_up 5
vt100_left 10
echo "This text should be at 5, 10. If it is not, vt100_up/down does not work."
echo
echo "Press ENTER to continue"
read
vt100_clear

# SAVE / RESTORE
echo "The below line should read \"ABCdefg\". If it does not, vt100_save or"
echo "vt100_restore does not work."
echo
vt100_save_cursor
echo -n "abcdefg"
vt100_restore_cursor
echo -n "ABC"
echo
echo
echo "Press ENTER to continue"
read
vt100_clear

# DEFAULT
vt100_defaults
echo "Finally, this text should look like the default text of your terminal."
echo "If it does not, then vt100_default does not work."
