#!/bin/bash
# ==============================================================================
# MIGRATOR MASTER V42 - THE SMART URL ALIGNMENT EDITION
# Idempotente, Read-Only na origem e com Search-Replace automatizado contra loops.
# ==============================================================================

LOG_FILE="migracao_master_$(date +%Y%m%d_%H%M%S).log"
WP_CLI_PATH="/usr/local/bin/wp"
SPAM_LIST="spam_list.txt"

EXCLUDES="--exclude=.bash* --exclude=.ssh --exclude=.wget-hsts --exclude=.wp-cli --exclude=Maildir --exclude=backwpup --exclude=ssl* --exclude=*.log --exclude=.bash_history --exclude=wp-content/cache --exclude=wp-content/w3tc-config --exclude=wp-content/upgrade --exclude=cache --exclude=backups --exclude=quarantine --exclude=wp-content/languages/plugins/woocommerce-*.json"

echo "=========================================================="
echo " INICIANDO MIGRAÇÃO MESTRE V42 - $(date)"
echo "=========================================================="

read -p "SSH User [root]: " input_user
SSH_USER=${input_user:-root}
read -p "IP do Servidor Antigo: " OLD_SERVER_IP

echo "[PREP] Baixando feeds globais de Spam e E-mails Descartáveis no NOVO servidor..."
curl -s https://raw.githubusercontent.com/groundcat/disposable-email-domain-list/master/domains.txt > /tmp/spam_raw.txt
curl -s https://raw.githubusercontent.com/sefinek/Blacklisted-Emails/main/blacklist/LIST.txt >> /tmp/spam_raw.txt
curl -s https://raw.githubusercontent.com/unkn0w/disposable-email-domain-list/main/domains.txt >> /tmp/spam_raw.txt

grep -v '^#' /tmp/spam_raw.txt | grep -v '^\s*$' | tr '[:upper:]' '[:lower:]' | sort -u > /tmp/disposable.txt

echo "DELETE FROM wp_comments WHERE SUBSTRING_INDEX(comment_author_email, '@', -1) IN (" > /tmp/clean_spam.sql
awk '{print "'\x27'" $1 "'\x27'"}' /tmp/disposable.txt | paste -sd, - >> /tmp/clean_spam.sql
echo ");" >> /tmp/clean_spam.sql
rm -f /tmp/spam_raw.txt /tmp/disposable.txt

DOMINIOS=$(grep -vE '^\s*$' "dominios_lista.txt" | sed 's/server_name//g' | tr -d ' ' | grep -E '\.' | sort | uniq)

