#!/bin/sh

LETSENCRYPT=/etc/letsencrypt

err() {
	echo "$*" >&2
}

replace() {
	sed	-e "s|@D@|$domain|g" \
		-e "s|@NAME@|$name|g" \
		-e "s|@ROOT@|$root|g" \
		-e "s|@DOMAINROOT@|$domainroot|g" \
		"$@"
}

TAB="$(printf '\t')"

indent() {
	sed -e 's/^/\t/' -e 's/^[ \t]\+$//' "$@"
}

gen_server_config_body() {
	local proto= port=
	local ssl= root=
	local x=

	if [ -d "$target/" ]; then
		root=$(cd "$target" && pwd -P)
	fi

	# listen
	#
	for x; do
		proto="${x%:*}" port="${x##*:}"
		[ "$port" != "$proto" ] || port=

		if [ "$DEFAULT_SERVER" = "$name" ]; then
			x=" default_server ipv6only=off"
		else
			x=
		fi

		case "$proto" in
		http)
			: ${port:=80}
			;;
		https)
			: ${port:=443}
			x="${x} ssl"
			ssl=yes
			;;
		esac

		echo "listen [::]:$port$x;"
	done

	# server_name
	#
	if [ -s "$file_base.server_name" ]; then
		x=$(replace "$file_base.server_name" | tr '\n\t' '  ' |
			sed -e 's|^ *||g' -e 's| *$||' -e 's| \+| |g')
	else
		x=
	fi
	cat <<-EOT
	server_name ${x:-$name};

	EOT

	# SNI
	#
	if [ -n "$ssl" ]; then
		if [ -s "$file_base.ssl" ]; then
			replace "$file_base.ssl"
			echo
		elif [ -s "$LETSENCRYPT/live/$name/privkey.pem" ]; then
			cat <<-EOT
			ssl_certificate $LETSENCRYPT/live/$name/fullchain.pem;
			ssl_certificate_key $LETSENCRYPT/live/$name/privkey.pem;

			EOT
		elif [ -s '*.ssl' ]; then
			replace '*.ssl'
			echo
		fi
	fi

	case "$action" in
	"->"|"=>")	# redirect
		case "$target" in
		https)
			# http -> https special case
			target="https://$name"
			;;
		.)	# to domain
			target="\$scheme://$domain"
			;;
		*:*)	# URI
			;;
		*.*)	# host
			target="\$scheme://$target"
			;;
		*)	# name
			target="\$scheme://$target.$domain"
			;;
		esac

		case "$action" in
		"->") # soft
			cat <<-EOT
			location / {
			${TAB}rewrite ^ $target\$request_uri permanent;
			}
			EOT
			;;
		"=>") # hard
			cat <<-EOT
			location / {
			${TAB}rewrite ^ $target? permanent;
			}
			EOT
			;;
		esac
		;;
	=)	# root

		cat <<-EOT
		error_log logs/$logname.err info;
		access_log logs/$logname.log;

		EOT

		if [ -s "$target.conf" ]; then
			replace "$target.conf"
		else
			cat <<-EOT
			root $root;
			index index.html;
			EOT
		fi
	esac
}

gen_config_rules() {
	local x=
	local name= action= target=
	local proto=
	local file_base=

	[ $# -gt 0 ] || set -- http

	while read name action target; do
		# fill the blanks
		#
		: ${action:==}
		: ${target:=$name}

		# canonicalize name
		#
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

		for x; do
			proto="${x%:*}"
			echo "# $proto://$name"
		done
		cat <<-EOT
		#
		server {
		EOT

		gen_server_config_body "$@" | indent

		cat <<-EOT
		}

		EOT
	done
}

gen_config_rules_file() {
	local f="$1" d=
	shift

	[ -s "$f" ] || return 1

	if [ "$domain" = "$DEFAULT_SERVER" ]; then
		d="^\.[ \t]"
		grep "$d" "$f"
		grep -v "$d" "$f"
	elif [ "$domain" = "${DEFAULT_SERVER#*.}" ]; then
		d="${DEFAULT_SERVER%%.*}"
		grep -e "^$d$" -e "^$d[ \t]" "$f"
		grep -v -e "^$d$" -e "^$d[ \t]" "$f"
	else
		cat "$f"
	fi | sed -e '/^[ \t]*$/d' -e '/^[ \t]*#/d' |
		gen_config_rules "$@"
}

gen_config() {
	local domain="${PWD##*/}" domainroot="$PWD"
	local x= found=

	if [ -e sites.txt ]; then
		# legacy
		gen_config_rules_file sites.txt http && found=yes
	elif [ -e https.txt ]; then
		# legacy split
		gen_config_rules_file http.txt http && found=yes
		gen_config_rules_file https.txt https && found=yes
	else
		gen_config_rules_file http.txt http https && found=yes
		gen_config_rules_file http-only.txt http && found=yes
		gen_config_rules_file https-only.txt https && found=yes
	fi

	if [ -z "$found" ]; then
		if [ -d www/ ]; then
			echo ". -> www" | gen_config_rules http
		fi

		for x in */; do
			[ -d "$x" ] || continue
			x="${x%/}"

			echo "$x"
		done | gen_config_rules http
	fi
}

for x; do
	(cd "$x" && gen_config)
done
