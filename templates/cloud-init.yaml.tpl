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

bootcmd:
  - mkdir -p /etc/nginx/stream.d

write_files:
  - path: /etc/nginx/nginx.conf
    encoding: b64
    content: ${nginx_config_b64}
    permissions: '0644'
    defer: true

  - path: /etc/nginx/stream.d/mud-proxy.conf
    encoding: b64
    content: ${nginx_stream_config_b64}
    permissions: '0644'
    defer: true

  - path: /usr/local/sbin/mud-proxy-firewall
    permissions: '0755'
    defer: true
    content: |
      #!/bin/sh
      set -eu

      ports="${nginx_proxy_ports_csv}"
      [ -n "$ports" ] || exit 0

      iptables -C INPUT -p tcp -m multiport --dports "$ports" -j ACCEPT 2>/dev/null ||
        iptables -I INPUT 1 -p tcp -m multiport --dports "$ports" -j ACCEPT

  - path: /etc/systemd/system/mud-proxy-firewall.service
    permissions: '0644'
    defer: true
    content: |
      [Unit]
      Description=Allow local firewall ingress for MUD proxy ports
      After=network-pre.target
      Before=nginx.service

      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/mud-proxy-firewall
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target

runcmd:
  - rm -f /etc/nginx/sites-enabled/default
  - systemctl daemon-reload
  - systemctl enable --now mud-proxy-firewall.service
  - nginx -t
  - systemctl enable nginx
  - systemctl restart nginx
