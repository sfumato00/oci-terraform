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

variable "allowed_tcp_ports" {
  description = "TCP ports the MUD proxy listens on (opened to allowed_source_cidrs)."
  type        = list(number)
  default     = [23]
}

variable "mud_upstream_host" {
  description = "Hostname or IP of the upstream MUD/game server."
  type        = string
}

variable "mud_upstream_port" {
  description = "TCP port of the upstream MUD/game server."
  type        = number
}

variable "mud_upstream_cidrs" {
  description = "Optional list of CIDRs for the upstream MUD server. When set, egress to the upstream port is restricted to these CIDRs. When empty, broader egress is allowed because OCI NSGs cannot target hostnames."
  type        = list(string)
  default     = []
}
