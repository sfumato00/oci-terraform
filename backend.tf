# Copy this file to the main stack root as backend.tf and fill in the values
# from `terraform -chdir=bootstrap output`.
#
# Then run:
#   terraform init -migrate-state
#
# Terraform backends cannot reference input variables, so values must be
# hardcoded here (or supplied via -backend-config flags / a .tfbackend file).

terraform {
  backend "oci" {
    auth                = "SecurityToken"
    config_file_profile = "tlbb"

    # From: terraform -chdir=bootstrap output region
    region = "ap-chuncheon-1"

    # From: terraform -chdir=bootstrap output bucket_namespace
    namespace = "axg4yq5nfjj2"

    # From: terraform -chdir=bootstrap output bucket_name
    bucket = "tlbb-terraform-state"

    # Path within the bucket for this root's state object.
    key = "terraform.tfstate"
  }
}
