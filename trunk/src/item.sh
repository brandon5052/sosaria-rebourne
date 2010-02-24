# item.sh
#
# Items system
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

# Item static data
declare -a _item_name
declare -a _item_str
declare -a _item_dex
declare -a _item_int
declare -a _item_type
declare -a _item_param

# Party equipment data (uses indicies from the _combat_mob* tables)
declare -a _item_mob_head
declare -a _item_mob_body
declare -a _item_mob_accessory1
declare -a _item_mob_accessory2
declare -a _item_mob_weapon
declare -a _item_mob_shield

# Party inventory data
declare -a _item_party_idx
declare -a _item_party_amount

# Load all item static data
function item_init
{
	local idx name str dex int typ param
	# Load item table
	while read idx name str dex int typ param; do
		if [ "$idx" = "#" ]; then continue; fi
		_item_name[$idx]="${name//_/ }"
		_item_str[$idx]=$str
		_item_dex[$idx]=$dex
		_item_int[$idx]=$int
		_item_type[$idx]=$typ
		_item_param[$idx]=$param
	done < "$g_static_data_path/items.tab"

}

# Load party data from save file
function item_load_from_save
{
	local idx head body acc1 acc2 weapon shield item amount

	# Load all party equipment	 
	while read idx head body acc1 acc2 weapon shield; do
		if [ "$idx" = "#" ]; then continue; fi
		(( idx += _combat_num_mobs ))
		_item_mob_head[$idx]=$head
		_item_mob_body[$idx]=$body
		_item_mob_accessory1[$idx]=$acc1
		_item_mob_accessory2[$idx]=$acc2
		_item_mob_weapon[$idx]=$weapon
		_item_mob_shield[$idx]=$shield
	done < "$g_save_data_path/equipment.tab"

	# Load party inventory
	while read idx item amount; do
		if [ "$idx" = "#" ]; then continue; fi
			_item_party_idx[$idx]=$item
			_item_party_amount[$idx]=$amount
	done < "$g_save_data_path/inventory.tab"
}

# Place the (short) type string for a given item type code into g_return.
#
# $1	The item type code
function item_get_type_string
{
	case "$1" in
	A) g_return="Accessory" ;;
	B) g_return="Body armor" ;;
	C) g_return="Consumable" ;;
	H) g_return="Helm" ;;
	M) g_return="Weapon" ;;
	m) g_return="2-H Weapon" ;;
	R) g_return="Ranged" ;;
	r) g_return="2-H Ranged" ;;
	S) g_return="Shield" ;;
	*) g_return="None" ;;
	esac
}

# Determine if a monster is able to use an item
#
# $1	The monster index of the monster to check
# $2	The item index of the item to check
# Returns non-zero if the monster is unable to use the item
function item_can_monster_use
{
	# Compare stat requirements
	if (( _combat_mob_str[$1] < _item_str[$2] || \
		_combat_mob_dex[$1] < _item_dex[$2] || \
		_combat_mob_int[$1] < _item_int[$2] )); then
		return 1
	fi
	
	return 0
}

# Determine if a character can equip a two-handed weapon right now.
#
# $1	The monster index of the monster to check
# Returns non-zero if the monster cannot equip a two-handed weapon right now.
function item_can_monster_equip_two_handed_weapon
{
	local item_idx
	
	# If we are not wearing a sheild right now we can equip a two-handed
	# weapon.
	item_idx=${_item_mob_shield[$1]}
	if (( item_idx == 0 )); then
		return 0
	fi
	
	return 1
}

# Determine if a character can equip a shield right now.
#
# $1	The monster index of the monster to check
# Returns non-zero if the monster cannot equip a shield right now.
function item_can_monster_equip_shield
{
	local item_idx item_type
	
	# If we are not wearing a two-handed weapon we can equip a shield
	item_idx=${_item_mob_weapon[$1]}
	item_type=${_item_type[$item_idx]}
	if [ "$item_type" != "m" -a "$item_type" != "r" ]; then
		return 0
	fi
	
	return 1
}

