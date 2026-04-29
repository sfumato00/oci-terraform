output "bucket_name" {
  description = "Name of the Object Storage bucket holding Terraform state."
  value       = oci_objectstorage_bucket.tfstate.name
}

output "bucket_namespace" {
  description = "Object Storage namespace (tenancy name). Required for the oci backend config."
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "region" {
  description = "OCI region where the bucket was created."
  value       = var.region
}

output "backend_snippet" {
  description = "Paste this into the main stack's backend.tf (fill in the state_file path)."
  value       = <<-EOT
    terraform {
      backend "oci" {
        auth                = "${var.oci_auth}"
        config_file_profile = "${var.oci_config_profile}"
        region              = "${var.region}"
        namespace           = "${data.oci_objectstorage_namespace.ns.namespace}"
        bucket              = "${oci_objectstorage_bucket.tfstate.name}"
        key                 = "terraform.tfstate"
      }
    }
  EOT
}
