#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add timestamp to logs
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), "[** MAILGUN SEND EMAIL **]", $0; fflush(); }') 2>&1

set -a
source .env
set +a

# Configuration
MAILGUN_API_BASE="https://api.eu.mailgun.net/v3/${MAILGUN_DOMAIN}"

# Email details
FROM="Mailgun <mailgun@${MAILGUN_DOMAIN}>"
TO=$1
SUBJECT=$2
TEXT=$3

# Send the email
curl -s --user "api:${MAILGUN_API_KEY}" \
    "${MAILGUN_API_BASE}/messages" \
    -F from="${FROM}" \
    -F to="${TO}" \
    -F subject="${SUBJECT}" \
    -F text="${TEXT}"

