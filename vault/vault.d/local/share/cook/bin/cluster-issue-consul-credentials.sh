#!/bin/sh

CERT_NODENAME="$1"
CERT_DATACENTER="$2"

trap "echo \$STEP failed" EXIT

if [ -z "$CERT_NODENAME" ]; then
    2>&1 echo "Usage: $0 cert_nodename [cert_ips] [alt_names] [policies]"
    exit 1
fi

if [ -z "$CERT_IPS" ]; then
    CERT_IPS="127.0.0.1"
fi

if [ -z "$CERT_ALT_NAMES" ]; then
    CERT_ALT_NAMES="localhost,server.$CERT_DATACENTER.consul"
fi

if [ -z "$TOKEN_POLICIES" ]; then
    TOKEN_POLICIES="consul-tls-policy"
fi

TOKEN_POLICIES_PARAMS=""
for policy in $(echo "$TOKEN_POLICIES" | tr ',' ' '); do
    TOKEN_POLICIES_PARAMS="$TOKEN_POLICIES_PARAMS -policy=$policy"
done

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH=/usr/local/bin:$PATH
export VAULT_ADDR=https://active.vault.service.consul:8200
export VAULT_CLIENT_CERT=/mnt/certs/agent.crt
export VAULT_CLIENT_KEY=/mnt/certs/agent.key
export VAULT_CACERT=/mnt/certs/ca_chain.crt
export VAULT_FORMAT=json
STEP="Issue token"
# shellcheck disable=SC2086
TOKEN=$(vault token create \
  $TOKEN_POLICIES_PARAMS -wrap-ttl=300s -ttl=15m \
  | jq -e ".wrap_info.token")
STEP="Get root CA"
CA_ROOT=$(vault read consulpki/cert/ca | jq -e ".data.certificate")
STEP="Issue Client Certificate"
CERT_JSON=$(vault write consulpki_int/issue/consul-cluster \
  common_name="$CERT_NODENAME.$CERT_DATACENTER.consul" \
  ttl=10m \
  alt_names="$CERT_ALT_NAMES" \
  ip_sans="$CERT_IPS")

STEP="Parse Client Certificate"
CERT=$(echo "$CERT_JSON" | jq -e ".data.certificate")
KEY=$(echo "$CERT_JSON" | jq -e ".data.private_key")
CA=$(echo "$CERT_JSON" | jq -e ".data.issuing_ca")
CA_CHAIN=$(
  echo "$CERT_JSON" | jq -ec ".data.ca_chain[]"
)

STEP="Assemble response"
echo "{
  \"wrapped_token\": $TOKEN,
  \"cert\": $CERT,
  \"key\": $KEY,
  \"ca\": $CA,
  \"ca_chain\": $CA_CHAIN,
  \"ca_root\": $CA_ROOT
}"  | jq

trap - EXIT