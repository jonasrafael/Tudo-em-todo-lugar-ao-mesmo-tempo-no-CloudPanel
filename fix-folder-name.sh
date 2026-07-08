#Remover Nomes Truncados
cd /home/
for folder in *; do
    # Ignora pastas protegidas
    [[ "$folder" == "clp" || "$folder" == "mysql" || "$folder" == "localhost" ]] && continue
    # Se a pasta contém underscore, é a versão nova (boa), ignore
    [[ "$folder" == *"_"* ]] && continue
    # Se a pasta NÃO tem underscore, é o lixo antigo
    echo "[CANDIDATO A LIXO]: $folder"
done


#A faxina
cd /home/
for folder in *; do
    [[ "$folder" == "clp" || "$folder" == "mysql" || "$folder" == "localhost" ]] && continue
    [[ "$folder" == *"_"* ]] && continue
    echo "Deletando $folder..."
    rm -rf "$folder"
done


# 1. Remove os htdocs vazios identificados
find /home/ -maxdepth 2 -name "htdocs" -type d -empty -exec rm -rf {} \;

# 2. Remove as pastas dos domínios que ficaram órfãs (agora que o htdocs sumiu, a pasta do domínio está vazia)
find /home/ -maxdepth 1 -type d -empty -delete
