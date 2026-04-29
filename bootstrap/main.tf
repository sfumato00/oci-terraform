terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
  # Local state intentionally — this root creates the remote state bucket.
  # After apply, migrate the main stack to the oci backend.
}

provider "oci" {
  auth                = var.oci_auth
  tenancy_ocid        = var.tenancy_ocid
  region              = var.region
  config_file_profile = var.oci_config_profile
}

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.bucket_name

  # Versioning lets the oci backend store state revisions and enables locking.
  versioning = "Enabled"

  # Server-side encryption with OCI-managed keys (always free).
  kms_key_id = null

  freeform_tags = {
    project = var.project_tag
    managed = "terraform"
  }
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

# IAM policy granting the specified user manage access to the state bucket.
# Skipped when state_user_ocid is empty (e.g. when using instance principals).
resource "oci_identity_policy" "tfstate" {
  count = var.state_user_ocid != "" ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = "${var.project_tag}-tfstate-access"
  description    = "Allows the Terraform operator to manage the remote state bucket."

  statements = [
    "Allow user ${var.state_user_ocid} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name='${var.bucket_name}'",
    "Allow user ${var.state_user_ocid} to manage buckets in compartment id ${var.compartment_ocid} where target.bucket.name='${var.bucket_name}'",
  ]

  freeform_tags = {
    project = var.project_tag
    managed = "terraform"
  }
}
