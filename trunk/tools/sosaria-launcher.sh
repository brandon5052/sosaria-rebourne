#! /bin/bash
#
# sosaria-launcher.sh
#
# Launcher script for Sosaria Re-Bourne.
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

declare terminal
declare client_opts
declare debug_log_path="/home/qbradq/data/Projects/sosaria/stderr.log"
declare client_path="/home/qbradq/data/Projects/sosaria/sosaria-rebourne.sh"
declare client_invoke="$client_path 2>$debug_log_path"
declare xterm_client_opts="-bg black -fg white -geometry 97x34 -e bash -c $client_invoke"

$client_invoke &
exit 0

# Detect available terminals
if type aterm >/dev/null 2>&1; then
	terminal="aterm"
	client_opts="$xterm_client_opts"
elif type xterm >/dev/null 2>&1; then
	terminal="xterm"
	client_opts="$xterm_client_opts"
else
	echo "No suitable terminal emulator found. Please install aterm." 1>&2
	exit 1
fi

echo $terminal $client_opts &
$terminal $client_opts &
