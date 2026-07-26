#!/usr/bin/env bash

set -euo pipefail

SELECTOR="default"
PRIVATE_KEY="/var/spanel/domain_keys/private"
PUBLIC_KEY="/var/spanel/domain_keys/public"
SERVER_IP=$(dig +short A "$(hostname -f)" | head -n1)

DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
    read -r -p "Please enter the sub-domain: " DOMAIN
fi

DOMAIN="${DOMAIN%.}"
DOMAIN="${DOMAIN,,}"

if [[ -z "$DOMAIN" ]]; 
  then echo "Error: The sub-domain cannot be empty." 
  exit 1 
fi

if [[ ! "$DOMAIN" =~ ^([a-z0-9-]+\.)+[a-z]{2,}$ ]]; then
    echo "Error: Invalid domain name: $DOMAIN"
    exit 1
fi

if [[ -f "$PRIVATE_KEY/$DOMAIN" ]]; then
    echo "Error: Private key already exists: $PRIVATE_KEY/$DOMAIN"
    exit 1
fi

if [[ -f "$PUBLIC_KEY/$DOMAIN" ]]; then
    echo "Error: Public key already exists: $PUBLIC_KEY/$DOMAIN"
    exit 1
fi

openssl genpkey \
  -quiet \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:2048 \
  -out "$PRIVATE_KEY/$DOMAIN"

openssl rsa \
  -in "$PRIVATE_KEY/$DOMAIN" \
  -pubout \
  -out "$PUBLIC_KEY/$DOMAIN" \
  2>/dev/null

chown exim:mail "$PRIVATE_KEY/$DOMAIN"
chmod 600 "$PRIVATE_KEY/$DOMAIN"
chmod 644 "$PUBLIC_KEY/$DOMAIN"

DKIM_RECORD=$(
  grep -v -- "-----" "$PUBLIC_KEY/$DOMAIN" |
  tr -d '\r\n'
)

echo "------------------------"
echo "DKIM Record"
echo "Domain: ${SELECTOR}._domainkey.${DOMAIN}"
echo "Type: TXT"
echo "Value: "
echo "v=DKIM1; k=rsa; p=${DKIM_RECORD}"
echo "------------------------"
echo "SPF Record"
echo "Domain: ${DOMAIN}"
echo "Type: TXT" 
echo "Value: "
echo "v=spf1 +a +mx +ip4:$SERVER_IP -all"
echo "------------------------"
echo "MX Record"
echo "Domain: ${DOMAIN}"
echo "Type: MX | Prioty: 0"
echo "Value: "
echo "$(hostname -f)"
echo "------------------------"
echo "DMARC Record"
echo "Domain: _dmarc.${DOMAIN}"
echo "Type: TXT"
echo "Value: "
echo "v=DMARC1; p=reject; sp=none; rf=afrf; pct=100; ri=86400"
echo "------------------------"

