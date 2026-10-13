# Bancada do `delegate` — resultados

Registro das rodadas que decidiram (ou confirmaram) o modelo default do `delegate`.
Critério: **entre os modelos que entregam o mesmo diff, fica o mais rápido.** As fixtures
estão saturadas de propósito — quem passa, passa; o que separa é o relógio e o lixo deixado
para trás. Quando a bancada empatar sempre, é sinal de que ela precisa de uma fixture mais
difícil, não de que os modelos são iguais em tudo.

Legenda: `f1` = rename com chave de protocolo intocável; `f2` = N+1→lote com juiz oculto
(5 invariantes que nenhum teste do repo cobre).

## 13/10/2026 — 3.8 Flash low × medium × GPT-OSS 120B → **default vira 3.8 Flash Low**

agy 1.3.4, que deixou de listar o 3.7 Flash e o 3.1 Pro (`agy models` traz só 3.8 Flash
low/medium/high, os Claude 5.5 e o GPT-OSS 120B). O 3.8 Flash High, default provisório do dia,
esgotava a cota individual em poucas tarefas. Pergunta da rodada: qual esforço entrega o mesmo
diff gastando menos? Rodada única. O agy não registra contagem de tokens; o relógio é o proxy
de cota (mais passos e mais chamadas de ferramenta = mais tempo e mais cota).

| modelo | f1 | f2 | total | testes | juiz | observação |
|---|---|---|---|---|---|---|
| gemini-3.8-flash-low | 62s | 70s | **132s** | 3/3 | 5/5 | limpo: README e `test/` renomeados, chave de fio com o valor certo |
| gemini-3.8-flash-medium | 336s | — | — | 3/3 (f1) | — | f1 tão lento quanto o high, e com fallback morto `cfg.backoffBaseMs ?? cfg.retryDelayMs` em `legacy.js`; f2 **não rodou** (429, cota esgotada) |
| gpt-oss-120b-medium | 250s | 53s | 303s | 3/3 | 5/5 | ⚠️ deixou a opção antiga no `README.md` e em 2 chamadas de `test/retry.test.js`; em `legacy.js` leu `cfg.retryDelayMs ?? cfg.backoffBaseMs` (nome antigo primeiro) |
| gemini-3.8-flash-high (10/09, referência) | 260–332s | 85–109s | 345–441s | 3/3 | 5/5 | não rodado de novo, para poupar cota |

**Decisão:** default = `gemini-3.8-flash-low`. Mesmo diff limpo do high em ~1/3 do relógio.
`--think high` fica para tarefa difícil/longa, ou quando a revisão do diff mostrar retrabalho.

**Medium não compensa** nesta amostra: gastou o relógio do high na f1 e entregou pior. É o
mesmo desenho do 3.7 em 10/09 (medium foi o pior dos três esforços). Uma rodada só — não é
veredito, mas não há motivo para escolhê-lo.

**GPT-OSS 120B tem cota separada** (uma observação): rodou as duas fixtures logo depois de o
Gemini devolver `RESOURCE_EXHAUSTED: Individual quota reached`. A qualidade é inferior (o
"verde que esconde" na f1), então serve de reserva **manual** para transform simples quando o
Gemini estiver sem cota, com revisão de diff redobrada — não de fallback automático:

```sh
DELEGATE_MODEL=gpt-oss-120b-medium delegate "<transform simples>"
```

**`--think pro` passa a ser recusado** (exit 2 com a saída indicada): o 3.1 Pro não existe mais
no agy, e um slug inexistente falha com exit 0 e resposta vazia.

**Pendente:** segunda rodada do low quando a cota voltar (esta foi única), e a f2 do medium.

## 10/09/2026 — 3.8 × 3.7 × 3.6 Flash (High) → **default vira 3.7 Flash High**

agy 1.2.0. Todos passaram os 3 testes do repo e 5/5 do juiz oculto, com diff equivalente
(diferença só de nome de variável local).

| modelo | f1 | f2 | total | testes | juiz | observação |
|---|---|---|---|---|---|---|
| gemini-3.7-flash-high (r1) | 60s | 36s | **96s** | 3/3 | 5/5 | limpo |
| gemini-3.7-flash-high (r2) | 66s | 38s | **104s** | 3/3 | 5/5 | limpo |
| gemini-3.6-flash-high | 171s | 26s | 197s | 3/3 | 5/5 | limpo |
| gemini-3.8-flash-high (r1) | 332s | 109s | 441s | 3/3 | 5/5 | ⚠️ deixou 2 chamadas com a opção antiga (`retryDelayMs: 1`) em `test/retry.test.js` |
| gemini-3.8-flash-high (r2) | 260s | 85s | 345s | 3/3 | 5/5 | limpo |

Esforços menores do 3.7 (para `--think low|med`), rodada única:

| modelo | f1 | f2 | total | testes | juiz | observação |
|---|---|---|---|---|---|---|
| gemini-3.7-flash-low | 59s | 35s | 94s | 3/3 | 5/5 | limpo |
| gemini-3.7-flash-medium | 112s | 55s | 167s | 3/3 | 5/5 | deixou fallback morto `cfg.backoffBaseMs ?? cfg.retryDelayMs` em `legacy.js` |

**Decisão:** default = `gemini-3.7-flash-high`. Capacidade empatada, 1/4 do relógio do 3.8.

**Sobre o 3.8.** Não é pior — é mais caro em tempo porque "trabalha mais" (mais passos de
raciocínio e mais chamadas de ferramenta). Os benchmarks publicados só o separam do 3.7 no
que é difícil de verdade: Terminal-Bench 2.1 90,8 × 81,6; SWE-Bench Pro 61,6 × 60,4; HLE-V
54,9. A bancada é fácil demais para enxergar isso — por isso ele fica como escape hatch:

```sh
DELEGATE_MODEL=gemini-3.8-flash-high delegate "<briefing de tarefa difícil/longa>"
```

O deslize da r1 (opção renomeada no `src/`, chamada antiga sobrando no `test/`, testes
verdes porque o default do config assume o valor) é **exatamente** o modo de falha que a
bancada existe para pegar, e não se repetiu na r2 — trate como ruído com sinal, não como
veredito. O 3.7 não errou em nenhuma das duas.

**`--think pro` continua no 3.1 Pro:** duas gerações atrás em execução, mas ainda à frente por
pouco em raciocínio puro (GPQA Diamond 95,5 × 94,4 do 3.8 Flash, medição independente Vals AI)
e em needle-in-haystack (MRCR v2). Serve também como segunda opinião de modelo diferente num
`--redo`.

## 30/07/2026 — 3.6 Flash × 3.1 Pro × Sonnet 4.6 → **default sai do 3.1 Pro**

3.6 Flash (High/Med/Low), 3.1 Pro (High) e Sonnet 4.6 entregaram diff equivalente e 100% do
juiz oculto. O 3.1 Pro foi o mais lento (229s × ~125s). Mesma capacidade, metade do relógio.
