# EscopoCRM — Guia de Verificação Pós-Deploy
## Alvo/Foco com Mira | 15/05/2026

---

## O que foi feito

| # | O que | Onde |
|---|---|---|
| 1 | Campo `statusProspeccao` (bool) criado na tabela `account` | entityDefs/Account.json |
| 2 | Campo `porQueFoco` (text) criado na tabela `account` | entityDefs/Account.json |
| 3 | Campo `tipoEscalao` (enum A/B/C) criado na tabela `account` | entityDefs/Account.json |
| 4 | Campo `porQueAlvo` (text) criado na tabela `account` | entityDefs/Account.json |
| 5 | Botão mira ⊙ adicionado ao detail da Account | clientDefs/Account.json |
| 6 | Handler JS criado com lógica toggle + modal obrigatório | alvo-foco-handler.js |
| 7 | Filtro `statusProspeccao` registrado na busca de Contas | searchFilters.json |
| 8 | Extensão rebuilda e instalada | linkedin-prospect-1.0.0.zip |
| 9 | Banco migrado (colunas criadas via rebuild) | tabela account |
| 10 | Cache limpo e PHP-FPM reiniciado | servidor |

---

## Checklist de verificação — passo a passo

### 1. Verificar ícone na tela de detalhe

```
1. Abra http://148.72.177.131 no browser
2. Faça Ctrl+Shift+R (hard refresh obrigatório)
3. Vá em Contas → clique em qualquer conta
4. Olhe o canto superior direito da tela

ESPERADO:
  [Editar] [•••]  [⊙]  [Seguir]
                   ^
               ícone mira cinza = Alvo

SE NÃO APARECER:
  → Rodar: php /opt/espocrm/www/command.php clear-cache
  → Rodar: php /opt/espocrm/www/command.php rebuild
  → Reiniciar: systemctl restart php8.3-fpm
  → Tentar Ctrl+Shift+R novamente
```

---

### 2. Testar toggle Alvo → Foco

```
1. Com a conta aberta, clique no ícone ⊙ (mira cinza)

ESPERADO:
  → Abre modal "Por que é Foco?"
  → Campo textarea obrigatório

2. Clique em "Confirmar Foco" SEM preencher

ESPERADO:
  → Mensagem de erro: "Campo obrigatório: informe o motivo."
  → Modal NÃO fecha

3. Preencha o motivo e clique "Confirmar Foco"

ESPERADO:
  → Modal fecha
  → Ícone muda para ⊕ azul preenchido
  → Toast de sucesso: "Conta marcada como Foco."
  → Borda do botão fica azul
```

---

### 3. Testar toggle Foco → Alvo

```
1. Com conta em Foco (ícone ⊕ azul), clique no ícone

ESPERADO:
  → Abre confirmação: "Remover status Foco? A conta voltará para Alvo."
  → Botões: [Confirmar] [Cancelar]

2. Clique em Confirmar

ESPERADO:
  → Ícone volta para ⊙ cinza
  → Toast: "Conta voltou para Alvo."
```

---

### 4. Verificar persistência no banco

```
1. Marque uma conta como Foco
2. Recarregue a página (F5)

ESPERADO:
  → Ícone continua ⊕ azul (persistiu no banco)

Verificação direta no MySQL:
  mysql -u espocrm espocrm \
    -e "SELECT name, status_prospeccao, por_que_foco FROM account LIMIT 5;"

ESPERADO:
  → Coluna status_prospeccao com valor 1 para contas Foco
  → Coluna por_que_foco com o texto preenchido
```

---

### 5. Verificar filtro na listagem

```
1. Vá em Contas (listagem)
2. Clique em "Busca Avançada" ou no ícone de filtro
3. Procure o campo "Foco" ou "Status Prospecção"

ESPERADO:
  → Campo aparece como checkbox na busca
  → Marcando o checkbox e buscando → mostra só contas Foco

SE NÃO APARECER:
  → Admin → Entity Manager → Account → Search Filters
  → Adicionar "statusProspeccao" manualmente
  → Rebuild
```

---

### 6. Verificar campos via API REST

```bash
curl -s \
  -u "admin:Fabio@2026" \
  "http://148.72.177.131/api/v1/Account?maxSize=2&select=name,statusProspeccao,tipoEscalao,porQueFoco" \
  | python3 -m json.tool

ESPERADO:
  → JSON com "statusProspeccao": false/true
  → JSON com "tipoEscalao": "" / "A" / "B" / "C"
  → JSON com "porQueFoco": null ou texto
```

---

### 7. Testar importação da planilha

```
Preparar CSV com as colunas:
  name, industry, linkedinUrl, tipoEscalao, porQueAlvo

1. Vá em Contas → clique nos "•••" → Importar
2. Faça upload do CSV
3. Mapeie as colunas:
   - Conta        → name
   - Setor        → industry
   - LinkedIn     → linkedinUrl
   - Tipo (A/B/C) → tipoEscalao
   - Por que alvo → porQueAlvo
4. Marque "linkedinUrl" como campo de duplicidade (upsert)
5. Conclua a importação

ESPERADO:
  → Contas criadas/atualizadas sem erros
  → Campo Escalão preenchido com A, B ou C
  → Campo "Por que é Alvo" com o texto da planilha
  → Ícone ⊙ (Alvo) em todas as contas importadas
```

---

### 8. Verificar log em caso de erro

```bash
# Log do EspoCRM em tempo real
tail -f /opt/espocrm/www/data/logs/espo-$(date +%Y-%m-%d).log

# Log do deploy
ls -lt /opt/espocrm/www/data/logs/deploy_alvo_foco_*.log | head -3

# Erros de PHP-FPM
journalctl -u php8.3-fpm -n 50
```

---

## Referência rápida — comandos de fix

```bash
# Se o botão não aparecer
php /opt/espocrm/www/command.php clear-cache
php /opt/espocrm/www/command.php rebuild
systemctl restart php8.3-fpm

# Se colunas não foram criadas
php /opt/espocrm/www/command.php rebuild --fix

# Se precisar reinstalar a extensão
php /opt/espocrm/www/command.php extension \
  --file=/opt/linkedin-prospect/build/linked-in-prospect-1.0.0.zip

# Verificar colunas no banco
mysql -u espocrm espocrm \
  -e "SHOW COLUMNS FROM account;" | grep -E "status_|por_que|tipo_"
```

---

*Documento gerado automaticamente pelo deploy_alvo_foco.sh — EscopoCRM Decatron*
