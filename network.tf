resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_tag}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = "tlbbmud"

  freeform_tags = local.common_tags
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_tag}-igw"
  enabled        = true

  freeform_tags = local.common_tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_tag}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }

  freeform_tags = local.common_tags
}

# Minimal security list — workload rules live in the NSG.
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_tag}-public-sl"

  # Allow all outbound by default; NSG rules layer on top for workload egress.
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # ICMP type 3 (destination unreachable) from anywhere — needed for path MTU.
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"

    icmp_options {
      type = 3
    }
  }

  # ICMP type 3 code 4 (fragmentation needed) from inside the VCN.
  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr

    icmp_options {
      type = 3
      code = 4
    }
  }

  freeform_tags = local.common_tags
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  display_name      = "${var.project_tag}-public-subnet"
  cidr_block        = var.public_subnet_cidr
  dns_label         = "pub"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.public.id]

  # Public subnet — instances get public IPs assigned at launch.
  prohibit_public_ip_on_vnic = false

  freeform_tags = local.common_tags
}
