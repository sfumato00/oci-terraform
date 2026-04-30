resource "oci_core_network_security_group" "instances" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_tag}-instances-nsg"

  freeform_tags = local.common_tags
}

# ── Ingress: SSH ────────────────────────────────────────────────────────────

resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  for_each = toset(var.allowed_source_cidrs)

  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# ── Ingress: MUD proxy listener ports ───────────────────────────────────────

resource "oci_core_network_security_group_security_rule" "mud_ingress" {
  for_each = {
    for pair in setproduct(var.allowed_source_cidrs, [for p in var.tcp_proxies : p.listen_port]) :
    "${pair[0]}:${pair[1]}" => { cidr = pair[0], port = pair[1] }
  }

  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = each.value.cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

# ── Ingress: intra-VCN (instance-to-instance) ───────────────────────────────

resource "oci_core_network_security_group_security_rule" "intra_vcn_ingress" {
  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "INGRESS"
  protocol                  = "all"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"
}

# ── Egress: DNS (UDP + TCP port 53) ─────────────────────────────────────────

resource "oci_core_network_security_group_security_rule" "dns_egress_udp" {
  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "EGRESS"
  protocol                  = "17" # UDP

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  udp_options {
    destination_port_range {
      min = 53
      max = 53
    }
  }
}

resource "oci_core_network_security_group_security_rule" "dns_egress_tcp" {
  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 53
      max = 53
    }
  }
}

# ── Egress: HTTP/S (package updates, OCI APIs) ──────────────────────────────

resource "oci_core_network_security_group_security_rule" "http_egress" {
  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "https_egress" {
  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# ── Egress: upstream MUD port ────────────────────────────────────────────────

resource "oci_core_network_security_group_security_rule" "mud_upstream_egress" {
  for_each = {
    for p in var.tcp_proxies :
    "${p.upstream_ip}:${p.upstream_port}" => p
  }

  network_security_group_id = oci_core_network_security_group.instances.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = "${each.value.upstream_ip}/32"
  destination_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = each.value.upstream_port
      max = each.value.upstream_port
    }
  }
}
