locals {
  ad_count = length(data.oci_identity_availability_domains.ads.availability_domains)

  # Per-instance derived values indexed by position.
  instance_ads = [
    for i in range(var.instance_count) :
    var.availability_domain_strategy == "spread"
    ? data.oci_identity_availability_domains.ads.availability_domains[i % local.ad_count].name
    : data.oci_identity_availability_domains.ads.availability_domains[0].name
  ]

  # Stable private IPs starting at host .11 within the configured public subnet.
  instance_ips   = [for i in range(var.instance_count) : cidrhost(var.public_subnet_cidr, 11 + i)]
  instance_names = [for i in range(var.instance_count) : format("mud-proxy-%02d", i + 1)]

  # Nginx stream config: rendered from a template for direct top-level inclusion.
  nginx_stream_config = templatefile(
    "${path.module}/templates/nginx-stream.conf.tpl",
    {
      nginx_reverse_proxies = var.nginx_reverse_proxies
    }
  )

  nginx_config = file("${path.module}/templates/nginx.conf")

  cloud_init_userdata = base64encode(templatefile(
    "${path.module}/templates/cloud-init.yaml.tpl",
    {
      nginx_config_b64        = base64encode(local.nginx_config)
      nginx_proxy_ports_csv   = join(",", [for p in var.nginx_reverse_proxies : tostring(p.listen_port)])
      nginx_stream_config_b64 = base64encode(local.nginx_stream_config)
    }
  ))
}

resource "oci_core_instance" "mud_proxy" {
  count = var.instance_count

  availability_domain = local.instance_ads[count.index]
  compartment_id      = var.compartment_ocid
  display_name        = local.instance_names[count.index]
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.ocpu_per_instance
    memory_in_gbs = var.memory_gb_per_instance
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_aarch64.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  launch_options {
    is_pv_encryption_in_transit_enabled = true
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
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
    user_data           = local.cloud_init_userdata
  }

  freeform_tags = local.common_tags

  # Always Free A1 guardrails — fail plan rather than accumulate charges.
  lifecycle {
    ignore_changes = [
      source_details[0].source_id,
    ]

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