for DOMAIN in $DOMINIOS; do
    FOLDER=$(echo $DOMAIN | cut -d. -f1)
    USER_CLEAN=$(echo "$DOMAIN" | sed 's/\./_/g')
    TARGET_PATH="/home/$USER_CLEAN/htdocs/$DOMAIN"
    
    echo -e "\n\033[1;36m==================================================\033[0m"
    echo -e "\033[1;36m>>> PROCESSANDO: $DOMAIN (Target User: $USER_CLEAN)\033[0m"
    echo -e "\n\033[1;36m==================================================\033[0m"

    # 1. DETECÇÃO REMOTA RÁPIDA (READ-ONLY)
    echo "[BUSCA] Procurando wp-config ou index.html/htm no servidor antigo..."
    SEARCH_CMD="sudo find /home/*${DOMAIN}* /home/*${FOLDER}* -maxdepth 4 -type f 2>/dev/null"
    
    REMOTE_WP_FILE=$(ssh -n $SSH_USER@$OLD_SERVER_IP "$SEARCH_CMD -name 'wp-config.php' | head -n 1")
    REMOTE_WP_FILE=$(echo "$REMOTE_WP_FILE" | tr -d '\r')
    
    REMOTE_STATIC_FILE=$(ssh -n $SSH_USER@$OLD_SERVER_IP "$SEARCH_CMD \( -name 'index.html' -o -name 'index.htm' \) | grep -E 'public_html|htdocs|www' | head -n 1")
    REMOTE_STATIC_FILE=$(echo "$REMOTE_STATIC_FILE" | tr -d '\r')

    if [ -n "$REMOTE_WP_FILE" ]; then
        TYPE="WP"
        SOURCE_PATH=$(dirname "$REMOTE_WP_FILE")
        echo -e "\033[1;32m[DETECTADO] WordPress localizado em: $SOURCE_PATH\033[0m"
    elif [ -n "$REMOTE_STATIC_FILE" ]; then
        TYPE="STATIC"
        SOURCE_PATH=$(dirname "$REMOTE_STATIC_FILE")
        echo -e "\033[1;32m[DETECTADO] Site Estático localizado em: $SOURCE_PATH\033[0m"
    else
        echo -e "\033[1;31m[PULADO] $DOMAIN - Nenhum site válido encontrado.\033[0m"
        continue
    fi

    # 2. PROVISIONAMENTO OFICIAL & IDEMPOTÊNCIA
    if [ -f "/etc/nginx/sites-available/$DOMAIN.conf" ]; then
        echo "[INFO] $DOMAIN já está no CloudPanel. Ativando Modo UPDATE (Apenas Arquivos)..."
        SITE_EXISTS=true
        mkdir -p "$TARGET_PATH"
    else
        echo "[PROVISIONANDO] Criando site com sintaxe oficial..."
        SITE_EXISTS=false
        RANDOM_PASS=$(openssl rand -base64 16)
        
        if [ -d "/home/$USER_CLEAN" ]; then
            echo "   -> [AVISO] Removendo diretório residual '$USER_CLEAN' para evitar conflitos..."
            userdel -f "$USER_CLEAN" 2>/dev/null
            rm -rf "/home/$USER_CLEAN"
        fi

        if [ "$TYPE" == "WP" ]; then
            clpctl site:add:php --domainName="$DOMAIN" --phpVersion="8.3" --vhostTemplate="WordPress" --siteUser="$USER_CLEAN" --siteUserPassword="$RANDOM_PASS" > /dev/null 2>&1
        else
            clpctl site:add:static --domainName="$DOMAIN" --vhostTemplate="Static" --siteUser="$USER_CLEAN" --siteUserPassword="$RANDOM_PASS" > /dev/null 2>&1
        fi
        
        mkdir -p "$TARGET_PATH"
    fi

    # 3. TRANSFERÊNCIA INTELIGENTE
    echo "[RSYNC] Sincronizando arquivos (Modo Delta/Update)..."
    rsync -rtvP --update --no-perms --no-owner --no-group $EXCLUDES --rsync-path="sudo rsync" -e "ssh -o StrictHostKeyChecking=no" $SSH_USER@$OLD_SERVER_IP:$SOURCE_PATH/ $TARGET_PATH/ >> $LOG_FILE 2>&1

    # 4. CONFIGURAÇÃO DE BANCO DE DADOS LOCAL (Com alinhamento inteligente de URL)
    if [ "$TYPE" == "WP" ]; then
        if [ "$SITE_EXISTS" = false ]; then
            echo "[DATABASE] Configurando e Importando Banco de Dados Inicial..."
            DB_SUFFIX=$(openssl rand -hex 2)
            DB_NAME="db_${USER_CLEAN:0:8}_${DB_SUFFIX}"
            DB_USER="us_${USER_CLEAN:0:8}_${DB_SUFFIX}"
            DB_PASS=$(openssl rand -base64 14 | tr -dc 'a-zA-Z0-9!@#%^&*')

            echo "   -> Gerando credenciais CloudPanel ($DB_NAME)..."
            clpctl db:add --domainName="$DOMAIN" --databaseName="$DB_NAME" --databaseUserName="$DB_USER" --databaseUserPassword="$DB_PASS" > /dev/null 2>&1
            
            sudo $WP_CLI_PATH config set DB_NAME "$DB_NAME" --path="$TARGET_PATH" --allow-root > /dev/null 2>&1
            sudo $WP_CLI_PATH config set DB_USER "$DB_USER" --path="$TARGET_PATH" --allow-root > /dev/null 2>&1
            sudo $WP_CLI_PATH config set DB_PASSWORD "$DB_PASS" --path="$TARGET_PATH" --allow-root > /dev/null 2>&1
            sudo $WP_CLI_PATH config set DB_HOST "127.0.0.1" --path="$TARGET_PATH" --allow-root > /dev/null 2>&1

            echo "   -> Importando dados do servidor antigo..."
            ssh -n $SSH_USER@$OLD_SERVER_IP "sudo $WP_CLI_PATH db export - --path=$SOURCE_PATH --allow-root" | sudo $WP_CLI_PATH db import - --path=$TARGET_PATH --allow-root >> $LOG_FILE 2>&1

            # --- MOTOR DE ALINHAMENTO DE URL (SÊNIOR ENGINE) ---
            echo "   -> Sincronizando e higienizando URLs da estrutura interna..."
            # Captura a URL cadastrada originalmente no banco antigo importado
            OLD_HOME_URL=$(sudo $WP_CLI_PATH option get home --path="$TARGET_PATH" --allow-root 2>/dev/null | tr -d '\r')
            
            # Se a URL antiga diferir da nova meta (https://$DOMAIN), executa a varredura completa
            if [ "$OLD_HOME_URL" != "https://$DOMAIN" ] && [ -n "$OLD_HOME_URL" ]; then
                echo "      [REWRITE] Executando search-replace em tabelas estruturais de: $OLD_HOME_URL -> https://$DOMAIN"
                sudo $WP_CLI_PATH search-replace "$OLD_HOME_URL" "https://$DOMAIN" --path="$TARGET_PATH" --allow-root >> $LOG_FILE 2>&1
            fi
            
            # Força as duas chaves básicas e limpa o cache de objetos do WordPress
            sudo $WP_CLI_PATH option update siteurl "https://$DOMAIN" --path="$TARGET_PATH" --allow-root >/dev/null 2>&1
            sudo $WP_CLI_PATH option update home "https://$DOMAIN" --path="$TARGET_PATH" --allow-root >/dev/null 2>&1
            sudo $WP_CLI_PATH cache flush --path="$TARGET_PATH" --allow-root >/dev/null 2>&1
            # ----------------------------------------------------
        else
            echo "[DATABASE] Site já existe. Importação ignorada para preservação de dados locais."
        fi
    fi

    # 5. SANITIZAÇÃO LOCAL
    if [ "$TYPE" == "WP" ]; then
        echo "[SANITIZAÇÃO LOCAL] Limpando Malware, Transientes e Spam..."
        mkdir -p $TARGET_PATH/wp-content/quarantine
        
        INFECTED=$(grep -rIlE '(base64_decode|eval\(|gzinflate|str_rot13|preg_replace.*\/e|shell_exec|exec|passthru)' $TARGET_PATH/wp-content/plugins $TARGET_PATH/wp-content/themes 2>/dev/null | sort -u)
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            PURGE_DIR=$(echo "$file" | sed -E 's!(.*(plugins|themes)/[^/]+).*!\1!')
            echo "   -> [SECURITY] Quarentenando Localmente: $PURGE_DIR"
            mv $PURGE_DIR $TARGET_PATH/wp-content/quarantine/ 2>/dev/null
        done <<< "$INFECTED"

        sudo $WP_CLI_PATH transient delete --all --path=$TARGET_PATH --allow-root >/dev/null 2>&1
        sudo $WP_CLI_PATH post delete $(sudo $WP_CLI_PATH post list --post_type='revision' --format=ids --path=$TARGET_PATH --allow-root 2>/dev/null) --force --path=$TARGET_PATH --allow-root >/dev/null 2>&1
        sudo $WP_CLI_PATH db query < /tmp/clean_spam.sql --path=$TARGET_PATH --allow-root >/dev/null 2>&1

        if [ -f "$SPAM_LIST" ]; then
            echo "   -> Processando spam_list.txt customizada..."
            while read -r spam_pattern; do
                [[ -z "$spam_pattern" || "$spam_pattern" =~ ^# ]] && continue
                sudo $WP_CLI_PATH comment delete $(sudo $WP_CLI_PATH comment list --search="$spam_pattern" --format=ids --path=$TARGET_PATH --allow-root 2>/dev/null) --path=$TARGET_PATH --allow-root >/dev/null 2>&1
            done < "$SPAM_LIST"
        fi
    fi

    # 6. HARDENING DE SEGURANÇA E PERMISSÕES
    echo "[HARDENING] Aplicando permissões de segurança..."
    find /home/$USER_CLEAN/htdocs/ -type d -exec chmod 755 {} \;
    find /home/$USER_CLEAN/htdocs/ -type f -exec chmod 644 {} \;
    if [ "$TYPE" == "WP" ]; then
        chmod 600 $TARGET_PATH/wp-config.php 2>/dev/null
    fi
    chown -R $USER_CLEAN:$USER_CLEAN /home/$USER_CLEAN/htdocs/ 2>/dev/null

    # 7. CRON E SSL
    if [ "$SITE_EXISTS" = false ]; then
        echo "[SISTEMA] Restaurando Crons e gerando SSL inicial..."
        ssh -n $SSH_USER@$OLD_SERVER_IP "sudo crontab -l -u $FOLDER" > /tmp/cron_temp 2>/dev/null
        if [ -s /tmp/cron_temp ]; then
            crontab -u "$USER_CLEAN" /tmp/cron_temp
        fi
        rm -f /tmp/cron_temp
        clpctl site:install:certificate --domainName="$DOMAIN" --validation="http" > /dev/null 2>&1
    else
        echo "[SISTEMA] Site já existe. Pulando emissão de SSL para evitar conflitos."
    fi
    
    # 8. HEALTH CHECK
    echo "[AUDITORIA] Testando o domínio localmente..."
    sleep 3
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -H "Cache-Control: no-cache" http://$DOMAIN)
    
    if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "301" || "$HTTP_STATUS" == "302" ]]; then
        echo -e "\033[1;32m[SUCESSO] $DOMAIN finalizado e operante (Status $HTTP_STATUS).\033[0m"
    else
        echo -e "\033[1;31m[ALERTA] $DOMAIN retornou status $HTTP_STATUS.\033[0m"
    fi

done
