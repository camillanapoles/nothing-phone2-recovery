# `archive/` — memória, não contrato

Tudo aqui é **passado congelado**. Vale a regra do `docs/skills/LEGACY-INDEX.md`:

```text
CONTRATO VIGENTE              -> AGENTS.md · agente.md · skills/*/SKILL.md + references/
CONTRATO EXECUTÁVEL           -> audit-fsm/src (FSM determinístico, read-only)
EVIDÊNCIA (não decide)        -> docs/skills/
MEMÓRIA (proibida como regra) -> state/quarantine/<UTC>/ · archive/ · ci*/
```

Consequências práticas, para não haver dúvida:

1. **Nada aqui é fonte de regra.** Se `archive/` e `skills/evox-rom-ci-optimizer/references/*.json`
   discordarem, quem manda é o `references/` — sempre.
2. **Nada aqui é insumo de pipeline.** Um documento arquivado não gera fila, não gera passo de
   instalação e não autoriza nada. Se um script precisar de um dado que só existe aqui, o dado
   deve ser promovido para `references/` — e aí ele passa a ter fonte, gate e mutante.
3. **Não se reescreve o passado para ele parecer atual.** Número datado continua datado; o que
   muda é o carimbo no topo (`HISTÓRICO — NÃO EXECUTAR`) e o registro em
   `skills/evox-rom-ci-optimizer/references/legacy-sources.json`, que é o que o gate lê
   (`make -s escopo`).
4. **Arquivar não é apagar.** O caminho antigo entra em `legacy-sources.json → removed`: se
   voltar para a raiz, o gate reprova (regressão), não importa quem trouxe.

## Conteúdo

| caminho | o que foi | por que está aqui |
|---|---|---|
| `archive/zeroharcoderd/` | base de conhecimento "zero hardcoded" (24 arquivos: versões, receitas de módulo, troubleshooting) | é **anti-pattern de nascença**: chamava-se "zero hardcoded" e guardava `v1.4.5`, `v17`, `TrickyStore v1.4.1`, receita de kernel próprio do DroidSpaces — números colados à mão, contradizendo as decisões vigentes. Virou memória; a fonte é `references/` |
