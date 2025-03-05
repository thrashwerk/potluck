#!/bin/sh

# shellcheck disable=SC1091
. /root/.env.cook

set -e
# shellcheck disable=SC3040
set -o pipefail

SCRIPT=$(readlink -f "$0")
SCRIPTDIR=$(dirname "$SCRIPT")
TEMPLATEPATH=$SCRIPTDIR/../templates

export PATH=/usr/local/bin:"$PATH"
export VAULT_ADDR=https://active.vault.service.consul:8200
export VAULT_CLIENT_TIMEOUT=300s
export VAULT_MAX_RETRIES=5
export VAULT_CLIENT_CERT=/mnt/vaultcerts/agent.crt
export VAULT_CLIENT_KEY=/mnt/vaultcerts/agent.key
export VAULT_CACERT=/mnt/vaultcerts/ca_root.crt
unset VAULT_FORMAT

. "${SCRIPTDIR}/lib.sh"

# real config dir
mkdir -p /usr/local/etc/nginx

# shellcheck disable=SC3003
# safe(r) separator for sed
sep=$'\001'

# Allow Consul and Vault servers to get Nomad client certs
add_id_group_policy "vault-servers" "issue-nomad-client-cert"
add_id_group_policy "consul-servers" "issue-nomad-client-cert"

# Copy over consul-template template for Nomad certs
< "$TEMPLATEPATH/cluster-nomad.tpl.in" \
  sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" | \
  > "/mnt/templates/nomad.tpl"

# Append consul-template config with Nomad template settings
cat << EOF >> /usr/local/etc/consul-template-consul.d/consul-template-consul.hcl

template {
  source      = "/mnt/templates/nomad.tpl"
  destination = "/mnt/nomadcerts/nomad.checksum"
  command     = "service nginx reload nomadproxy; true"
}
EOF

# Copy over Nginx config for Nomad proxy
cp "$TEMPLATEPATH/cluster-nomadproxy.conf.in" \
  /usr/local/etc/nginx/nomadproxy.conf

service nginx enable
sysrc nginx_profiles+="nomadproxy"
sysrc nginx_nomadproxy_configfile="/usr/local/etc/nginx/nomadproxy.conf"

# Start Nomad proxy
timeout --foreground 120 \
  sh -c 'while ! service nginx status nomadproxy; do
    service nginx start nomadproxy || true; sleep 3;
  done'
