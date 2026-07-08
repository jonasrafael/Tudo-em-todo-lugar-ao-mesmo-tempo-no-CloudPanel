#!/bin/bash
# MIGRATOR MASTER V6 - O ÚNICO QUE VOCÊ PRECISA

# Coleta de dados
read -p "IP do Servidor Antigo: " OLD_SERVER_IP
read -p "Fazer SIMULAÇÃO (Dry Run)? (s/n) [n]: " dry_run
DRY_RUN=${dry_run:-n}

DOMINIOS=$(grep -vE '^\s*$' "dominios_lista.txt" | sed 's/server_name//g' | tr -d ' ' | grep -E '\.' | sort | uniq)

for DOMAIN in $DOMINIOS; do
    FOLDER=$(echo $DOMAIN | cut -d. -f1)
    USER_CLEAN=$(echo $DOMAIN | sed 's/\.//g' | cut -c1-16)
    TARGET_PATH="/home/$USER_CLEAN/htdocs"
    
    echo -e "\n\033[1;36m>>> Processando: $DOMAIN <<<\033[0m"

    # 1. Provisiona no CloudPanel
    clpctl site:add:php --domainName="$DOMAIN" --phpVersion="8.3" --vhostTemplate="WordPress" --siteUser="$USER_CLEAN" > /dev/null 2>&1
    mkdir -p "$TARGET_PATH"

    # 2. Rsync "blindado" (Ignora permissões do antigo, aplica as novas no final)
    RSYNC_OPTS="-rtvP --no-perms --no-owner --no-group"
    [[ "$DRY_RUN" == "s" ]] && RSYNC_OPTS="$RSYNC_OPTS --dry-run"

    echo "Transferindo arquivos..."
    rsync $RSYNC_OPTS -e "ssh -o StrictHostKeyChecking=no" root@$OLD_SERVER_IP:/home/$FOLDER/ $TARGET_PATH/

    # 3. Ajuste de Dono (Essencial para CloudPanel)
    chown -R $USER_CLEAN:$USER_CLEAN $TARGET_PATH

    # 4. Migração de Banco (Com auto-detecção)
    WP_PATH=$(ssh root@$OLD_SERVER_IP "find /home/$FOLDER -name wp-config.php | head -n 1 | xargs dirname")
    
    if [ -n "$WP_PATH" ]; then
        echo "Migrando Banco de Dados..."
        ssh root@$OLD_SERVER_IP "wp db export - --path=$WP_PATH" | wp db import - --path=$TARGET_PATH --allow-root
    fi

    # 5. SSL
    clpctl site:add:ssl --domainName="$DOMAIN" --validation="http" > /dev/null 2>&1
    
    echo -e "\033[1;32m[OK] $DOMAIN migrado com sucesso.\033[0m"
done
