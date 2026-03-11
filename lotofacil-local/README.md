# Fechamentos de Loterias (Local)

Aplicacao local com backend e frontend para:

1. Buscar concursos recentes na API publica da Caixa.
2. Calcular metricas percentis para sugerir dezenas base.
3. Gerar fechamento de jogos.
4. Exportar para Excel (`.xlsx`).
5. Planejar quantidade de jogos por orcamento mensal.
6. Aplicar fator de variacao para diversificar dezenas base.

## Loterias e modelos

### Lotofacil
- `19 dezenas -> 164 jogos (reduzido heuristico)`

### Mega-Sena
- `8 dezenas -> 28 jogos (fechamento completo)`
- `9 dezenas -> 84 jogos (fechamento completo)`
- `10 dezenas -> 210 jogos (fechamento completo)`
- `10 dezenas -> 60 jogos (reduzido heuristico)`

## Requisitos

- Python 3.9+
- Internet ativa para consultar a API da Caixa

## Como executar

```bash
cd "/Users/adrianobenignopavao/Documents/New project/lotofacil-local"
python3 app.py
```

Acesse: [http://127.0.0.1:8080](http://127.0.0.1:8080)

## Observacoes

- Na Mega-Sena, os modelos completos (8/9/10 dezenas) sao os mais usados por apostadores que fazem desdobramento manual.
- Os modelos reduzidos sao heuristicas de balanceamento; nao ha garantia matematica oficial de premiacao.
- Com orcamento mensal e preco por jogo, o sistema calcula automaticamente quantos jogos cabem no seu limite.
- O fator de variacao (0 a 100%) reduz dependencia do ranking puro dos ultimos concursos e aumenta diversidade nas dezenas base.

## Automacao de preenchimento no site

Foi adicionada uma automacao separada em:

- `/Users/adrianobenignopavao/Documents/New project/lotofacil-local/automation`

Ela le o Excel gerado e preenche os jogos no navegador (sem confirmar pagamento).
Veja instrucoes em:

- `/Users/adrianobenignopavao/Documents/New project/lotofacil-local/automation/README.md`
