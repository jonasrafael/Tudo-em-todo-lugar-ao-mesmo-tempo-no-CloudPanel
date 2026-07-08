# 1. O "SSH Completo" (Setup)
Para que o root do novo servidor entre no antigo sem pedir nada, execute estes dois comandos no seu servidor novo:

Bash
# Gera a chave se não existir
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# Copia a identidade para o servidor antigo (isso autoriza o acesso total)
ssh-copy-id root@IP_DO_SEU_SERVIDOR_ANTIGO
Após isso, o SSH está "completo" e autenticado.

# 2. O Script de Migração "Master"
Este script contém a correção definitiva para o erro de Permission denied. Usamos as flags --no-perms --no-owner --no-group. Isso diz ao servidor: "Não tente copiar quem é o dono do arquivo lá, apenas copie o conteúdo e eu ajusto o dono aqui depois".

# Por que este comando é a solução definitiva:
--no-perms --no-owner --no-group: O erro Permission denied (13) ocorre porque o rsync tenta replicar o usuário/grupo que existe no cannafix (que não existe no servidor novo). Essas flags eliminam essa tentativa, evitando conflitos de UID/GID.

chown -R pós-cópia: Como nós ignoramos o dono na cópia, o chown no final do script garante que o CloudPanel tenha total controle sobre os arquivos, evitando erros de "Forbidden" ao acessar o site.

SSH Key: Ao usar root@IP, o script agora usará a chave que você gerou no passo 1, tornando o processo automático, sem nunca pedir a senha.
