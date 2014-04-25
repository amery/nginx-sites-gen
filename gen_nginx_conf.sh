#!/bin/sh

err() {
	echo "$*" >&2
}

gen_config_rules() {
	local domain="$1" x=
	local name= action= target=
	local proto="${2:-http}" port="$3" ssl=
	local file_base=
	local server_name=

	if [ -z "$port" ]; then
		case "$proto" in
		http) port=80 ;;
		https) port=443 ;;
		*) err "$proto: can't guess port"; return ;;
		esac
	fi

	while read name action target; do
		# fill the blanks
		[ -n "$action" ] || action="="
		[ -n "$target" ] || target="$name"

		# canonicalize name
		if [ "$name" = '.' ]; then
			logname="$domain"
			name="$domain"
			file_base=
		else
			if [ "$action" = "=" ]; then
				file_base="$target"
			else
				file_base="$name"
			fi
			logname="$domain-$name"
			name="$name.$domain"
		fi

		server_name="$name"
		if [ -s "$file_base.server_name" ]; then
			x=$(sed -e "s|@D@|$domain|g" -e "s|@NAME@|$name|g" "$file_base.server_name" |
				tr '\n\t' '  ' |
				sed -e 's|^ *||g' -e 's| *$||' -e 's| \+| |g')
			if [ -n "$x" ]; then
				server_name="$x"
			fi
		fi

		case "$proto" in
		https)
			ssl=" ssl"
			;;
		*)
			ssl=
			;;
		esac

		cat <<-EOT
		# $proto://$name
		#
		server {
		    listen [::]:$port$ssl;
		    server_name $server_name;

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

gen_config_rules_from_file() {
	local f="$1"
	shift

	if [ -s "$f" ]; then
		sed -e '/^[ \t]*$/d' -e '/^[ \t]*#/d' "$f" |
			gen_config_rules "$@"
	fi
}

gen_config() {
	local domain="$1" x=

	if [ ! -s sites.txt -a ! -s http.txt -a ! -s https.txt ]; then
		if [ -d www/ ]; then
			echo ". -> www" | gen_config_rules "$domain"
		fi

		for x in */; do
			[ -d "$x" ] || continue
			x="${x%/}"

			echo "$x"
		done | gen_config_rules "$domain"
	else
		gen_config_rules_from_file sites.txt "$domain"
		gen_config_rules_from_file http.txt "$domain"
		gen_config_rules_from_file https.txt "$domain" https 443
	fi
}

for x; do
	cd "$x" 2> /dev/null || continue

	gen_config "${PWD##*/}"
	cd - > /dev/null
done


