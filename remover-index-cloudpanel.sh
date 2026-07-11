cat << 'EOF' > limpar_index_placeholders.sh
#!/bin/bash

echo "===================================================="
echo "    REMOVENDO INDEX.PHP PADRÃO (HELLO WORLD)        "
echo "===================================================="

# Executa uma busca restrita apenas dentro do diretório de usuários (/home)
# Filtrando estritamente para pastas htdocs para NUNCA tocar na pasta /home/clp do painel
find /home -maxdepth 4 -path "/home/*/htdocs/*/index.php" | while read -r arquivo; do
    # Verifica se o arquivo contém o texto 'Hello World' antes de deletar, por segurança extra
    if grep -q "Hello World" "$arquivo"; then
        echo "Removendo placeholder seguro de: $arquivo"
        rm -f "$arquivo"
    else
        echo "[Ignorado] Arquivo index.php real detectado em: $arquivo"
    fi
done

echo "===================================================="
echo " LIMPEZA CONCLUÍDA COM SEGURANÇA!                   "
echo "===================================================="
EOF

chmod +x limpar_index_placeholders.sh
./limpar_index_placeholders.sh
