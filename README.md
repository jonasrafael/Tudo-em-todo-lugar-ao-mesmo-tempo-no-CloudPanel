# Tudo em Todo Lugar ao Mesmo Tempo - CloudPanel Migrator

O **Tudo em Todo Lugar ao Mesmo Tempo** não é apenas um script de migração. É uma ferramenta de **Higienização Forense e Automação de Infraestrutura** para migrar sites WordPress de qualquer servidor antigo para o ecossistema **CloudPanel**.

Chega de migrar "lixo digital", logs inúteis ou backdoors silenciosos. Este script purga, limpa e organiza seu ambiente antes de mover um único byte.

---

## 🚀 O Diferencial Elite

Migrações tradicionais (`rsync` simples) apenas copiam os problemas de um servidor para outro. O nosso script segue uma lógica de **"Migração Imaculada"**:

1.  **Varredura Forense:** Antes de mover, ele busca por assinaturas de malwares (`base64_decode`, `eval`, etc.) nos diretórios de plugins e temas.
2.  **Purga Automática:** Se um plugin ou tema estiver infectado, ele **não tenta consertar**, ele remove o diretório inteiro do servidor de origem para evitar a propagação do malware.
3.  **Sanitização de Banco:** Remove revisões de posts, comentários spam e dados temporários (transients) via WP-CLI antes de exportar o SQL.
4.  **Automação CloudPanel:** Provisiona o site automaticamente, gera SSL e ajusta permissões de dono (`chown`) para o padrão do CloudPanel.
5.  **Log de Auditoria:** Cada ação de purga e cada arquivo removido é registrado no log, para que você saiba exatamente o que foi deletado.

---

## 🛠 Pré-requisitos

* **Servidor de Origem:** SSH com acesso `root` ou `sudo`.
* **Servidor de Destino:** CloudPanel instalado e configurado.
* **WP-CLI:** (O script instala automaticamente no servidor antigo caso não encontre).

---

## 📦 Como utilizar

1.  **Prepare a lista:** Crie um arquivo `dominios_lista.txt` na mesma pasta do script, com um domínio por linha:
    ```text
    meusite.com
    outro.com.br
    ```

2.  **Configuração:**
    * Dê permissão de execução: `chmod +x migracao.sh`.
    * Certifique-se de que sua chave SSH (`ssh-copy-id`) está configurada entre os servidores para evitar pedidos de senha.

3.  **Execução:**
    ```bash
    ./migracao.sh
    ```

---

## ⚠️ AVISO DE SEGURANÇA (Destrutivo)

Este script possui funcionalidades **destrutivas** por design:
* Quando detecta malware, ele utiliza `sudo rm -rf` para deletar a pasta do plugin/tema permanentemente do servidor de origem.
* **Sempre execute o script com a opção `Dry Run` (Simulação) primeiro** para ver quais arquivos seriam alterados.
* Ao migrar para o CloudPanel, certifique-se de que o PHP do site seja compatível com a versão que o script define (padrão 8.3).

---

## 📝 Logs e Auditoria
Toda execução gera um log no formato `migracao_YYYYMMDD_HHMMSS.log`. 
* *Exemplo de leitura:* Se o log disser `[SECURITY] Removendo diretório infectado: /plugins/webp-express`, significa que você deve reinstalar este plugin manualmente via painel do WordPress após a migração, garantindo que ele venha de uma fonte limpa.

---

## 🤝 Contribuições
Sinta-se à vontade para sugerir novas assinaturas de malware para a varredura ou melhorias na purga de lixo. 

*Desenvolvido com foco em alta performance e segurança extrema.*
