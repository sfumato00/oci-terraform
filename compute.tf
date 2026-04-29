locals {
  ad_count = length(data.oci_identity_availability_domains.ads.availability_domains)

  # Per-instance derived values indexed by position.
  instance_ads = [
    for i in range(var.instance_count) :
    var.availability_domain_strategy == "spread"
    ? data.oci_identity_availability_domains.ads.availability_domains[i % local.ad_count].name
    : data.oci_identity_availability_domains.ads.availability_domains[0].name
  ]

  # 10.42.1.11 – 10.42.1.14 (within the public subnet 10.42.1.0/24).
  instance_ips   = [for i in range(var.instance_count) : "10.42.1.${11 + i}"]
  instance_names = [for i in range(var.instance_count) : format("mud-proxy-%02d", i + 1)]
}

resource "oci_core_instance" "mud_proxy" {
  count = var.instance_count

  availability_domain = local.instance_ads[count.index]
  compartment_id      = var.compartment_ocid
  display_name        = local.instance_names[count.index]
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpu_per_instance
    memory_in_gbs = var.memory_gb_per_instance
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_aarch64.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "${local.instance_names[count.index]}-vnic"
    hostname_label   = local.instance_names[count.index]
    private_ip       = local.instance_ips[count.index]
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.instances.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  freeform_tags = local.common_tags

  # Always Free A1 guardrails — fail plan rather than accumulate charges.
  lifecycle {
    precondition {
      condition     = var.instance_count * var.ocpu_per_instance <= 4
      error_message = "Total OCPUs (instance_count × ocpu_per_instance) exceeds the Always Free A1 limit of 4."
    }
    precondition {
      condition     = var.instance_count * var.memory_gb_per_instance <= 24
      error_message = "Total memory (instance_count × memory_gb_per_instance) exceeds the Always Free A1 limit of 24 GB."
    }
    precondition {
      condition     = var.instance_count * var.boot_volume_gb <= 200
      error_message = "Total storage (instance_count × boot_volume_gb) exceeds the Always Free block volume limit of 200 GB."
    }
  }
}
