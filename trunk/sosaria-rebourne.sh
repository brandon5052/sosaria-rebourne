#! /bin/bash
#
# sosaria-rebourne.sh
#
# Main executable entry point.
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
declare -r g_static_data_path="data"
declare -r g_dynamic_data_path="save"
declare g_save_data_path
declare g_return

# Source all libraries
. ./src/common.sh
. ./src/vt100.sh
. ./src/vt100img.sh
. ./src/tiles.sh
. ./src/combat.sh
. ./src/input.sh
. ./src/log.sh
. ./src/ui.sh
. ./src/item.sh
. ./src/animation.sh

at_exit "vt100_defaults; vt100_clear"

# Load the last save or create a new one
if ! load_last_save; then
	create_new_save
	load_last_save
fi

tiles_init
item_init
combat_init

vt100_bg $COLOR_BLACK
vt100_fg $COLOR_WHITE
vt100_high
vt100_clear
vt100_home
combat_mode trees 1 

exit 0
