#!/bin/bash
# MIGRATOR MASTER V12 - THE SANITIZER & PURGER

LOG_FILE="migracao_$(date +%Y%m%d_%H%M%S).log"

# Coleta de dados
read -p "SSH User [root]: " input_user
SSH_USER=${input_user:-root}
read -p "IP do Servidor Antigo: " OLD_SERVER_IP

DOMINIOS=$(grep -vE '^\s*$' "dominios_lista.txt" | sed 's/server_name//g' | tr -d ' ' | grep -E '\.' | sort | uniq)

# Exclusões padrão para manter o servidor novo limpo
EXCLUDES="--exclude=.bash* --exclude=.ssh --exclude=.wget-hsts --exclude=.wp-cli --exclude=Maildir --exclude=backwpup --exclude=ssl* --exclude=*.log --exclude=.bash_history --exclude=wp-content/cache --exclude=wp-content/w3tc-config --exclude=wp-content/upgrade --exclude=cache --exclude=backups"

for DOMAIN in $DOMINIOS; do
    FOLDER=$(echo $DOMAIN | cut -d. -f1)
    USER_CLEAN=$(echo $DOMAIN | sed 's/\.//g' | cut -c1-12)
    TARGET_PATH="/home/$USER_CLEAN/htdocs"
    
    echo -e "\n\033[1;36m>>> Iniciando Ciclo de Segurança: $DOMAIN\033[0m" | tee -a $LOG_FILE

    # 1. Provisionamento CloudPanel
    clpctl site:add:php --domainName="$DOMAIN" --phpVersion="8.3" --vhostTemplate="WordPress" --siteUser="$USER_CLEAN" > /dev/null 2>&1
    mkdir -p "$TARGET_PATH"

    # 2. Localizar WordPress (Dynamic Path)
    WP_PATH=$(ssh $SSH_USER@$OLD_SERVER_IP "sudo find /home/$FOLDER -maxdepth 3 -name wp-config.php | head -n 1 | xargs dirname")
    
    if [ -z "$WP_PATH" ]; then
        echo "WP-Config não encontrado para $DOMAIN. Pulando." | tee -a $LOG_FILE
        continue
    fi

    # 3. Sanitização e Purga de Malware (HACKER ELITE)
    echo "Executando varredura e expurgo de malwares..."
    # Busca assinaturas em plugins e temas
    INFECTED=$(ssh $SSH_USER@$OLD_SERVER_IP "sudo grep -rIEl '(base64_decode|eval\(|gzinflate|str_rot13|preg_replace.*\/e|shell_exec|exec|passthru)' $WP_PATH/wp-content/plugins $WP_PATH/wp-content/themes")

    if [ -n "$INFECTED" ]; then
        echo -e "\033[1;31m[ALERTA]\033[0m Malware detectado. Purging..."
        while IFS= read -r file; do
            # Extrai o caminho do plugin/tema (ex: .../plugins/nome-do-plugin/...)
            PURGE_DIR=$(echo "$file" | sed -E 's!(.*(plugins|themes)/[^/]+).*!\1!')
            echo "[SECURITY] Removendo diretório infectado: $PURGE_DIR" | tee -a $LOG_FILE
            ssh $SSH_USER@$OLD_SERVER_IP "sudo rm -rf $PURGE_DIR"
        done <<< "$INFECTED"
    fi

    # 4. Limpeza de Banco (WP-CLI)
    echo "Sanitizando banco (Transients/Revisões/Spam)..."
    ssh $SSH_USER@$OLD_SERVER_IP "sudo wp transient delete --all --path=$WP_PATH --allow-root" >/dev/null 2>&1
    ssh $SSH_USER@$OLD_SERVER_IP "sudo wp post delete \$(sudo wp post list --post_type='revision' --format=ids --path=$WP_PATH --allow-root) --force --path=$WP_PATH --allow-root" >/dev/null 2>&1

    # 5. Transferência (Agora sem as pastas infectadas que acabamos de purgar)
    echo "Transferindo..."
    rsync -rtvP --no-perms --no-owner --no-group $EXCLUDES --rsync-path="sudo rsync" -e "ssh -o StrictHostKeyChecking=no" $SSH_USER@$OLD_SERVER_IP:$WP_PATH/ $TARGET_PATH/ >> $LOG_FILE 2>&1

    # 6. Finalização
    chown -R $USER_CLEAN:$USER_CLEAN $TARGET_PATH 2>/dev/null
    ssh $SSH_USER@$OLD_SERVER_IP "sudo wp db export - --path=$WP_PATH --allow-root" | wp db import - --path=$TARGET_PATH --allow-root >> $LOG_FILE 2>&1
    clpctl site:add:ssl --domainName="$DOMAIN" --validation="http" > /dev/null 2>&1
    
    echo -e "\033[1;32m[OK] $DOMAIN migrado e purgado.\033[0m"
done
