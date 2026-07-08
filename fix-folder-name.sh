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
