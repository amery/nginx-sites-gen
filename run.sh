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

# default server
#
D="$PWD/default_server"
if [ -s "$D" ]; then
	read D < "$D"
else
	D=
fi

rm -f "$S~"
ls -1d */*/ 2> /dev/null | sed -e 's|/\+$||' | sort |
while read d; do
	[ ! -e "$d/.skip" ] || continue

	c="$PWD/$d.conf"
	[ -s "$c" ] || touch "$c"

	l="include \"$c\";"
	if ! grep -q "^$l\$" "$S"; then
		echo "$l" >> "$S"
	fi
	echo "$l" >> "$S~"

	DEFAULT_SERVER="$D" $U "$d/"
done

echo "====="
mv "$S~" "$S"
nginx -t && nginx -s reload
