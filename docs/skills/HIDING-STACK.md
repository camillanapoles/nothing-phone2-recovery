# Pilha de ocultação — revisão 2026-11-02 (KSU-Next + SUSFS)

> **Escopo:** operação no aparelho. O contrato que o *solver* usa continua sendo
> `references/hiding-stack.json` (quais capacidades o par motor × kernel precisa entregar);
> **este** documento descreve o que se instala e em que ordem, e está amarrado ao combo em
> `references/install-stack.json` (fase F4). Nenhum dos dois substitui o outro.
> **Gate:** `make stack` cobra conflito, ordem e pin; a matriz de detecção é o teste de campo.

## 1. Correções sobre o que circula por aí

| Afirmação | Veredito | Fato |
|---|---|---|
| Zygisk Assistant está obsoleto | **correta** | removido dos guias desde jun/2025; o motivo é redundância + abandono, não "falha de interceptação" |
| Shamiko é legado e closed-source | **correta** | Zygisk Next ≥1.3.0 integrou a maior parte dele e **bloqueia o carregamento**; o sintoma no KSU-Next é falha de instalação, não bootloop |
| "Shamiko conflita com namespaces do KSU-Next e causa bootloop" | **não evidenciada** | não existe fonte para esse mecanismo; repetir isso é criar requisito fantasma |
| KSU-Next App Profile + Zygisk Next + NoHello é o SOTA | **correta no espírito** | com três correções de vocabulário: o toggle é *Umount modules*, o modo do ZN é `just_umount`, e o NoHello é **condicional** |
| "ganchos em Rust" e "isolamento geométrico" | **marketing** | Rust existe no TEESimulator-RS, não no hiding. O que existe: unmount por namespace, SUSFS no kernel e injeção no zygote |

## 2. Ordem de força (o que entra e em que sequência)

| Ordem | Camada | O que esconde | Obrigatória |
|---|---|---|---|
| 1 | **SUSFS** (kernel patchado + `susfs4ksu` R28) | paths, mounts, kstat, uname | sim |
| 2 | **KSU-Next — Umount modules por app** | os módulos montados | sim |
| 3 | **Zygisk Next** `just_umount` + `linker builtin` + `memory-type anonymous` | a própria injeção | sim |
| 4 | **NoHello v0.0.8** (whitelist) | rastros residuais | condicional |
| 5 | **HMA-OSS** | lista de apps instalados | opcional |
| — | Shamiko · Zygisk Assistant · dois Zygisks · NoHello + Shamiko · Yurikey · Integrity Box | — | **vetados** |

### Comandos verificáveis do Zygisk Next (efeito imediato, sem reboot)

```
/data/adb/modules/zygisksu/bin/zygiskd enforce-denylist just_umount
/data/adb/modules/zygisksu/bin/zygiskd linker builtin
/data/adb/modules/zygisksu/bin/zygiskd memory-type anonymous
```

Isso é o que torna a fase F4 testável: o estado é conferível por comando, não por "cliquei em algo".

### Dois detalhes que quebram a pilha se ignorados

- **SUSFS userspace é obrigatório mesmo com kernel patchado** — sem o módulo, os dependentes
  falham com `susfs not found`. E as versões têm de casar: kernel com SUSFS ≥ 1.5.2 ↔ módulo
  `v1.5.2+_R28`. Mismatch gera erro de build e, pior, atestação quebrada.
- **Zygisk Next é binário fechado** (licença proprietária desde ~1.0) rodando como root. É a
  mesma dívida de auditoria do motor de atestação. Fica registrada como **dívida declarada**:
  `NeoZygisk` (JingMatrix, aberto) é o candidato a validar, não o default — há relatos de
  ReZygisk não instalar em KSU-Next + SUSFS, e estabilidade vence pureza de licença aqui.

## 3. Matriz de detecção (o teste que vale)

| App | O que tem de reportar |
|---|---|
| Ruru / Duck Detector | sem root, sem zygisk, sem mount inconsistency, sem sus path |
| 2 apps reais do uso diário (banco / One) | abrem e autenticam |
| Play Integrity checker | BASIC + DEVICE (STRONG só se necessário) |

**Falseabilidade:** cada linha tem contra-exemplo explícito. Se o detector acusar *mount
inconsistency*, o problema é a camada 2 (umount por app). Se acusar *zygisk*, é a camada 3.
Se acusar *sus path*, é a camada 1. A matriz não diz "está oculto" — diz **qual camada falhou**.

## 4. O que não é demonstrável

Ocultação perfeita não existe: sempre sobra superfície (timing, syscalls, atestação). O
compromisso deste projeto é o oposto de "confiar": é **medir por app** e deixar o resultado
reproduzível. Nada aqui é "garantia"; é conjunto de testes com PASS ou PENDENTE.
