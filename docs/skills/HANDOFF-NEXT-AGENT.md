# Handoff — instrução de prosseguimento (próximo agente)

**Estado:** branch `arena/863582fd-nothing-phone2-recovery` · skill `evox-rom-ci-optimizer` v3.1
**Data:** 2026-11-01 · **Suíte:** `make -s prove` verde · mutação **177/177 mortos por asserção**

> **Leia antes:** `docs/skills/CONTINUITY-INSTRUCTION.md` (memória, método, mandato, aprendizados,
> anti-padrões e como resolver dúvida). Para a kernel: `docs/skills/KERNEL-REQUIREMENTS.md`
> (requisitos e critério de 100% por módulo) e `docs/skills/KERNEL-BUILD-TEST-PLAN.md`
> (build no GitHub Actions, box de kernel, plano de teste do par). Este handoff cobre P1/P2/P3 e a
> operação do pack.

Este documento é a instrução operacional. Ele **não autoriza** nenhuma decisão de produto em nome
da usuária. O que está decidido está listado como decidido; o que falta está listado como pergunta.

---

## 1. P1 — Vanilla × GApps: **perguntar com dados, nunca escolher**

`P1` **continua aberta**. A escolha é da usuária ("ficar decisão minha em dado"). O agente:

1. **Não** assume variante, **não** baixa/instala/flasheia nada antes da resposta.
2 **Apresenta os dados abaixo** (já pinados em `references/rom-artifacts.json`) e pede a decisão.
3. Só depois de `session_open.py check` sair **0** (com `build.flavor_source == "user"`) prossegue.

O gate é executável, não é recomendação: `session_open.py check` marca `build.flavor_source`
pendente sempre que a variante não foi declarada pela usuária; `session_open.py auto` **limpa**
qualquer variante herdada em vez de reaproveitá-la.

### Dados para a decisão (builds pinadas — 2026-09-15, versão 11.11)

| | **Vanilla** | **GApps** |
|---|---|---|
| Arquivo | `EvolutionX-16.0-20260915-Pong-11.11-Vanilla-Official.zip` | `EvolutionX-16.0-20260915-Pong-11.11-Official.zip` |
| Tamanho | 2,36 GB | 3,4 GB |
| SHA-256 | `26be9ac8bb21f0843f369f996d9d905673a140cd25ed2125d12733edf7a687e1` | `79236f9b4259cf5df124dcd7176f8b4c30de0d755e189e8a4224a03e365422fb` |
| MD5 | `36fa6955fe12a54248342b9490e76963` | `e98f1e2f4e06bf3d281fe7ff4ed2375a` |
| Imagem inicial | **nenhuma** publicada para a build | `recovery.img` publicada (**com erros**) |
| Instalação | `adb sideload` | `adb sideload` (não `fastboot flash boot`) |
| Observação técnica | sem GApps/serviços Google; menor superfície | `recovery.img` com erro → extrair `boot.img` do ZIP antes de qualquer flash |

**Recomendação com base em dados (não é decisão):** se o objetivo é *performance* e menor
superfície de variáveis, Vanilla reduz ~1 GB de payload e não depende de `recovery.img` (que está
com erro na build GApps). Se o objetivo inclui *banking/IA e apps Google*, GApps evita retrabalho de
reinstalação posterior. Ambas são 11.11/A16 e ambas instalam por `adb sideload`.

**Ação do agente:** colar esta tabela, perguntar "Vanilla ou GApps?" e **parar**. Não inferir por
contexto, não escolher pela usuária, não usar "a mais nova".

## 2. P2 — builds pinadas (decidido)

`references/rom-artifacts.json` (`schema evox-rom-artifacts/2`) é a fonte única: device `Pong`,
Android 16, build 2026-09-15, versão 11.11, `status: pinned_by_user`, com `filename`, `url`, `md5`,
`sha256`, `size_label` e `install_path`. **Nunca** trocar por outra build "mais recente".
`architecture_guard.py` AG16 valida URL do CDN oficial (`cdn.evolution-x.org/Pong/…zip`) e sha256
hex-64; o hash pinado é o contrato.

## 3. P3 — autorização (decidido: **Sim**)

P3 foi respondida "Sim": a autorização item a item está registrada em `workspace/decision.json`
(`installs[].authorized`, `modules[].approved`, `canary/usb/cache approved`). O agente **não**
pergunta de novo; ele **verifica** com `session_open.py check` antes de agir.

## 4. Ordem de execução (quando P1 for respondida)

1. `python3 scripts/session_open.py check` → precisa sair **0**.
2. `scripts/audit_loop.sh` → `convergiu=1 limpo=1`.
3. Baixar a build escolhida e **conferir sha256/md5** contra `references/rom-artifacts.json`
   (divergência = parar, exit 5).
4. `extract_evox_base.sh` → manifesto; `forge_patcher.sh`/`patch_boot_offline.sh` (backup
   `boot.img` sempre, um módulo por vez, cache de partes verdes).
5. AVD no GitHub Actions **antes** do físico; nada no USB antes de Release Artifact testado.
6. Encerramento automático por inatividade; snapshots por partes (branch+tag).

## 5. Regras que não podem ser afrouxadas

- **Teste que passa com a lógica removida é falha** (`make -s mutation`: catálogo inteiro, 0 vivo).
- **Timeout não é cobertura**: mutante morto por travar é classificado `timeout` e o harness
  reprova (`--allow-timeout` só com justificativa explícita).
- **Ausência de insumo não é sucesso**: scripts de estágio saem `3` (PENDENTE) ou `4` (ferramenta
  ausente); nenhum "dry-run" se declara concluído.
- **Evidência não se auto-emite**: o auditor de ZIP não gera o próprio sha256.
- HIL A/B nunca é gate final; USB é produção; kernel só com suporte declarado a 11.11 + Pong.

## 6. Onde está a prova

| Comando | O que prova |
|---|---|
| `make -s prove` | estado + wrappers + arquitetura + harness das 8 skills |
| `make -s mutation` | falseabilidade: catálogo inteiro morto **por asserção**, 0 timeout |
| `make -s vacuity` | 22 suítes, 0 erro, 0 aviso (V1–V6) |
| `make -s audit-loop` | AG1–AG21 + contradições + cobertura + mutação, em loop até convergir |
| `docs/skills/FALSIFIABILITY-REPORT.md` | relatório com mascaramentos encontrados e limites |
