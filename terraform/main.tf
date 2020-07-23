provider "vault" {
}


provider "google" {
  credentials = file("${var.terraform_account}.json")
  project     = var.gcp_project
  version     = "~> 2.8"
}

provider "google" {
  alias       = "dns-zone"
  credentials = file("${var.terraform_account}.json")  
  project     = var.managed_dns_gcp_project
  version     = "~> 2.8"
}

provider "google-beta" {
  credentials = file("${var.terraform_account}.json")  
  project     = var.gcp_project
  version     = "~> 2.8"
}

resource "random_string" "random" {
  length = 16
  special = false
}

resource "vault_generic_secret" "dynamic_accounts" {
  path = "secret/dynamic_accounts/intake/new_cluster"
  data_json = <<EOT
  {
    "ca_cert": "${google_container_cluster.kube-cluster.master_auth.0.cluster_ca_certificate}",
    "k8s_host": "${google_container_cluster.kube-cluster.endpoint}",
    "k8s_name": "${var.gcp_project}",
    "k8s_username": "${kubernetes_service_account.service_account.metadata[0].name}",
    "user_token": "${data.kubernetes_secret.service_account_data.data.token}"
  }
  EOT
  }

data "google_client_config" "default" {
    provider                      = google-beta
}

provider "kubernetes" {
  load_config_file       = false
  host                   = google_container_cluster.kube-cluster.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.kube-cluster.master_auth.0.cluster_ca_certificate)
}
resource "google_container_cluster" "kube-cluster" {
  name     = "my-gke-cluster" //this is the name in console
  location = var.gcp_region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  
  master_auth {
    username = random_string.random.result
    password = random_string.random.result

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "cluster-nodes" {
  name       = "my-gke-cluster-node-pool"
  location   = var.gcp_region
  cluster    = google_container_cluster.kube-cluster.name
  node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
  node_config {
    preemptible  = true
    machine_type = "e2-small"

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}


resource "kubernetes_service_account" "service_account" {

  metadata {
    name      = var.service_account_name
    namespace = var.service_account_namespace
  }
  automount_service_account_token = "true"
  secret {
    name = data.google_client_config.default.access_token
  }
}

resource "kubernetes_cluster_role_binding" "cluster_role_binding" {

  metadata {
    name = "${var.service_account_name}-cluster-role"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.service_account_name
    namespace = var.service_account_namespace
    api_group = ""
  }

  depends_on = [kubernetes_service_account.service_account]
}

data "kubernetes_secret" "service_account_data" {

  metadata {
    name      = kubernetes_service_account.service_account.default_secret_name
    namespace = kubernetes_service_account.service_account.metadata[0].namespace
  }
}


# output "ca_certificate" {
#   value     = "${google_container_cluster.kube-cluster.master_auth.0.cluster_ca_certificate}"
#  sensitive = false
# }
# output "host" {
#   value     = "${google_container_cluster.kube-cluster.endpoint}"
#  sensitive = false
# }
# output "token" {
#   value     = "${data.kubernetes_secret.service_account_data.data.token}"
#  sensitive = false
# }