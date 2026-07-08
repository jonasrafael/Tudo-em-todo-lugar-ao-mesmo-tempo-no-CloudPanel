root@srv:/usr/games# ./migracao.sh 
SSH User [root]: nomedeusuario
IP do Servidor Antigo: servidorantigo.design.com.br
Fazer SIMULAÇÃO (Dry Run)? (s/n) [n]: s


>>> Processando: api.prfvr.com (User: apiprfvrcom)
[ERRO] Falha na transferência.
Deseja (p)ular ou (a)bortar? 

>>> Iniciando Ciclo de Segurança: design.com.br
Executando varredura e expurgo de malwares...
[ALERTA] Malware detectado. Purging...
[SECURITY] Removendo diretório infectado: /home/design/public_html/wp-content/plugins/wordpress-seo-premium
Sanitizando banco (Transients/Revisões/Spam)...
Transferindo...
sudo: wp: command not found
[OK] design.com.br migrado e purgado.
