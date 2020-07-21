# vault-spinnaker-dynamic-accounts

## Introduction

The following instructions have been created to allow a Spinnaker Operator to configure their Spinnaker deployment to utilize dynamic accounts through HashCorp Vault as well as tha ability to add new accounts using a collection of Run Job Manifests turned into Custom Job Stages and Pipelines specifically for the Spinnaker Operators to use to add new accounts without having to re-deploy Spinnaker through Halyard.

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

TBD