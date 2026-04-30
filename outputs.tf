output "instance_names" {
  description = "Display names of the mud-proxy instances."
  value       = local.instance_names
}

output "instance_public_ips" {
  description = "Public IPs assigned to each mud-proxy instance."
  value = {
    for i, inst in oci_core_instance.mud_proxy :
    local.instance_names[i] => inst.public_ip
  }
}

output "instance_private_ips" {
  description = "Static private IPs of each mud-proxy instance."
  value       = local.instance_ips
}

output "proxy_ports" {
  description = "TCP ports the nginx stream proxy listens on."
  value       = var.allowed_tcp_ports
}

output "mud_upstream" {
  description = "Upstream MUD server the proxy forwards to."
  value       = "${var.mud_upstream_host}:${var.mud_upstream_port}"
}

output "ssh_commands" {
  description = "SSH commands to connect to each instance."
  value = {
    for i, inst in oci_core_instance.mud_proxy :
    local.instance_names[i] => "ssh ubuntu@${inst.public_ip}"
  }
}

output "client_connect_examples" {
  description = "Example connection strings for MUD clients (first proxy, first port)."
  value = {
    for i, inst in oci_core_instance.mud_proxy :
    local.instance_names[i] => [
      for port in var.allowed_tcp_ports :
      "telnet ${inst.public_ip} ${port}"
    ]
  }
}

output "nginx_stream_config" {
  description = "Rendered nginx stream config deployed to each instance."
  value       = local.nginx_stream_config
}
