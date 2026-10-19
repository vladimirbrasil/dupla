# Bancada do `delegate` — resultados

Registro das rodadas que decidiram (ou confirmaram) o modelo default do `delegate`.

### Filosofia e Critério de Decisão
- **JAMAIS ter pressa:** tempo de relógio é apenas secundário ou proxy de turnos, nunca o objetivo final.
- **SEMPRE priorizar a economia de tokens/cota:** o custo de contexto cumulativo é o recurso mais escasso.
- **Custo-benefício (qualidade / tokens):** não buscamos "força bruta" que queima 3× a 5× mais tokens para obter 1% a mais de sofisticação cosmética. Buscamos o modelo de **maior rendimento por token** — aquele que atinge a precisão exigida (100% de testes e invariantes de contrato respeitados) com a maior sobriedade de passos, sem desperdiçar tokens de raciocínio inflados. Só vale adotar um modelo mais gastador se ele for **muito, muito melhor** nos testes que elaboramos.

Legenda: `f1` = rename com chave de protocolo intocável; `f2` = N+1→lote com juiz oculto
(5 invariantes que nenhum teste do repo cobre).

## 19/10/2026 — 3.8 Flash Low × 4.0 Argon Low × 4.0 Argon Medium → **default vira Gemini 4 Argon Low**

**Aplicação da Filosofia nesta Rodada:**
> *"Qualidade robusta e suficiente com o menor gasto de tokens possível — zero pressa."*
> Entrega correta de contratos e testes gastando a menor fatia da cota.

Comparação direta entre a geração 3.8 Flash e a geração 4.0 Argon (`gemini-4-argon-*`). Além do tempo de relógio, foi realizada auditoria direta nos transcripts do `agy` (`~/.gemini/antigravity-cli/brain/*/transcript.jsonl`) medindo o consumo real de tokens (novos inputs, cache lido e outputs gerados) e passos/ferramentas:

| modelo | f1 (tempo) | f2 (tempo) | tempo total | passos (f1+f2) | tool calls | tokens entrada novos | tokens cache lido | tokens saída | volume total de contexto | testes | juiz |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **gemini-4-argon-low** | 84s | 52s | **136s** | **31** (20+11) | **20** | **51.261** | **110.057** | **4.268** | **165.586** | 3/3 | 5/5 |
| gemini-4-argon-medium | 68s | 86s | 154s | 32 (17+15) | 18 | 70.563 | 150.679 | 5.382 | 226.624 | 3/3 | 5/5 |
| gemini-3.8-flash-low | 109s | 81s | 190s | 72 (46+26) | 34 | 198.783 | 509.150 | 5.518 | 713.451 | 3/3 | 5/5 |

*(Todos entregaram diffs limpos e perfeitos: `legacy.js` preservado com valor correto na f1, e `Map` com ordenação/nulls na f2).*

**Análise sob a ótica de máxima economia de tokens:**
1. **O vencedor absoluto é o `gemini-4-argon-low`**:
   - Gastou **~75% MENOS tokens de entrada novos** que o 3.8 Flash Low (51k vs 198k).
   - O volume total processado na janela de contexto foi **4,3× MENOR** (165k vs 713k).
   - Precisou de menos da metade dos passos (31 vs 72) e quase metade das chamadas de ferramentas (20 vs 34). O 3.8 dá muito mais voltas e re-inspeções para chegar ao mesmo lugar, acumulando histórico repetido no contexto.
2. **Low vs Medium no Argon 4.0**:
   - O **Argon Low** consumiu **27% menos tokens** que o Argon Medium (165k vs 226k) para entregar exatamente a mesma qualidade. O medium gasta mais tokens de pensamento/output sem ganho algum no diff final.
3. **Decisão:**
   - **`gemini-4-argon-low`** vence tanto no critério de tokens/eficiência quanto no critério de relógio. É o modelo mais sóbrio e econômico testado até hoje no `agy`.

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
