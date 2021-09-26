#!/bin/sh
#export VAULT_ADDR=https://active.vault.service.consul:8200
export PATH=/usr/local/bin:$PATH
export VAULT_CLIENT_TIMEOUT=300s
export VAULT_MAX_RETRIES=5
export VAULT_CLIENT_CERT=/mnt/certs/agent.crt
export VAULT_CLIENT_KEY=/mnt/certs/agent.key
export VAULT_CACERT=/mnt/certs/ca_chain.crt
vault "$@"
