stream {
%{ for p in nginx_reverse_proxies ~}
    upstream proxy_${p.listen_port} {
        server ${p.upstream_host}:${p.upstream_port};
    }

    server {
        listen ${p.listen_port};
        proxy_pass proxy_${p.listen_port};
    }

%{ endfor ~}
}
