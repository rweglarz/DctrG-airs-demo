# -------------------------------------------------------------------------------------
# Required variables
# -------------------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
}

variable "gcp_zone" {
  default = null
  description = "GCP zone with GCP Region"
  type = string

}

variable "fw_trust_vpc" {
  type = string
}

variable "airs_api_key" {
  type = string
}

variable "airs_profile_name" {
  type = string
}
