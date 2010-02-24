#! /bin/bash
#
# linecount.sh
#
# Count the non-empty, non-comment lines in all .sh files recursively
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

if [ -z "$1" ]; then
	echo "Usage: $0 path"
	exit 1
fi

declare total=0
declare total_full=0

# Count the number of source lines in all scripts in this directory.
# Recursively call this function for each directory found.
#
# $1	Directory path
function count_directory
{
	local fname count full_count
	for fname in $1/*; do
		if [ -d $fname ]; then
			count_directory $fname
		else
			if [[ $fname =~ \.sh ]]; then
				full_count=$(cat $fname | wc -l)
				count=$(grep -v "^[[:space:]]\{0,\}#" "$fname" |
					grep -cv "^[[:space:]]\{0,\}$")
				(( total += count ))
				(( total_full += full_count ))
				printf "%-40s %-8d %3d%% Code\n" $fname $count \
					$(( (count * 100) / (full_count) ))
			fi
		fi
	done
}
count_directory $1
printf "%-40s %-8d %3d%% Code\n" "Total" $total \
	$(( (total * 100) / (total_full) ))
