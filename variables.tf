variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment where all resources will be created."
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

variable "environment" {
  description = "Environment label applied to all resource tags (e.g. prod, dev)."
  type        = string
  default     = "prod"
}

variable "project_tag" {
  description = "Value for the 'project' freeform tag applied to all resources."
  type        = string
  default     = "tlbb-mud-proxy"
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the regional public subnet."
  type        = string
  default     = "10.42.1.0/24"
}

# ── NSG / access control ────────────────────────────────────────────────────

variable "allowed_source_cidrs" {
  description = "CIDRs allowed to reach SSH and MUD proxy ports. Required; no default."
  type        = list(string)

  validation {
    condition     = length(var.allowed_source_cidrs) > 0
    error_message = "allowed_source_cidrs must contain at least one CIDR. Do not leave this empty."
  }
}

variable "nginx_reverse_proxies" {
  description = "Explicit list of TCP proxy mappings. Each entry binds one listen port to one upstream."
  type = list(object({
    listen_port   = number
    upstream_host = string
    upstream_ip   = string
    upstream_port = number
  }))
  default = []
}

# ── Compute ──────────────────────────────────────────────────────────────────

variable "ssh_public_key" {
  description = "SSH public key material placed in authorized_keys on each instance."
  type        = string
  sensitive   = true
}

variable "instance_count" {
  description = "Number of A1 Flex instances to create (1–4; Always Free cap is 4 total OCPUs / 24 GB)."
  type        = number
  default     = 4

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 4
    error_message = "instance_count must be between 1 and 4."
  }
}

variable "ocpu_per_instance" {
  description = "OCPU count per A1 Flex instance."
  type        = number
  default     = 1
}

variable "memory_gb_per_instance" {
  description = "Memory in GB per A1 Flex instance."
  type        = number
  default     = 6
}

variable "boot_volume_gb" {
  description = "Boot volume size in GB per instance (default 50 GB × 4 = 200 GB Always Free limit)."
  type        = number
  default     = 50
}

variable "availability_domain_strategy" {
  description = "Placement strategy: 'spread' distributes instances across ADs round-robin; 'single' puts all in AD[0]. Use 'single' for single-AD regions."
  type        = string
  default     = "spread"

  validation {
    condition     = contains(["spread", "single"], var.availability_domain_strategy)
    error_message = "availability_domain_strategy must be 'spread' or 'single'."
  }
}