#!/bin/sh

die() {
	echo "$@" >&1
	exit 1
}

set -e
ARG0=$(readlink -f "$0")
[ -x "$ARG0" ] || die "$0: not found"
cd "$(dirname "$0")"

U="${ARG0%/*}/update.sh"
S="$PWD/sites.conf"
F=
rm -f "$S~"
for d in */*/; do
	[ -d "$d" ] || continue
	[ ! -e "$d/.skip" ] || continue

	d="${d%/}"
	c="$PWD/$d.conf"
	[ -s "$c" ] || touch "$c"

	l="include \"$c\";"
	if ! grep -q "^$l\$" "$S"; then
		echo "$l" >> "$S"
	fi
	echo "$l" >> "$S~"

	$U "$d/"
done

echo "====="
mv "$S~" "$S"
nginx -t && nginx -s reload
