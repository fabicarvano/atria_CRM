# Deploy — Soma por Coluna no Kanban de Oportunidades
# EscopoCRM / Decatron — Servidor 148.72.177.131

## Arquivo criado
client/custom/modules/crm/src/views/opportunity/list.js

## Caminho no servidor
/opt/espocrm/www/client/custom/modules/crm/src/views/opportunity/list.js

## Comandos para aplicar no servidor (via SSH)

# 1. Criar diretório se não existir
mkdir -p /opt/espocrm/www/client/custom/modules/crm/src/views/opportunity/

# 2. Copiar o arquivo (ou usar o conteúdo gerado)
# (faça upload ou copie o conteúdo do list.js para o caminho acima)

# 3. Limpar cache
php /opt/espocrm/www/command.php clear-cache

# 4. Hard refresh no browser: Ctrl+Shift+R

## Como funciona
- Sobrescreve apenas a view JS de listagem de Oportunidades (não toca PHP/metadata)
- Após o Kanban renderizar, lê todos os models da collection, agrupa por "stage" e soma "amount"
- Injeta o total formatado em BRL abaixo do label de cada coluna
- Recalcula automaticamente após drag-and-drop (evento collection-fetched)
- Não requer rebuild, não requer reinstalar extensão — apenas clear-cache
