cat <<EOF > /etc/php/8.4/fpm/pool.d/NOME_DO_USUARIO.conf
[NOME_DO_USUARIO]
user = NOME_DO_USUARIO
group = NOME_DO_USUARIO
listen = 127.0.0.1:PORTA_DO_NGINX
listen.owner = www-data
listen.group = www-data
pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 10s
pm.max_requests = 200
chdir = /
EOF


grep -r "fastcgi_pass" /etc/nginx/sites-enabled/


USERS=("usuarios q estao dentro do /home/")

for user in "${USERS[@]}"; do
    if ! id "$user" &>/dev/null; then
        echo "Criando usuário: $user"
        useradd -r -s /usr/sbin/nologin "$user"
        mkdir -p "/home/$user"
        chown -R "$user:$user" "/home/$user"
    fi
done



cat <<'EOF' > /tmp/rebuild_pools.sh
#!/bin/bash
# Mapa de domínios e portas
declare -A MAP=(
["dominio.com.br"]="18020"
)

for user in "${!MAP[@]}"; do
    port="${MAP[$user]}"
    conf="/etc/php/8.4/fpm/pool.d/${user}.conf"
    
    echo "Processando pool para $user na porta $port..."
    cat <<INNER > "$conf"
[$user]
user = $user
group = $user
listen = 127.0.0.1:$port
listen.owner = www-data
listen.group = www-data
pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 10s
pm.max_requests = 200
chdir = /
php_admin_value[error_log] = /home/$user/logs/php/error.log
INNER
    mkdir -p "/home/$user/logs/php/"
    chown -R "$user:$user" "/home/$user/logs/"
done
EOF

# Dá permissão e executa
chmod +x /tmp/rebuild_pools.sh
bash /tmp/rebuild_pools.sh

# Reinicia o PHP
systemctl restart php8.4-fpm
