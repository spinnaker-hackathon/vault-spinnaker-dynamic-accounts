# vault-spinnaker-dynamic-accounts

## Introduction

The following instructions have been created to allow a Spinnaker Operator to configure their Spinnaker deployment to utilize dynamic accounts through HashCorp Vault as well as tha ability to add new accounts using a collection of a Run Job Manifest turned into Custom Job Stage and Pipelines designed specifically for the Spinnaker Operators to use to add new accounts without having to re-deploy Spinnaker through Halyard and able to utilize through automation!

## Prerequisites

1. Have HashiCorp Vault up and running with Vault Agent Injector or use the [Relatively easy Vault-Helm Example Installation](#relatively-easy-vault-helm-example-installation)
1. Have Spinnaker up and running

### Relatively easy Vault-Helm Example Installation

#### Description

The included vault-helm values file will setup a vault server in HA mode with Raft as the backend. It is not ideal for production due to the secrets being stored in the cluster rather than stored externally but good enough to see how to "connect the lego pieces" and continue with the demonstration

#### Instructions

Create the vault namespace

`kubectl create ns vault`

Load your TLS certs into a secret into the vault namespace (you can get this from Let's Encrypt *outside the scope of this tutorial)

```sh
cat <<SECRET_EOF | kubectl -n vault apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-tls
  namespace: vault
type: Opaque
data:
  vault.pem: $(cat /path/to/certbot/cert_wildcard.crt | base64 -w 0)
  vault.key: $(cat /path/to/certbot/cert_wildcard.key | base64 -w 0)
SECRET_EOF
```

Install helm locally

`brew install helm`

Add HashiCorp repo to local Helm installation

`helm repo add hashicorp https://helm.releases.hashicorp.com`

Modify the example helm values file to suit your needs then install the helm chart

```sh
helm install vault hashicorp/vault \
  --version 0.6.0 \
  --values=example-vault-helm-values/vault-helm-values.yml \
  --namespace vault
```

Follow the rest of the setup instruction from [here](https://www.vaultproject.io/docs/platform/k8s/helm/examples/ha-with-raft#highly-available-vault-cluster-with-integrated-storage-raft) (after the install command) to complete the Vault configuration. IMPORTANT NOTE: Make sure you keep the unseal keys and the initial root token safe because you will need that!

You now have a vault server up and running, congrats!

### Setup Kubernetes Authentication within Vault

#### Description

The following commands are mostly pulled from [this location](https://docs.armory.io/docs/spinnaker-install-admin-guides/secrets/vault-k8s-configuration/)

Setup environment variables for VAULT_ADDR and VAULT_TOKEN to point to your vault installation

Assumption is kubectl is configured to point to your Spinnaker deployment cluster

Note: We use `jq` for convenience below but you could just as well grab the results from the vault output

#### Vault Kubernetes Authentication Installation Instructions

You may need to log into your vault if you haven't already

`vault login`

Create the vault-auth service account that Vault will use to verify the authenticity of kubernetes service accounts

```sh
kubectl -n default \
  create serviceaccount vault-auth
```

Setup Cluster Role Binding to allow vault to validate any kubernetes service account in any namespace

```sh
cat << VAULT_AUTH_SVC_ACCT | kubectl -n default apply --filename -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: default
VAULT_AUTH_SVC_ACCT
```

Enable the Kubernetes authentication for Vault

```sh
vault auth enable \
    --path="kubernetes-spinnaker" \
    kubernetes
```

Create the vault secret location for dynamic accounts

```sh
vault secrets enable \
    -version=1 \
    -path="secret" \
    -default-lease-ttl=0 \
    -max-lease-ttl=0 \
    kv
```

##### Create policies for dynamic accounts

Create read-write vault policy for dynamic accounts

```sh
cat << VAULT_POLICY | vault policy write dynamic_accounts_ro_policy -
# For K/V v1 secrets engine
path "secret/dynamic_accounts/*" {
    capabilities = ["read", "list"]
}
# For K/V v2 secrets engine
path "secret/data/dynamic_accounts/*" {
    capabilities = ["read", "list"]
}
VAULT_POLICY
```

Create read-write vault policy for dynamic accounts

```sh
cat << VAULT_POLICY | vault policy write dynamic_accounts_rw_policy -
# For K/V v1 secrets engine
path "secret/dynamic_accounts/*" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
# For K/V v2 secrets engine
path "secret/data/dynamic_accounts/*" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
VAULT_POLICY
```

Enable approle authentication within Vault to generate token to be used by Spinnaker to access the dynamic accounts secret (NEVER USE THE ROOT TOKEN FOR ANYTHING OTHER THAN SETTING UP BETTER OPTIONS) and for approle to be used by 

```sh
vault auth enable approle
```

#### Create read-only app role for Spinnaker

```sh
vault write \
    auth/approle/role/dynamic_accounts_ro_role \
    token_policies="dynamic_accounts_ro_policy" \
    token_max_ttl="1600h" \
    token_num_uses=0 \
    secret_id_num_uses=0
```
Get role-id for dynamic accounts read-only approle

```sh
vault read -format=json auth/approle/role/dynamic_accounts_ro_role/role-id \
    | jq -r '.data.role_id' > .dynamic-accounts-ro-role-id
```

Get secret-id for dynamic accounts read-only approle

```sh
vault write -format=json -force auth/approle/role/dynamic_accounts_ro_role/secret-id \
    | jq -r '.data.secret_id' > .dynamic-accounts-ro-role-secret-id
```

Get a token for the read-only approle by using the role-id and the secret-id

```sh
vault write \
    -format=json auth/approle/login \
    role_id="$(cat .dynamic-accounts-ro-role-id)" \
    secret_id="$(cat .dynamic-accounts-ro-role-secret-id)" \
    | jq -r '.auth.client_token' > .dynamic-accounts-ro-token
```

#### Create read-write approle for Spinnaker

```sh
vault write \
    auth/approle/role/dynamic_accounts_rw_role \
    token_policies="dynamic_accounts_rw_policy" \
    token_max_ttl="1600h" \
    token_num_uses=0 \
    secret_id_num_uses=0
```
Get role-id for dynamic accounts read-write approle

```sh
vault read -format=json auth/approle/role/dynamic_accounts_rw_role/role-id \
    | jq -r '.data.role_id' > .dynamic-accounts-rw-role-id
```

Get secret-id for dynamic accounts read-write approle

```sh
vault write -format=json -force auth/approle/role/dynamic_accounts_rw_role/secret-id \
    | jq -r '.data.secret_id' > .dynamic-accounts-rw-role-secret-id
```

Get a token for the read-write approle by using the role-id and the secret-id

```sh
vault write \
    -format=json auth/approle/login \
    role_id="$(cat .dynamic-accounts-rw-role-id)" \
    secret_id="$(cat .dynamic-accounts-rw-role-secret-id)" \
    | jq -r '.auth.client_token' > .dynamic-accounts-rw-token
```
