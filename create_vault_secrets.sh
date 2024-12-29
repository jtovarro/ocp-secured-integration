#!/bin/bash

# Vault configuration
VAULT_ADDR="$(oc get route hashicorp-vault -n vault --template='https://{{.spec.host}}')"
VAULT_TOKEN="root"                  # Default token in dev mode

# Inline JSON definition of secrets
SECRETS_JSON='[
    {
        "path": "secret/data/demo1",
        "data": {
            "key1": "value1",
            "key2": "value2"
        }
    },
    {
        "path": "secret/data/demo2",
        "data": {
            "key1": "value3",
            "key2": "value4"
        }
    },
    {
        "path": "secret/data/demo3",
        "data": {
            "key1": "value5",
            "key2": "value6"
        }
    }
]'

# Parse JSON and upload secrets
for row in $(echo "$SECRETS_JSON" | jq -c '.[]'); do
    path=$(echo "$row" | jq -r '.path')
    data=$(echo "$row" | jq -c '.data')

    echo "Writing secret to $path"
    curl -s \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        --request POST \
        --data "{\"data\":$data}" \
        "$VAULT_ADDR/v1/$path" > /dev/null

    if [ $? -eq 0 ]; then
        echo "Successfully wrote secret to $path"
    else
        echo "Failed to write secret to $path"
    fi
done
