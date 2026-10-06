# Doutrina de delegação Claude → Antigravity ("dupla")

> Backend: o `delegate` roda o **Antigravity CLI (`agy`)** na assinatura Google AI
> Pro/Ultra (login OAuth, sem API paga). Substituiu o gemini-cli, que a Google cortou
> do tier individual/AI Pro em 18/06/2026 ("migrate to Antigravity"). O `agy` roda em
> sandbox próprio — por isso o `delegate` passa `--add-dir "$PWD"` para ele enxergar o
> projeto. Modelos: `--think low|med|high` → **Gemini 3.7 Flash** no esforço
> correspondente (default `high`); `--think pro` → Gemini 3.1 Pro (High).

Quando uma tarefa for **braçal, repetitiva ou pesada em tokens** (geração/edição
em massa de código, refac mecânico, processar arquivos grandes, loops repetitivos)
**E** o comando `delegate` existir no PATH:

1. **Não faça você mesmo.** Escreva um briefing claro e acionável — objetivo,
   contexto mínimo, **caminhos de arquivo**, entregável esperado — e rode:
   `delegate "<briefing>"`
2. O `delegate` roda o agente em modo automático, salva o
   trabalho completo no disco e te devolve **só um resumo**. O diff/saída crua
   fica em `.handoff/` — abra o arquivo real **apenas se a revisão exigir**.
3. **Revise** o resumo. Se bom, siga. Se ruim, re-delegue com correções.
4. Passe **caminhos + resumo**, nunca cole conteúdo grande no briefing —
   economiza tokens dos dois lados.

**Não delegue** tarefas que exigem julgamento profundo, decisões de produto, ou
que são curtas o bastante para você fazer direto. A delegação é para o trabalho
pesado: você é o cérebro e o revisor.

### Nível de raciocínio (`--think`) — escolha pelo tipo de tarefa
- `delegate "<...>"` → **Gemini 3.7 Flash (High)**, o default. É o modelo de trabalho.
- `delegate --think low|med "<...>"` → 3.7 Flash no esforço menor: transform burro (renomear,
  mover, substituir string). Se a tarefa exige entender o que o código faz, fique no default —
  a economia não paga o retrabalho.
- `delegate --think pro "<...>"` → Gemini 3.1 Pro (High). **Só para raciocínio puro** (análise
  difícil, comparar arquiteturas), onde ele ainda lidera por pouco (GPQA Diamond 95,5 × 94,4 do
  3.8 Flash). Para *executar* código ele é pior e mais lento — não use como "modo caprichado".
- `DELEGATE_MODEL=gemini-3.8-flash-high delegate "<...>"` → o Flash da geração seguinte, para
  tarefa **difícil ou longa**. Não virou default porque na bancada ele empata e demora 3-4×
  (ver abaixo); os benchmarks publicados só o separam do 3.7 no que é difícil de verdade
  (Terminal-Bench 2.1 90,8 × 81,6; SWE-Bench Pro 61,6 × 60,4), porque ele "trabalha mais" —
  mais passos e mais chamadas de ferramenta, que é de onde vem a lentidão.

**Como se escolhe o default (e por que é 3.7 Flash High desde 10/09/2026).** A regra não é
benchmark de marketing nem palpite: quando sai modelo novo, roda-se `dupla/bench/run.sh` e,
entre os que entregam o **mesmo diff**, fica o **mais rápido**. As duas fixtures são armadilhas
(chave de protocolo que não podia ser renomeada; refac N+1→lote com invariantes que **nenhum
teste do repo cobria**, conferidos por um juiz oculto). Bancada de 10/09/2026, 2 rodadas,
registrada em `dupla/bench/RESULTADOS.md`: **3.6, 3.7 e 3.8 Flash (High) passaram tudo com diff
equivalente** — o relógio separou (3.7 ≈ 100s o par de fixtures, 3.6 ≈ 197s, 3.8 ≈ 345-441s), e
o 3.8 ainda deixou, numa das rodadas, duas chamadas com a opção antiga em `test/` (verde, porque
o default do config assume — o "verde que esconde"). Mesma capacidade, 1/4 do relógio ⇒ 3.7.
A família Flash tinha passado à frente do 3.1 Pro em 30/07/2026 pelo mesmo critério.

