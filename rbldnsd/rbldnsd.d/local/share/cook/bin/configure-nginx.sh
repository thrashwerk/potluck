#!/bin/sh

# shellcheck disable=SC1091
if [ -e /root/.env.cook ]; then
    . /root/.env.cook
fi

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH=/usr/local/bin:$PATH

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

# make traumadrill web directory and set permissions
mkdir -p /usr/local/www/rbldnsd

# copy in index.php
cp -f "$TEMPLATEPATH/index.php.in" /usr/local/www/rbldnsd/index.php

# set ownership on web directory, www needs write perms for stress-ng
chown www:www /usr/local/www/rbldnsd
chmod 775 /usr/local/www/rbldnsd

# shellcheck disable=SC3003,SC2039
# safe(r) separator for sed
sep=$'\001'

# copy in custom nginx and set IP to ip address of pot image
< "$TEMPLATEPATH/nginx.conf.in" \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
  sed "s${sep}%%domain%%${sep}$DOMAIN${sep}g" \
  > /usr/local/etc/nginx/nginx.conf

# copy over custom php.ini with long execution time
cp -f "$TEMPLATEPATH/php.ini.in" /usr/local/etc/php.ini

# enable nginx
service nginx enable || true

# enable php-fpm
service php-fpm enable || true
