# -------------------------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------------------------
output "flow_logs_bucket" {
  value = google_storage_bucket.gcs.name
}

output "bank_app_unprotected" {
    value = "http://${google_compute_instance.ai_vm_unprotected.network_interface[0].access_config[0].nat_ip}:80" 
}

output "bank_app_protected" {
  value = "http://${google_compute_instance.ai_vm_protected.network_interface[0].access_config[0].nat_ip}:8888"
}

output "gemini_app" {
  value = "http://${google_compute_instance.ai_vm_unprotected.network_interface[0].access_config[0].nat_ip}:8080" 
}

output "SET_ENV_VARS" {
  value = <<EOF
export PROJECT_ID=${local.project_id}
export REGION=${local.region}
export ZONE=${google_compute_instance.ai_vm_unprotected.zone}
EOF
}
