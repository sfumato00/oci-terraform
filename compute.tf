locals {
  ad_count = length(data.oci_identity_availability_domains.ads.availability_domains)

  # Per-instance derived values keyed by stable numeric suffix.
  instance_numbers        = var.instance_numbers == null ? range(1, var.instance_count + 1) : var.instance_numbers
  instance_numbers_by_key = { for n in local.instance_numbers : tostring(n) => n }

  instance_ads = {
    for key, n in local.instance_numbers_by_key :
    key => (
      var.availability_domain_strategy == "spread"
      ? data.oci_identity_availability_domains.ads.availability_domains[(n - 1) % local.ad_count].name
      : data.oci_identity_availability_domains.ads.availability_domains[0].name
    )
  }

  # Stable private IPs starting at host .11 within the configured public subnet.
  instance_ips   = { for key, n in local.instance_numbers_by_key : key => cidrhost(var.public_subnet_cidr, 10 + n) }
  instance_names = { for key, n in local.instance_numbers_by_key : key => format("mud-proxy-%02d", n) }

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
  for_each = local.instance_numbers_by_key

  availability_domain = local.instance_ads[each.key]
  compartment_id      = var.compartment_ocid
  display_name        = local.instance_names[each.key]
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
    network_type                        = "PARAVIRTUALIZED"
    is_pv_encryption_in_transit_enabled = true
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "${local.instance_names[each.key]}-vnic"
    hostname_label   = local.instance_names[each.key]
    private_ip       = local.instance_ips[each.key]
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
      launch_options[0].is_pv_encryption_in_transit_enabled,
      source_details[0].boot_volume_size_in_gbs,
      source_details[0].source_id,
    ]

    precondition {
      condition     = length(local.instance_numbers) * var.ocpu_per_instance <= 4
      error_message = "Total OCPUs (active instance count x ocpu_per_instance) exceeds the Always Free A1 limit of 4."
    }
    precondition {
      condition     = length(local.instance_numbers) * var.memory_gb_per_instance <= 24
      error_message = "Total memory (active instance count x memory_gb_per_instance) exceeds the Always Free A1 limit of 24 GB."
    }
    precondition {
      condition     = length(local.instance_numbers) * var.boot_volume_gb <= 200
      error_message = "Total storage (active instance count x boot_volume_gb) exceeds the Always Free block volume limit of 200 GB."
    }
  }
}
