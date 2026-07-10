#!/bin/bash
read -p "Usuário SSH antigo: " SSH_USER
read -p "IP do servidor antigo: " OLD_SERVER_IP

echo "Mapeando todos os sites..."
ssh -t $SSH_USER@$OLD_SERVER_IP "sudo find /home -type f -name 'wp-config.php'"
