#!/bin/sh

err() {
	echo "$*" >&2
}

gen_config_rules() {
	local domain="$1" x=
	local name= action= target=
	local proto=http port=80

	while read name action target; do
		# fill the blanks
		[ -n "$action" ] || action="="
		[ -n "$target" ] || target="$name"

		# canonicalize name
		if [ "$name" = '.' ]; then
			logname="$domain"
			name="$domain"
		else
			logname="$domain-$name"
			name="$name.$domain"
		fi

		cat <<-EOT
		# $proto://$name
		#
		server {
		    listen [::]:$port;
		    server_name $name;

		EOT

		case "$action" in
		"->"|"=>")	# redirect
			case "$target" in
			.)	# to domain
				target="$proto://$domain"
				;;
			*:*)	# URI
				;;
			*.*)	# host
				target="$proto://$target"
				;;
			*)	# name
				target="$proto://$target.$domain"
				;;
			esac

			case "$action" in
			"->") # soft
				echo "    rewrite ^ $target\$request_uri permanent;"
				;;
			"=>") # hard
				echo "    rewrite ^ $target? permanent;"
				;;
			esac
			;;
		=)	# root

			cat <<-EOT
			    error_log logs/$logname.err info;
			    access_log logs/$logname.log;

			EOT

			x=$(cd "$target"; pwd -P)
			if [ -s "$target.conf" ]; then
				sed	-e 's/^/    /' \
					-e "s,@ROOT@,$x,g" \
					"$target.conf"
			else
				cat <<-EOT
				    root $x;
				    index index.html;
				EOT
			fi
		esac
		cat <<-EOT
		}

		EOT
	done
}

gen_config() {
	local domain="$1" x=

	if [ -f sites.txt ]; then
		sed -e '/^[ \t]*$/d' -e '/^[ \t]*#/d' \
			sites.txt | gen_config_rules "$domain"
	else
		if [ -d www/ ]; then
			echo ". -> www" | gen_config_rules "$domain"
		fi

		for x in */; do
			[ -d "$x" ] || continue
			x="${x%/}"

			echo "$x"
		done | gen_config_rules "$domain"
	fi
}

for x; do
	cd "$x" 2> /dev/null || continue

	gen_config "${PWD##*/}"
	cd - > /dev/null
done


