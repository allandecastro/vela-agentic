#!/bin/sh
# Setup for account-mi-outbound: an empty work dir plus a throwaway self-signed code-signing certificate
# (dev only) at <work>/signing/dev-signing.pfx, its password in <work>/signing/password.txt.
set -eu
WORK="$1"
mkdir -p "$WORK/signing"
cd "$WORK/signing"
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 30 -nodes \
  -subj "/CN=Zava Dev Signing" -addext "extendedKeyUsage=codeSigning" >/dev/null 2>&1
PW=$(openssl rand -hex 12)
openssl pkcs12 -export -out dev-signing.pfx -inkey key.pem -in cert.pem -passout "pass:$PW" -legacy 2>/dev/null \
  || openssl pkcs12 -export -out dev-signing.pfx -inkey key.pem -in cert.pem -passout "pass:$PW"
printf '%s' "$PW" > password.txt
rm -f key.pem cert.pem
chmod 600 dev-signing.pfx password.txt