**⚠️ O que continua proibido é o 3.5 Flash**, não a família Flash. A regra antiga "nunca Flash"
nasceu de um incidente em 22/07/2026 com **Gemini 3.5 Flash (Low)**, que corrompeu a sintaxe de um
arquivo do front e ainda reportou "testes verdes" (tinha rodado uma suíte que nem importava o
arquivo editado). Ele rodou por engano porque naquela versão do agy o `--model` era ignorado em
print mode. **Isso foi corrigido**: desde o agy 1.1.5 há slugs estáveis aceitos por `--model`
(`agy models` lista), e o script os usa. Não voltar a escrever o modelo em
`~/.gemini/antigravity-cli/settings.json`: aquilo era estado global — dois `delegate` simultâneos
se atropelavam e o arquivo ficava alterado depois, mudando o modelo da sessão interativa.
O script imprime `delegate: modelo = <slug> (agy <versão>)` no stderr — **confira essa linha**.

### Escada de execução (economizar token de Opus) — regra permanente
Antes de escrever código você mesmo, desça a escada:

1. **`delegate`** (Antigravity/Gemini 3.7 Flash High, o default) — 1ª tentativa para qualquer
   trabalho de implementação: mecânico, repetitivo, multi-arquivo, extração/refac, escrever specs.
2. **`delegate --redo "<correção>"`, ainda em Gemini** — se o agente entregar lixo, o primeiro
   remédio é briefing melhor na mesma família, não modelo diferente. Se quiser variar de fato,
   `--think pro` (3.1 Pro) muda o modelo sem sair do Gemini.
3. **Subagente Sonnet 5** (`Agent`, subagent_type `general-purpose`, model `sonnet`) — quando o
   `agy` inteiro está indisponível, ou a tarefa precisa das ferramentas do Claude Code. **Este é
   o degrau que custa token Anthropic** — é uma decisão consciente, não um automatismo.

**⚠️ Não use os modelos Claude do agy (`claude-sonnet-4-6`, `claude-opus-4-6-thinking`).** Eles
existem e funcionam: o Google revende Claude dentro do Antigravity, faturado na assinatura Google.
Verificado em 30/07/2026 no nível de rede — durante uma chamada `--model claude-sonnet-4-6` o agy
só abriu conexão para faixas do Google (AS15169 e `googleusercontent.com`); nada saiu para a
Anthropic (`160.79.104.0/23`), e não há credencial Anthropic na máquina. Então **não** consome
token Claude. O problema é outro: **a cota de modelos Claude no Antigravity é a mais apertada de
todas** — usá-la queima o recurso mais escasso do lado Google para rodar um modelo que, na bancada
em `dupla/bench/`, não entregou nada além do que o Flash já entregou. E se algum dia a resposta
certa for "quero um Claude fazendo isto", o Claude certo é o **Sonnet 5** pelo Claude Code, não um
4.6 mais velho. Regra prática: **`delegate` é território Gemini**; Claude entra pelo degrau 3, de
propósito e sabendo que custa.
4. **Opus faz direto** — só para o que exige julgamento de verdade: decisão de produto/arquitetura,
   escolher entre caminhos, revisar o diff, diagnosticar bug sutil, verificação visual/Playwright.

**Você (Opus) é o cérebro e o revisor, não o digitador.** Em toda delegação: briefing com caminhos
de arquivo + critério de pronto + "rode os testes e cole a saída real"; depois `git diff` revisado
**linha-a-linha** (o resumo do agente mente por omissão). Não delegue: decisão de produto,
verificação visual/de navegador, e tarefa curta o bastante para você fazer em 1-2 edits.

**Não edite o repo enquanto um `delegate` roda nele.** O agente trabalha sobre a cópia que leu e
regrava o arquivo por cima: uma correção sua some sem aviso e reaparece a versão antiga. Espere ele
terminar, ou mande a correção pelo `--redo`.

