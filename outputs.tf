output "instance_names" {
  description = "Display names of the mud-proxy instances."
  value       = [for n in local.instance_numbers : local.instance_names[tostring(n)]]
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
  value       = [for n in local.instance_numbers : local.instance_ips[tostring(n)]]
}

output "proxy_ports" {
  description = "TCP ports the nginx stream proxy listens on."
  value       = [for p in var.nginx_reverse_proxies : p.listen_port]
}

output "mud_upstream" {
  description = "Upstream MUD servers the proxy forwards to."
  value = {
    for p in var.nginx_reverse_proxies :
    p.listen_port => "${p.upstream_host}:${p.upstream_port}"
  }
  sensitive = true
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
      for p in var.nginx_reverse_proxies :
      "telnet ${inst.public_ip} ${p.listen_port}"
    ]
  }
}

output "nginx_stream_config" {
  description = "Rendered nginx stream config deployed to each instance."
  value       = local.nginx_stream_config
  sensitive   = true
}

output "tintin_connection_strings" {
  description = "tintin++ config shortcut."
  value = {
    for i, inst in oci_core_instance.mud_proxy :
    local.instance_names[i] => "{HOST} {${inst.public_ip}}"
  }
}

output "proxy_test_commands" {
  description = "Ready-to-run nc and curl commands for validating each proxy listener."
  value = {
    for i, inst in oci_core_instance.mud_proxy :
    local.instance_names[i] => flatten([
      for p in var.nginx_reverse_proxies : [
        "nc -vz ${inst.public_ip} ${p.listen_port}",
        "curl -v --connect-timeout 5 telnet://${inst.public_ip}:${p.listen_port}",
      ]
    ])
  }
}