# Add an item to the party inventory
#
# $1	The item index
# $2	The amount, defaults to 1
function item_add_to_inventory
{
	local idx amount
	
	# None item short-circut
	if (( $1 == 0 )); then
		return 0
	fi
	
	# Default parameters
	if [ -z "$2" ]; then
		amount=1
	else
		amount=$2
	fi
	
	# Try to find the item in inventory and add the amount to it
	for (( idx=0; idx < ${#_item_party_idx[@]}; idx++ )); do
		if (( _item_party_idx[$idx] == $1 )); then
			(( _item_party_amount[$idx] += $amount ))
			return 0
		fi
	done
	
	# Add to the end of inventory
	_item_party_idx=(${_item_party_idx[@]} $1)
	_item_party_amount=(${_item_party_amount[@]} $amount)
	
	return 0
}

# Remove an item from the party inventory
#
# $1	The item index
# $2	The amount to remove, defaults to 1
# Returns non-zero if the item was not found in inventory
function item_remove_from_inventory
{
	local idx amount
	
	# None item short-circut
	if (( $1 == 0 )); then
		return 0
	fi
	
	# Default parameters
	if [ -z "$2" ]; then
		amount=1
	else
		amount=$2
	fi
	
	# Try to find the item in inventory and remove the amount from it
	for (( idx=0; idx < ${#_item_party_idx[@]}; idx++ )); do
		if (( _item_party_idx[$idx] == $1 )); then
			(( _item_party_amount[$idx] -= $amount ))
			# No more left, remove this entry
			if (( _item_party_amount[$idx] <= 0 )); then
				echo "REMOVE $idx ARRAY=${_item_party_idx[@]}" >&2
				_item_party_idx=(${_item_party_idx[@]:0:$idx} ${_item_party_idx[@]:$((idx+1))})
				_item_party_amount=(${_item_party_amount[@]:0:$idx} ${_item_party_amount[@]:$((idx+1))})
				echo "AFTER REMOVE $idx ARRAY=${_item_party_idx[@]}" >&2
			fi
			return 0
		fi
	done

	# Item not found in inventory
	return 1
}

# Remove equipment from a monster
#
# $1	The monster index of the monster
# $2	The euipqment code, H, B, S, W, A1 or A2
function item_remove_equipment
{
	local item_idx
	
	# Remove the equipment
	case $2 in
	H) item_idx=${_item_mob_head[$1]}; _item_mob_head[$1]=0 ;;
	B) item_idx=${_item_mob_body[$1]}; _item_mob_body[$1]=0 ;;
	S) item_idx=${_item_mob_shield[$1]}; _item_mob_shield[$1]=0 ;;
	W) item_idx=${_item_mob_weapon[$1]}; _item_mob_weapon[$1]=0 ;;
	A1) item_idx=${_item_mob_accessory1[$1]}; _item_mob_accessory1[$1]=0 ;;
	A2) item_idx=${_item_mob_accessory2[$1]}; _item_mob_accessory2[$1]=0 ;;
	esac
	
	# Add the equipment back to inventory
	item_add_to_inventory $item_idx
}

# Add equipment to a monster, but DOES NOT check requirements. This is handled
# in the UI.
#
# $1	The monster index of the monster
# $2	The euipqment code, H, B, S, W, A1 or A2
# $3	The item index of the item to equip
# Returns non-zero on failure
function item_equip_equipment
{
	local weapon_idx
	
	# Take the item from inventory
	if ! item_remove_from_inventory $3; then
		return 1
	fi

	# Remove the existing equipment
	item_remove_equipment $1 $2
	
	weapon_idx=${_item_mob_weapon[$1]}

	# If this is a two-handed weapon, remove the shield
	if [ "${_item_type[$3]}" = "m" -o "${_item_type[$3]}" = "r" ]; then
		item_remove_equipment $1 S
	# If this is a shield and the character is wearing a two-handed weapon,
	# remove it.
	elif [ "${_item_type[$3]}" = "S" -a \
		\( \
			"${_item_type[$weapon_idx]}" = "m" -o \
			"${_item_type[$weapon_idx]}" = "r" \
		\) ]; then
		item_remove_equipment $1 W
	fi
	
	# Place the new equipment in the right slot
	case $2 in
	H) _item_mob_head[$1]=$3 ;;
	B) _item_mob_body[$1]=$3 ;;
	S) _item_mob_shield[$1]=$3 ;;
	W) _item_mob_weapon[$1]=$3 ;;
	A1) _item_mob_accessory1[$1]=$3 ;;
	A2) _item_mob_accessory2[$1]=$3 ;;
	esac
	
	return 0
}

# Return the target type for a given consumable item, which is placed in
# g_return.
#
# $1	The item index of the item to check
function item_get_target_type
{
	local -a params
	
	params=(${_item_param[$1]})
	g_return=${params[1]}
}

# Use an item on a monster.
#
# $1	The item index of the item to use
# $2	Monster index of the monster using the item
# $3	Monster index of the target of the item
function item_use_item
{
	local -a params
	
	params=(${_item_param[$1]})
	${params[0]} "$2" "$3" "${params[2]}" "${params[3]}" "${params[4]}"
}

# Healing potion proceedure
#
# $1	Monster index of the monster using the item
# $2	Monster index of the target of the item
# $3	Minimum amount of damage to heal
# $4	Maximum amount of damage to heal
function item_proc_pot_heal
{
	combat_take_damage $2 $(( ( (RANDOM % ($4 - $3) + 1) + $3 ) * -1 ))
}

# Exploding item proceedure
#
# $1	Monster index of the monster using the item
# $2	Monster index of the target of the item
# $3	Minimum amount of damage
# $4	Maximum amount of damag
function item_proc_explosion
{
	combat_take_damage $2 $(( (RANDOM % ($4 - $3) + 1) + $3 ))
}
