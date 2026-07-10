cat << 'EOF' > /tmp/auditoria_temas.sh
#!/bin/bash

# Identifica o binário do WP-CLI no sistema
WP_CLI=$(which wp 2>/dev/null || echo "/usr/local/bin/wp")

echo -e "\033[1;36m==================================================\033[0m"
echo -e "\033[1;36m>>>    INICIANDO AUDITORIA MESTRE DE TEMAS     <<<\033[0m"
echo -e "\033[1;36m==================================================\033[0m"

for user_dir in /home/*; do
    [ -d "$user_dir/htdocs" ] || continue
    USER_NAME=$(basename "$user_dir")

    for domain_dir in "$user_dir"/htdocs/*; do
        [ -d "$domain_dir" ] || continue
        DOMAIN=$(basename "$domain_dir")

        # Filtra apenas se houver uma instalação do WordPress ativa
        if [ -f "$domain_dir/wp-config.php" ]; then
            echo -e "\n\033[1;34m[*] Analisando Domínio: $DOMAIN (Usuário: $USER_NAME)\033[0m"

            # 1. Pega o slug do tema ativo configurado no banco de dados
            ACTIVE_THEME=$($WP_CLI option get stylesheet --path="$domain_dir" --allow-root 2>/dev/null | tr -d '\r')

            if [ -z "$ACTIVE_THEME" ]; then
                echo -e "  \033[1;31m[ERRO] Não foi possível ler o tema ativo no banco de dados.\033[0m"
                continue
            fi

            # 2. Verifica se a pasta física do tema ativo existe no local correto
            THEME_PATH="$domain_dir/wp-content/themes/$ACTIVE_THEME"
            if [ ! -d "$THEME_PATH" ]; then
                echo -e "  \033[1;31m[ALERTA CRÍTICO] O tema '$ACTIVE_THEME' está QUEBRADO ou AUSENTE no disco!\033[0m"
                echo -e "  -> Pasta não encontrada: wp-content/themes/$ACTIVE_THEME"
            else
                # 3. Se a pasta existe, checa se o style.css essencial está legível
                if [ ! -f "$THEME_PATH/style.css" ]; then
                    echo -e "  \033[1;31m[ALERTA] Pasta do tema existe, mas o style.css está faltando!\033[0m"
                else
                    echo -e "  \033[1;32m[OK] Tema ativo instalado e mapeado: $ACTIVE_THEME\033[0m"
                fi
            fi

            # 4. Double-Check: Força o WP-CLI a listar os temas para ver se o core reclama de falhas
            WP_ERRORS=$($WP_CLI theme list --path="$domain_dir" --allow-root 2>&1 | grep -iE '(error|warning|broken|reverting|não existe|does not exist)')
            if [ -n "$WP_ERRORS" ]; then
                echo -e "  \033[1;33m[AVISO WP-CLI] O core do WordPress reportou problemas:\033[0m"
                echo "$WP_ERRORS" | sed 's/^/    /'
            fi
        fi
    done
done
EOF

chmod +x /tmp/auditoria_temas.sh
/tmp/auditoria_temas.sh
