#!/bin/sh
GENDIR="${0%/*}"
GEN="$GENDIR/gen_nginx_conf.sh"

export LANG=C LANGUAGE=C LC_ALL=C
updated=

[ $# -gt 0 ] || set -- */
for D; do
	[ -d "$D" ] || continue
	D="${D%/}"
	C="$D.conf"

	echo "==== $D ===="

	if [ -s "$C" ]; then
		cp -f "$C" "$C.orig"
	else
		cat /dev/null > "$C.orig"
	fi

	if "$GEN" "$D" > "$C~"; then
		mv "$C~" "$C"
		sed -i -e 's|[ \t]\+$||' -e 's|^    \t|\t|' "$C"
		sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$C"
	else
		rm -f "$C~" "$C.orig"
		continue
	fi

	if diff -u "$C.orig" "$C" | pygmentize -l diff; then
		if nginx -t; then
			rm -f "$C.orig"
			updated=1
		else
			# bad new conf
			mv "$C" "$C.bad"
			mv "$C.orig" "$C"
		fi
	else
		# unchanged
		mv "$C.orig" "$C"
	fi
done

[ -z "$updated" ] || nginx -s reload
