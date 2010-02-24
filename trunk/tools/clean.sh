#! /bin/bash
#
# clean.sh
#
# Clean up the development directory structure prior to a check-in.
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

# Clean up the development directory structure
if [ -z "$1" ]; then
	echo "Usage: $0 path"
	exit 1
fi

# Remove log files
rm -f $1/*.log

# Remove all local save data
rm -rf $1/save

# Set execute bit on tools and main script file
chmod +x $1/*.sh
chmod +x $1/tools/*.sh

# Clean all files in a directory. Recursively call this function for each
# directory found.
#
# $1	Directory path
function clean_directory
{
	local fname

	# Remove all compiled files (.bin extension)
	rm -f $1/*.bin

	for fname in $1/*; do
		# Proc subdirectories
		if [ -d $fname ]; then
			clean_directory $fname
		else
			# Convert all files to UNIX line endings
			dos2unix $fname
		fi
	done
}

# Recursively clean everything
clean_directory $1
