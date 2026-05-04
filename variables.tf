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

variable "instance_shape" {
  description = "Shape of the Always Free A1 Flex instances."
  type        = string
  default     = "VM.Standard.A1.Flex"

  validation {
    condition     = var.instance_shape == "VM.Standard.A1.Flex"
    error_message = "This stack is constrained to VM.Standard.A1.Flex because image selection and Always Free guardrails are A1-specific."
  }
}

variable "instance_count" {
  description = "Number of A1 Flex instances to create when instance_numbers is unset (1-4; Always Free cap is 4 total OCPUs / 24 GB)."
  type        = number
  default     = 4

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 4
    error_message = "instance_count must be between 1 and 4."
  }
}

variable "instance_numbers" {
  description = "Stable mud-proxy numeric suffixes to manage. Use [2, 3, 4] to keep mud-proxy-02 through mud-proxy-04 while removing mud-proxy-01."
  type        = list(number)
  default     = null

  validation {
    condition = (
      var.instance_numbers == null ||
      (
        length(var.instance_numbers) >= 1 &&
        length(var.instance_numbers) <= 4 &&
        length(distinct(var.instance_numbers)) == length(var.instance_numbers) &&
        alltrue([for n in var.instance_numbers : n >= 1 && n <= 4])
      )
    )
    error_message = "instance_numbers must contain unique values between 1 and 4."
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

  validation {
    condition     = (var.instance_numbers == null ? var.instance_count : length(var.instance_numbers)) * var.memory_gb_per_instance <= 24
    error_message = "total memory must not exceed 24 GB"
  }
}

variable "boot_volume_gb" {
  description = "Boot volume size in GB per instance (default 50 GB × 4 = 200 GB Always Free limit)."
  type        = number
  default     = 50

  validation {
    condition     = (var.instance_numbers == null ? var.instance_count : length(var.instance_numbers)) * var.boot_volume_gb <= 200
    error_message = "total boot_volume_gb must not exeed 200"
  }
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

# ── Observability ─────────────────────────────────────────────────────────────

variable "alarm_email" {
  description = "Email address for alarm notifications. Leave empty to suppress email delivery (alarms still visible in OCI Monitoring console)."
  type        = string
  default     = ""
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization percentage that triggers the high-CPU alarm."
  type        = number
  default     = 80
}

variable "enable_flow_logs" {
  description = "Enable VCN subnet flow logs. Off by default; consumes OCI Always Free 10 GB/month logging quota."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Retention in days for VCN flow logs when enabled. Shorter values reduce log ingestion against the free quota."
  type        = number
  default     = 30
}
