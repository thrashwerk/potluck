#!/bin/sh

# shellcheck disable=SC1091
. /root/.env.cook

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH=/usr/local/bin:$PATH

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

# shellcheck disable=SC3003
# safe(r) separator for sed
sep=$'\001'

# setup dovecot.conf
< "$TEMPLATEPATH/dovecot.conf.in" \
  sed "s${sep}%%mailcertdomain%%${sep}$MAILCERTDOMAIN${sep}g" | \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
  sed "s${sep}%%vhostdir%%${sep}$VHOSTDIR${sep}g" | \
  sed "s${sep}%%postmastermail%%${sep}$POSTMASTERADDRESS${sep}g" \
  > /usr/local/etc/dovecot/dovecot.conf

# unset ssl settings
sed -i .bak \
    -e "s${sep}ssl_cert =${sep}#ssl_cert =${sep}g" \
    -e "s${sep}ssl_key =${sep}#ssl_key =${sep}g" \
    /usr/local/etc/dovecot/conf.d/10-ssl.conf

# set ldap auth
sed -i .bak \
    -e "s${sep}!include auth-system.conf.ext${sep}#!include auth-system.conf.ext${sep}g" \
    -e "s${sep}#!include auth-ldap.conf.ext${sep}!include auth-ldap.conf.ext${sep}g" \
    /usr/local/etc/dovecot/conf.d/10-auth.conf

# enable dovecot
service dovecot enable
sysrc dovecot_config="/usr/local/etc/dovecot/dovecot.conf"
