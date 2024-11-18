# -------------------------------------------------------------------------------------
# Locals
# -------------------------------------------------------------------------------------

locals {
  project_id               = var.gcp_project_id
  region                   = var.gcp_region
  zone                     = var.gcp_zone
  airs_name                = "airs-${substr(random_string.main.result, 0, 4)}"
  ai_vm_image              = var.ai_vm_image
  gce_subnet_name          = "gce-vpc-${local.region}-subnet"
  gce_subnet_cidr          = "10.1.0.0/24"
}

# -------------------------------------------------------------------------------------
# Provider
# -------------------------------------------------------------------------------------

terraform {

  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
  zone    = local.zone
}

# Basic services
resource "google_project_service" "basic" {
  for_each = toset([
    "compute.googleapis.com",
    "logging.googleapis.com",
    "cloudbilling.googleapis.com",
    "storage.googleapis.com"
  ])
  
  project = "airs-demo-emeal"
  service = each.key
  disable_on_destroy = false
  depends_on = [google_project_service.core]
}

# Advanced services
resource "google_project_service" "advanced" {
  for_each = toset([
    "apikeys.googleapis.com",
    "notebooks.googleapis.com",
    "artifactregistry.googleapis.com",
    "dataplex.googleapis.com",
    "datacatalog.googleapis.com",
    "visionai.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudasset.googleapis.com"
  ])
  
  project = "airs-demo-emeal"
  service = each.key
  disable_on_destroy = false
  depends_on = [google_project_service.basic]
}

# -------------------------------------------------------------------------------------
# Create GSC bucket & log router for VPC flow logs
# -------------------------------------------------------------------------------------

resource "random_string" "main" {
  length      = 16
  min_lower   = 8
  min_numeric = 8
  special     = false
}

resource "google_storage_bucket" "gcs" {
  name          = "flow-logs-${random_string.main.result}"
  location      = "US"
  force_destroy = true
}

resource "google_logging_project_sink" "log_router" {
  name                   = "flow-logs-sink"
  destination            = "storage.googleapis.com/${google_storage_bucket.gcs.name}"
  filter                 = "(logName =~ \"logs/cloudaudit.googleapis.com%2Fdata_access\" AND protoPayload.methodName:(\"google.cloud.aiplatform.\")) OR ((logName=\"projects/${local.project_id}/logs/compute.googleapis.com%2Fvpc_flows\"))"
  unique_writer_identity = true

  depends_on = [
    google_storage_bucket.gcs
  ]
}

resource "google_project_iam_binding" "gcs-bucket-writer" {
  project = local.project_id
  role    = "roles/storage.objectCreator"

  members = [
    google_logging_project_sink.log_router.writer_identity
  ]
}

resource "google_project_iam_audit_config" "all_services" {
  project = local.project_id
  service = "allServices"
  audit_log_config { log_type = "ADMIN_READ" }
  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
}


resource "google_project_iam_audit_config" "ai_platform" {
  project = local.project_id
  service = "aiplatform.googleapis.com"
  audit_log_config { log_type = "ADMIN_READ" }
  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
}


# -------------------------------------------------------------------------------------
# Create VPCs
# -------------------------------------------------------------------------------------

module "vpc_gce" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 4.0"
  project_id   = local.project_id
  network_name = "gce-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name               = local.gce_subnet_name
      subnet_ip                 = local.gce_subnet_cidr
      subnet_region             = local.region
      subnet_flow_logs          = "true"
      subnet_flow_logs_interval = "INTERVAL_5_SEC"
      subnet_flow_logs_sampling = 1.0
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
      subnet_flow_logs_filter   = "false"
    }
  ]

  firewall_rules = [
    {
      name      = "gce-vpc-ingress-all"
      direction = "INGRESS"
      priority  = "100"
      ranges    = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "all"
          ports    = []
        }
      ]
    }
  ]
  depends_on = [
    google_storage_bucket.gcs
  ]
}

