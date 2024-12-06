# -------------------------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------------------------
#output "flow_logs_bucket" {
#  value = google_storage_bucket.gcs.name
#}

output "bank_app_unprotected" {
  value = "http://${google_compute_instance.ai_vm_unprotected.network_interface[0].access_config[0].nat_ip}:80"
}

output "bank_api_protected" {
  value = "http://${google_compute_instance.ai_vm_api.network_interface[0].access_config[0].nat_ip}:80"
}

output "gemini_app" {
  value = "http://${google_compute_instance.ai_vm_unprotected.network_interface[0].access_config[0].nat_ip}:8080"
}

}
