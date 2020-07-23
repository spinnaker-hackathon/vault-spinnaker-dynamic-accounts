Terraform readme: #
Before spinning up cluster you need generated terraform.json file. This has to be a direct file location because it is needed before interpolation. Look at 'terraform.tfvars'
Also Vault token should be exported 'export VAULT_TOKEN='


# README #

## Terraform GKE spin.

### Description

Terraform script, who spin up GKE cluster, output host endpoint and sends to hashicorp vault for futher usage with Spinnaker dynamic env.

### Variables

| Name | Type | Default value | Description  |
|---|---|---|---|
| **terraform_account** | *string* | "terraform-account" | terraform account name |
| **gcp_project** | *string* | "cs-spingo1" | GCP project name |
| **cluster_name** | *string* | "my-gke-cluster" | Kubernetes cluster name |
| **gcp_region** | *string* | "us-east1" | GCP region name |
| **service_account_name** | *string* | "cs-spingo1" | Service account name |
| **service_account_namespace** | *string* | "default" | Service account namespace |
| **host** | *string* | "new-cluster" | k8s hostname |

### Outputs

| Name | Type | Description  |
|---|---|---|
| **token** | *string* | Kubernetes service account token |
| **host** | *string* | Kubernetes endpoint |
| **host** | *string* | Kubernetes endpoint |
| **ca_certificate** | *string* | Kubernetes certificate |
### Providers

| Name | Description  |
|---|---|
| **google** | Google cloud provider |
| **google-beta** | Google cloud provider |
| **vault** | Hashicorp vault provider |
| **kubernetes** | kubernetes provider |

 ### Goals

* Do not hardcode anything
* Create reusable modules
* Use standard directory structure:
    * data.tf
    * locals.tf
    * main.tf
    * modules.tf
    * outputs.tf
    * terraform.tfvars (if required)
    * variables.tf