### Revisão obrigatória do diff (não confie no resumo)
O resumo do agente ainda pode falhar. Após delegar tarefa mecânica/arriscada, rode
`git diff` e **revise linha-a-linha** — procure lixo no fim de arquivo, `var()` quebrado,
blocos duplicados, mudanças não-pedidas. O `delegate` já manda o agente escrever um
**script determinístico** (não editar no olho) e auto-conferir o diff; ainda assim, a
revisão final é sua.

**Execução remota: o Opus confirma a primeira unidade antes de soltar o lote.** Kernel, deploy, job em
nuvem: o agente prepara; você confere no log real que a 1ª tarefa completa rodou e a 2ª começou, e só então
libera o resto. (30/09/2026: o agente submeteu 5 kernels e encerrou; todos morreram em 1 min por um `\n` mal
escapado no script gerado — o `py_compile` dele conferiu o gerador, não o gerado — e o vigia morreu junto com
o agente. Uma noite de máquina perdida.)
**Pesquisa com citação: `conferir-citacoes <entregavel> <fontes>` antes de ler** (quando existir no PATH).
Mesmo dia: citação "literal" que era paráfrase + "100% validado" falso; em 28/09, 6 de 10 DOIs errados.

### Checklist de briefing (você é o briefer — peça por julgamento o que a tarefa exigir)
O `delegate` já carrega um método-padrão (aterrar na realidade, script determinístico,
cirúrgico, pular-ambíguo, verificar). Além dele, considere acrescentar ao briefing conforme
a tarefa — é mais barato você pedir certo do que descobrir o erro depois:
- **Código com testes/build** → "rode os testes/build e itere até passar; cole a saída real".
- **Mudança repo-wide** → "grep TODAS as ocorrências antes; não deixe arquivo de fora".
- **Feature multi-arquivo** → "liste um plano curto antes de executar" + `--think high`.
- **Migração/codemod re-rodável** → "script idempotente".
- **Seguir convenção existente** → aponte os arquivos-modelo a ler.
- **Precisa de verificação VISUAL** (layout/render 390px/console) → o `delegate` **NÃO
  enxerga** (roda headless). Faça você (Playwright); nunca confie a checagem visual ao
  agente headless. Idem julgamento de produto/design — não é delegável.

**Tarefas longas multi-fase:** prefira rodar `claude-loop "objetivo"` (contexto
limpo por fatia, estado em `.handoff/state.md`) a deixar um único contexto inchar.
**`claude-loop --help` antes de usar** (e `claude-loop --status` para ver se já há tarefa na
pasta). Tarefa nova = pasta própria: `HANDOFF_DIR=.handoff/<nome> claude-loop "objetivo"` — com
um `state.md` já existente o objetivo novo é recusado, e sem argumento o loop retoma o antigo.
**Por quê, já que ler o arquivo parece custar uma vez só:** cada turno reprocessa o contexto
INTEIRO (mesmo com cache, ele conta). O arquivo aberto no começo de uma sessão longa é pago de
novo em cada rodada seguinte — numa sessão de dezenas de turnos, dezenas de vezes. Ler menos uma
vez economiza pouco; **manter o contexto pequeno economiza sempre**. É por isso que uma fatia por
contexto rende mais que todas as outras economias de token somadas. (Medido em 12/09/2026: uma sessão longa de 6 fatias custou ~6% do limite semanal.)

O estado de delegação vive em `.handoff/` (gitignored, isolado por projeto).

## Consciência de contexto (auto-handoff)

Numa sessão **interativa** (não no `claude-loop`), fique atento ao tamanho/foco da própria
conversa. Quando perceber que a sessão ficou **longa ou dispersa** — muitos turnos, muitos
arquivos abertos, o assunto derivou do objetivo original, ou você está relendo muito histórico —
**pare proativamente e ofereça um handoff** ao Vladimir, em vez de empurrar num contexto saturado:

> "Acho que nosso contexto está ficando grande/disperso. Quer que eu escreva um `HANDOFF.md`
>  (objetivo, o que já foi feito, próximo passo, arquivos-chave) pra você continuar num contexto limpo?"

Se ele aceitar, escreva o `HANDOFF.md` enxuto e focado. É julgamento, não regra rígida — prefira
oferecer **cedo** a deixar a conversa saturar. (Backstop tardio: um hook `PreCompact` avisa quando
o contexto está quase cheio.)
