#!/bin/sh

set -eu

for D; do
	certbot certonly \
		${M:+-m "$M"} --agree-tos \
		--server https://acme-v02.api.letsencrypt.org/directory \
		--preferred-challenges dns-01 \
		--manual --manual-public-ip-logging-ok \
		-d "$D" -d "*.$D"
done
