#!/bin/bash

die() { echo "$*" 1>&2 ; exit 1; }

if [ -z "$VAULT_DYNAMIC_ACCOUNT_SECRET_LOCATION" ]; then
    die "Need vault dynamic account secret location VAULT_DYNAMIC_ACCOUNT_SECRET_LOCATION to continue"
fi

if [ -z "$VAULT_INTAKE_ACCOUNT_SECRET_LOCATION" ]; then
    die "Need vault intake account secret location VAULT_INTAKE_ACCOUNT_SECRET_LOCATION to continue"
fi

if [ -z "$READ_PERMISSIONS" ]; then
    die "Need at least 1 comma separated read permission role(s) READ_PERMISSIONS to continue"
fi

if [ -z "$WRITE_PERMISSIONS" ]; then
    die "Need at least 1 comma separated write permission role(s) WRITE_PERMISSIONS to continue"
fi

if [ -z "$VAULT_HOME" ]; then
    die "Need the url of vault set VAULT_HOME to continue"
fi

SVC_JWT="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
VAULT_TOKEN="$(curl -s --request POST --data '{"jwt":"'"$SVC_JWT"'","role":"dynamic-account-rw-role"}' "$VAULT_HOME"/v1/auth/kubernetes-spinnaker/login | jq -r '.auth.client_token')"

./vault login -no-print=true "$VAULT_TOKEN" 
./vault read -format=json "$VAULT_DYNAMIC_ACCOUNT_SECRET_LOCATION" | jq -r '.data' > account-list.json

./vault read -format=json "$VAULT_INTAKE_ACCOUNT_SECRET_LOCATION" | jq -r '.data' > new-account.json

ACCOUNT_LIST="$(< account-list.json)"
NEW_ACCOUNT="$(< new-account.json)"
CA_CERT="$( echo "$NEW_ACCOUNT" | jq -r '.ca_cert')"
K8S_HOST="$( echo "$NEW_ACCOUNT" | jq -r '.k8s_host')"
K8S_NAME="$( echo "$NEW_ACCOUNT" | jq -r '.k8s_name')"
K8S_USERNAME="$( echo "$NEW_ACCOUNT" | jq -r '.k8s_username')"
USER_TOKEN="$( echo "$NEW_ACCOUNT" | jq -r '.user_token')"
FORMATTED_NEW_ACCOUNT_CONTENTS="apiVersion: v1\nclusters:\n- cluster:\n    certificate-authority-data: $CA_CERT\n    server: $K8S_HOST\n  name: $K8S_NAME\ncontexts:\n- context:\n    cluster: $K8S_NAME\n    namespace: default\n    user: $K8S_USERNAME\n  name: $K8S_NAME\ncurrent-context: $K8S_NAME\nkind: Config\npreferences: {}\nusers:\n- name: $K8S_USERNAME\n  user:\n    token: $USER_TOKEN"

cat <<EOF > new-template-account.json
{
  "name": "$K8S_NAME",
  "requiredGroupMembership": [],
  "providerVersion": "V2",
  "permissions": {
    "READ": [
      $(echo "$READ_PERMISSIONS" | sed 's/,/\",\"/g' | sed 's/^/\"/g' | sed 's/$/\"/g')
    ],
    "WRITE": [
      $(echo "$WRITE_PERMISSIONS" | sed 's/,/\",\"/g' | sed 's/^/\"/g' | sed 's/$/\"/g')
    ]
  },
  "dockerRegistries": [
    {
      "accountName": "docker-registry",
      "namespaces": []
    }
  ],
  "configureImagePullSecrets": true,
  "cacheThreads": 1,
  "namespaces": [],
  "omitNamespaces": [],
  "kinds": [],
  "omitKinds": [],
  "customResources": [],
  "cachingPolicies": [],
  "oAuthScopes": [],
  "onlySpinnakerManaged": true,
  "kubeconfigContents": "$FORMATTED_NEW_ACCOUNT_CONTENTS"
}

EOF

NEW_ACCOUNT_JSON="$(< new-template-account.json)"

NEW_COMPLETE_ACCOUNT_LIST="$(echo "$ACCOUNT_LIST" | jq --argjson acct "$NEW_ACCOUNT_JSON" -r '.kubernetes.accounts += [$acct]')"

echo "$NEW_COMPLETE_ACCOUNT_LIST" | ./vault kv put "$VAULT_DYNAMIC_ACCOUNT_SECRET_LOCATION" -

if [ "$?" -eq 0 ]; then
    echo "SPINNAKER_PROPERTY_ADD_ACCOUNT_STATUS=SUCCESS"
else
    echo "SPINNAKER_PROPERTY_ADD_ACCOUNT_STATUS=FAILED"
fi
echo "SPINNAKER_PROPERTY_NEW_ACCOUNT_NAME=$K8S_NAME"
