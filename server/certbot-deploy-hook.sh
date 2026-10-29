#!/bin/sh
# deploy-hook certbot (/etc/letsencrypt/renewal-hooks/deploy/qgames.sh): после выпуска или продления сертификата
# кладёт его туда, где его читает web (/opt/qgames/certs, uid 101 — nginx-unprivileged), и перечитывает nginx.
set -eu
live=/etc/letsencrypt/live/qgames.duckdns.org
install -m 644 -o 101 -g 101 "$live/fullchain.pem" /opt/qgames/certs/cert.pem
install -m 600 -o 101 -g 101 "$live/privkey.pem" /opt/qgames/certs/key.pem
docker exec qgames-web nginx -s reload 2>/dev/null || true
