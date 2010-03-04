# vt100img.sh
#
# A VT100 image rendering and compilation library for BASH
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

# Load a vt100 image file and render it to stdout
#
# $1	Path to the image file
function vt100img_render
{
	local buffer newline_flag foreground character last_foreground idx
	local -a image_chars

	# If the cache is present and up to date, use it
	if [ -r "$1.bin" -a "$1.bin" -nt "$1" ]; then
		read -rd "" buffer <"$1.bin"
		echo -nE "$buffer"
		return 0
	fi

	# Otherwise we need to compile the image
	if [ ! -r "$1" ]; then
		error "Image file $1 not found." 1
	fi
	newline_flag=0
	while :; do
		# Load all characters
		idx=0
		while IFS= read -rn 1 buffer; do
			if [ "$buffer" = "" ]; then
				if (( newline_flag == 1 )); then
					break
				fi
				newline_flag=1
				continue
			fi
			newline_flag=0
			image_chars[$idx]="$buffer"
			(( idx++ ))
		done
		
		last_foreground=-1
		idx=0
		newline_flag=0
		vt100_save_cursor > "$1.bin"
		vt100_high >> "$1.bin" 
		# Process all color definitions
		while IFS= read -rn 1 buffer; do
			if [ "$buffer" = "" ]; then
				newline_flag=1
				continue
			fi

			# Processing the first character after a new line
			if (( newline_flag == 1)); then
				vt100_restore_cursor >> "$1.bin"
				vt100_down 1 >> "$1.bin"
				vt100_high >> "$1.bin"
				vt100_save_cursor >> "$1.bin"
				last_foreground=-1
				newline_flag=0
			fi

			foreground="${buffer:0:1}"
			character="${image_chars[$idx]}"
			if [ "$foreground" != "$last_foreground" ]; then
				last_foreground="$foreground"
				# Map the foreground color
				vt100_color_code_to_number "$foreground"
				vt100_fg "$g_return" >> "$1.bin"
			fi
			if [ "$character" = " " ]; then
				echo -ne " " >> "$1.bin"
			else
				echo -nE "$character" >> "$1.bin"
			fi
			(( idx++ ))
		done
		break
	done < "$1"

	# Cap the rendering with a cursor restore
	vt100_restore_cursor >> "$1.bin"

	# And now spit it back out
	read -rd "" buffer <"$1.bin"
	echo -nE "$buffer"
	return 0
}
