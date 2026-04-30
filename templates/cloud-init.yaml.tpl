#cloud-config
package_update: true
package_upgrade: true

packages:
  - nginx
  - libnginx-mod-stream
  - curl
  - tcpdump
  - netcat-openbsd
  - jq
  - unzip
%{ if install_tintin ~}
  - tintin++
%{ endif ~}

write_files:
  - path: /etc/nginx/stream.d/mud-proxy.conf
    encoding: b64
    content: ${nginx_stream_config_b64}

runcmd:
  - mkdir -p /etc/nginx/stream.d
  - grep -qF '/etc/nginx/stream.d/*.conf' /etc/nginx/nginx.conf || echo 'stream { include /etc/nginx/stream.d/*.conf; }' >> /etc/nginx/nginx.conf
  - rm -f /etc/nginx/sites-enabled/default
  - nginx -t
  - systemctl enable nginx
  - systemctl restart nginx
