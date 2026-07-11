cat << 'EOF' > exportar_local.sh
#!/bin/bash

# Lista exata das pastas que você deu o "ls" no /home/
pastas=(
  "bioperfeita" "blog" "budmaps" "buellbrasil" "canabista" "cannabis-app" 
  "cannabisflow" "clubescanabicos" "compremaconha" "demaconha" "design" 
  "diariodecultivo" "drhemp" "farmacaceres" "farmacias" "futurizy" 
  "headshop" "jogodasmarcas" "jonasrafael" "kadoshodontologia" "laricaria" 
  "legalizeja" "plantando" "prfvr" "tucultivo" "weedtour"
)

# Cria uma pasta limpa para armazenar todos os dumps juntos
mkdir -p /root/dumps_wordpress
rm -f /root/dumps_wordpress/*

echo "===================================================="
echo "         INICIANDO DUMP DOS BANCOS DE DADOS         "
echo "===================================================="

for pasta in "${pastas[@]}"; do
    WP_CONFIG="/home/${pasta}/public_html/wp-config.php"
    
    echo "--------------------------------------------------"
    echo "Analisando: /home/${pasta}..."
    
    if [ -f "$WP_CONFIG" ]; then
        # Extrai as credenciais usando delimitadores de aspas simples ou duplas
        DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | awk -F"'" '{print $4}')
        [ -z "$DB_NAME" ] && DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | awk -F'"' '{print $4}')
        
        DB_USER=$(grep "DB_USER" "$WP_CONFIG" | awk -F"'" '{print $4}')
        [ -z "$DB_USER" ] && DB_USER=$(grep "DB_USER" "$WP_CONFIG" | awk -F'"' '{print $4}')
        
        DB_PASSWORD=$(grep "DB_PASSWORD" "$WP_CONFIG" | awk -F"'" '{print $4}')
        [ -z "$DB_PASSWORD" ] && DB_PASSWORD=$(grep "DB_PASSWORD" "$WP_CONFIG" | awk -F'"' '{print $4}')
        
        DB_HOST=$(grep "DB_HOST" "$WP_CONFIG" | awk -F"'" '{print $4}')
        [ -z "$DB_HOST" ] && DB_HOST=$(grep "DB_HOST" "$WP_CONFIG" | awk -F'"' '{print $4}')
        
        # Limpa quebras de linha/espaços no texto extraído
        DB_NAME=$(echo "$DB_NAME" | tr -d '\r\n ')
        DB_USER=$(echo "$DB_USER" | tr -d '\r\n ')
        DB_PASSWORD=$(echo "$DB_PASSWORD" | tr -d '\r\n ')
        DB_HOST=$(echo "$DB_HOST" | tr -d '\r\n ')

        if [ -n "$DB_NAME" ]; then
            echo "Banco localizado: $DB_NAME (User: $DB_USER)"
            
            # Executa o dump local direto para a pasta centralizada
            mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "/root/dumps_wordpress/${pasta}.sql"
            
            if [ $? -eq 0 ] && [ -s "/root/dumps_wordpress/${pasta}.sql" ]; then
                echo "=> SUCESSO: Arquivo /root/dumps_wordpress/${pasta}.sql gerado!"
            else
                echo "=> [ERRO] Falha ao executar o mysqldump para $pasta."
            fi
        else
            echo "=> [ERRO] Não consegui extrair as chaves do wp-config.php."
        fi
    else
        echo "=> [Ignorado] Não é um WordPress ou wp-config.php ausente."
    fi
done

echo "===================================================="
echo " PROCESSO CONCLUÍDO! TODOS OS .SQL ESTÃO EM:        "
echo " /root/dumps_wordpress/                             "
echo "===================================================="
EOF

chmod +x exportar_local.sh
./exportar_local.sh
