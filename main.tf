terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  # Backend is configured in backend.tf (copied from bootstrap/backend.tf.example).
  # Run: terraform init -migrate-state  after creating backend.tf.
}

provider "oci" {
  auth                = var.oci_auth
  tenancy_ocid        = var.tenancy_ocid
  region              = var.region
  config_file_profile = var.oci_config_profile
}

locals {
  common_tags = {
    project     = var.project_tag
    environment = var.environment
    managed     = "terraform"
  }
}
