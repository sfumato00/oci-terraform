variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment where the state bucket will be created."
  type        = string
}

variable "region" {
  description = "OCI home region identifier (e.g. us-ashburn-1)."
  type        = string
}

variable "oci_config_profile" {
  description = "Profile name in ~/.oci/config."
  type        = string
  default     = "DEFAULT"
}

variable "oci_auth" {
  description = "OCI provider authentication method."
  type        = string
  default     = "APIKey"

  validation {
    condition     = contains(["APIKey", "SecurityToken", "InstancePrincipal", "ResourcePrincipal", "OKEWorkloadIdentity"], var.oci_auth)
    error_message = "oci_auth must be one of APIKey, SecurityToken, InstancePrincipal, ResourcePrincipal, or OKEWorkloadIdentity."
  }
}

variable "bucket_name" {
  description = "Name for the Object Storage bucket that holds Terraform state."
  type        = string
  default     = "tlbb-terraform-state"
}

variable "state_user_ocid" {
  description = "OCID of the IAM user or instance principal that will read/write state. Leave empty to skip IAM policy creation."
  type        = string
  default     = ""
}

variable "project_tag" {
  description = "Value for the 'project' freeform tag applied to all resources."
  type        = string
  default     = "tlbb-mud-proxy"
}
