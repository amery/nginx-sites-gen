#!/bin/sh

set -eu

case "${1:-}" in
-c|--cloudflare)
	MODE=cloudflare
	shift
	;;
-g|--google)
	MODE=google
	shift
	;;
-*)
	echo "$1: mode not supported" >&2
	exit 1
	;;
*)
	MODE=manual
	;;
esac

case "$MODE" in
cloudflare)
	MODE_OPTS="--dns-$MODE --dns-$MODE-credentials $HOME/.secrets/$MODE.ini"
	;;
google)
	# https://certbot-dns-google.readthedocs.io/en/stable/
	MODE_OPTS="--dns-$MODE --dns-$MODE-credentials $HOME/.secrets/$MODE.json"
	;;
manual)
	MODE_OPTS="--$MODE --$MODE-public-ip-logging-ok"
	;;
esac

for D; do
	certbot certonly \
		${M:+-m "$M"} --agree-tos \
		--server https://acme-v02.api.letsencrypt.org/directory \
		--preferred-challenges dns-01 \
		${MODE_OPTS} \
		-d "$D" -d "*.$D"
done
