# tiles.sh
#
# Tile management library
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
declare -r tiles_char_width=5
declare -r tiles_char_height=3
declare -r _tiles_tab_path="$g_static_data_path/tiles.tab"
declare -r _tiles_path="$g_static_data_path/tiles"

# Public data
declare -a tiles_symbol_xref

# Private data
declare -a _tiles_cache
declare -a _tiles_symbol
declare -a _tiles_combat_map_name

# Load all tiles defined in _tiles_tab_path
function tiles_init
{
	local image_file symbol index combat_map_name symbol_dec
	
	echo "Loading images"
	while read image_file symbol index combat_map_name; do
		if [ "$symbol" != "-" ]; then
			printf -v symbol_dec '%d' "'$symbol"
			_tiles_symbol[$index]=$symbol
			tiles_symbol_xref[$symbol_dec]=$index
		fi
		if [ "$combat_map_name" != "-" ]; then
			_tiles_combat_map_name[$index]=$combat_map_name
		fi
		# TODO - May need to refactor the subshell out of this for performance
		_tiles_cache[$index]="$(vt100img_render $_tiles_path/$image_file.vt100)"
	done < $_tiles_tab_path
}

# Render a tile at a given location
#
# $1	X position, zero-based
# $2	Y position, zero-based
# $3	Tile index
# $4	Background color
function tiles_render
{
	vt100_goto $1 $2
	vt100_bg $4
	echo -nE "${_tiles_cache[$3]}"
	vt100_bg 0
}

# Debug mode to show all tiles
function tiles_debug_display
{
	local image_file symbol index combat_map_name symbol_dec ofs_x ofs_y

	ofs_y=0
	ofs_x=0
	while read image_file symbol index combat_map_name; do
		tiles_render $ofs_x $ofs_y $index
		(( ofs_x += tiles_char_width ))
		if (( ofs_x > 80 - tiles_char_width)); then
			(( ofs_y += tiles_char_height ))
			ofs_x=0
		fi
	done < $_tiles_tab_path
}
