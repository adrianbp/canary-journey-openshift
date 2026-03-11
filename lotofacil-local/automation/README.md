# Automacao de preenchimento no site da loteria

Esta automacao:

1. Le o arquivo `.xlsx` gerado pelo sistema local.
2. Abre o navegador com Playwright.
3. Preenche os jogos automaticamente no site.
4. Nao confirma compra/pagamento.

## Requisitos

- Node.js 18+
- npm

## Instalacao

```bash
cd "/Users/adrianobenignopavao/Documents/New project/lotofacil-local/automation"
npm install
npx playwright install chromium
```

## Configuracao

Copie o arquivo de exemplo e ajuste seletores conforme o HTML atual do site:

```bash
cp config.example.json config.json
```

Campos:

- `siteUrl`: URL da loteria online.
- `selectors.clearSelection`: botao para limpar jogo atual (opcional).
- `selectors.addGame`: botao para adicionar o jogo ao carrinho (opcional, mas recomendado).
- `numberPattern`: regex para localizar dezenas nos botoes (`{n}` sera substituido).
- `delayBetweenNumbersMs`, `delayAfterGameMs`: pausas para estabilidade.

## Uso

### 1) Testar leitura da planilha (sem abrir navegador)

```bash
node loterias-automation.js \
  --excel "../output/megasena_fechamento_20260307_132829.xlsx" \
  --dry-run
```

### 2) Executar preenchimento

```bash
node loterias-automation.js \
  --excel "../output/megasena_fechamento_20260307_132829.xlsx" \
  --config "./config.json" \
  --headless false
```

### Opcoes uteis

- `--start 11`: comeca do jogo 11 da planilha.
- `--max 10`: preenche so 10 jogos.
- `--confirm-each`: pede ENTER entre jogos.

## Observacoes de seguranca

- Faca login manualmente.
- Revise os jogos antes de finalizar.
- Nao deixe credenciais salvas em scripts.
