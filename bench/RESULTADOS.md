# Bancada do `delegate` — resultados

Registro das rodadas que decidiram (ou confirmaram) o modelo default do `delegate`.
Critério: **entre os modelos que entregam o mesmo diff, fica o mais rápido.** As fixtures
estão saturadas de propósito — quem passa, passa; o que separa é o relógio e o lixo deixado
para trás. Quando a bancada empatar sempre, é sinal de que ela precisa de uma fixture mais
difícil, não de que os modelos são iguais em tudo.

Legenda: `f1` = rename com chave de protocolo intocável; `f2` = N+1→lote com juiz oculto
(5 invariantes que nenhum teste do repo cobre).

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
