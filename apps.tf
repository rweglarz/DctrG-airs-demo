# -------------------------------------------------------------------------------------
# Create VMs
# -------------------------------------------------------------------------------------

# Service account for AI VM.  Needed to reach vertex APIs.
resource "google_service_account" "ai" {
  account_id = "ai-sa-${random_string.main.result}"
  project    = local.project_id
}


# AI Application VM.
resource "google_project_iam_member" "ai" {
  project = local.project_id
  role    = "roles/owner" #"roles/aiplatform.user" #"roles/aiplatform.admin"
  member  = "serviceAccount:${google_service_account.ai.email}"
}

# Create VMs with Apps

resource "google_compute_instance" "ai_vm_unprotected" {
  name         = "ai-vm-unprotected"
  machine_type = "e2-standard-4"
  zone         = local.zone

  boot_disk {
    initialize_params {
      image = local.ai_vm_image
    }
  }

  network_interface {
    subnetwork = module.vpc_gce.subnets_self_links[0]
    network_ip = cidrhost(local.gce_subnet_cidr, 10)
    access_config {}
  }

  service_account {
    email = google_service_account.ai.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  metadata_startup_script = file("${path.module}/startup-script.sh")

  // Required metadata. The values are used to authenticate to vertex APIs.
  metadata = {
    project-id  = local.project_id
    region      = local.region
  }
}


resource "google_compute_instance" "ai-vm-protected" {
  name         = "ai-vm-protected"
  machine_type = "e2-standard-4"
  zone         = local.zone

  boot_disk {
    initialize_params {
      image = local.ai_vm_image
    }
  }

  network_interface {
    subnetwork = module.vpc_gce.subnets_self_links[0]
    network_ip = cidrhost(local.gce_subnet_cidr, 11)
    access_config {}
  }

  service_account {
    email = google_service_account.ai.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  metadata_startup_script = file("${path.module}/startup-script.sh")

  // Required metadata. The values are used to authenticate to vertex APIs.
  metadata = {
    project-id    = local.project_id
    region        = local.region
    is-protected = "true"
  }
}
