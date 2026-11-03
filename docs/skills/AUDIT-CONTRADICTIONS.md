# Auditoria de contradições — 2026-11-01

<!-- contagens: histórico · congelado em: 78fb0a5 (2026-11-02) — números deste documento valem para aquele commit --> números deste relatório são o retrato de 2026-10-28; o valor vivo sai de `make -s contagens`.

**Pergunta:** alguma instrução ativa ainda pertence à arquitetura antiga, a outro workspace, ou usa
vocabulário que duas partes do repositório leem de formas diferentes?

**Método:** `scripts/contradiction_scan.py` (regras **C1–C13**) sobre 70 arquivos ativos +
leitura manual dos 79 trechos que citam "gate/guard 4". Resultado inicial: **57 erros e 19 avisos**.
Resultado final: **0 erros, 0 avisos** · `audit_loop.sh` converge limpo em 2 iterações.

## 1. Vocabulário: o problema maior não era técnico

| Achado | Onde | Gravidade | Resolução |
|---|---|---|---|
| `Gate 4` / `G4` com **5 significados** diferentes: `G4` = "Guardião respeitado" (`AGENTS.md` §9), `G4` = injeção sem hardcode (`act-github-pat`), `G4` = confirmação humana (`github`), `G4` = densidade (`cogni-synapse`), `G4` = contrafactual (`sci-…`) | 31 ocorrências em 6 arquivos | alto (erro de leitura garantido) | §0 do `ARCHITECTURE-DECISION.md` fixa vocabulário; `Guard-4` fica só com o sentido de ROM; C8/C9 reprovam `Gate 4`/`G4` soltos |
| `gate 10` (checklist pré-USB) colidia com o objetivo `G10` ("HIL A/B isolado") | 16 ocorrências em 11 arquivos | alto | renomeado para **GO-USB 10/10**; C10 reprova o termo antigo |
| `Guard-4` usado como sinônimo de "backup do boot" em uns lugares e de "portão de autorização" em outros | `AGENTS.md` §1 e §invariantes, `SKILLS-INVENTORY.md`, `NEXT-SESSION-REPORT.md` | médio | definição canônica no `guard4_verify.sh` (cabeçalho) e no ADR: 4 condições, sendo 1–2 mecânicas e 3–4 humanas |

## 2. `init_boot`: a contradição factual que mais podia causar bootloop

| Lado A | Lado B |
|---|---|
| `AGENTS.md` invariante 20: "flash de `boot_<slot>` **+ `init_boot_<slot>`**" | `ak3/anykernel.sh`: "Pong uses boot.img (**NOT** init_boot.img!)"; `package-anykernel3.sh`: "Pong should NOT use this"; `.github/workflows`: "Pong is **pre-init_boot era**" |

**Não é decidível offline** (sem `payload.bin`). O que foi feito:

1. As assertivas "não tem init_boot" foram **marcadas como não verificadas** (`boot-test.yml`,
   `pong-build.yml`, `ak3/anykernel.sh`, `package-anykernel3.sh`), com instrução de confirmar no `payload.bin`.
2. Invariante 20 virou **condicional**: flasha `init_boot` *somente se o pacote trouxer* `init_boot.img`.
3. `guard4_verify.sh` passou a exigir **par de rollback byte-idêntico da `init_boot` quando o
   `rom_assets.json` listar `init_boot.img`** (`--init-boot` / `--init-boot-backup`), e a declarar
   `init_boot_layout = nao_informado` quando o layout não é passado. Coberto por 5 casos novos
   em `test_cache_and_guard4.sh` (20 PASS no total).
4. Regra **C11** reprova afirmação sobre `init_boot` sem marcação de "não verificado".

## 3. Instruções da arquitetura antiga que ainda estavam ativas

| Onde | O que dizia | Correção |
|---|---|---|
| `references/act-ab-hil-review.md:95` | "O HIL A/B **é o gate final** antes do USB" | virou **pré-gate**; gate final = GO-USB 10/10 + autorização (C12) |
| `SKILL.md` (4 trechos), `NEXT-SESSION-REPORT.md`, `SKILLS-INVENTORY.md`, `pong-hardware-matrix.md` | "QEMU/KVM" como se a ROM arm64 bootasse | "AVD (API 36)"; declara que valida a camada de módulos (C7) |
| `references/evox-ci-validator.yml` | `echo "gate10=pendente" > dist/GATE10.txt` | `GO-USB.txt` (C10) |

## 4. Risco operacional encontrado **durante** a auditoria (o mais grave)

Rodar `snapshot_branch_manager.sh` **sem argumentos** executava `git checkout -B snapshot/<layer>`,
`git add` e `git commit` — engoliu o worktree inteiro num branch novo, sem confirmação.

| Antes | Depois |
|---|---|
| qualquer invocação (inclusive `--help`) mexia no git | `--help` só imprime uso; **dry-run é o padrão**; só age com `--apply` |
| commitava tudo que estava sujo | commita **apenas** `$SOURCE_DIR/snapshot_manifest.json` (`git add --`) |
| rodava em branch de sessão | recusa `arena/*` e detached HEAD; recusa worktree sujo sem `--allow-dirty` |

Prova: `tests/test_script_contracts.sh` (55 asserções) roda `--help` em 18 scripts e verifica que
**branch, HEAD e `git status` não mudam** e que nenhuma branch `snapshot/*` é criada.

## 5. Scripts que executavam efeito colateral ao serem inspecionados

9 scripts rodavam o trabalho real quando chamados com `--help`/sem argumento
(`audit_rom_conflicts`, `build_safe_module_bundle`, `extract_evox_base`, `forge_patcher`,
`patch_boot_offline`, `runtime_module_tester`, `watchdog_anti_bootloop_service`,
`snapshot_branch_manager`, e os 7 de `scripts/` na raiz). Todos ganharam guarda de ajuda sem efeito.

## 6. Cobertura de teste (antes → depois)

| Antes | Depois |
|---|---|
| 12 scripts sem teste nem justificativa | **0** — 32 testados + 4 isentos declarados em `references/audit-exemptions.json` com motivo (3 do skill `github`, que exigem token; 1 instalador interativo) |
| 18 suítes / 175 casos | **18 suítes / 250 casos** (237 na skill + 13 de estado) |

## 7. O que **não** foi contradição (verificado e mantido)

- `G1–G10` no `AGENTS.md` §9 (objetivos globais) — legítimos, agora com legenda anti-colisão.
- `G4` dentro de `skills/github`, `cogni-synapse`, `sci-…`, `act-github-pat` — são de outros domínios;
  o scan só olha o domínio ROM.
- `references/archive/evox-ci-pipeline.yml` — histórico com aviso SUPERSEDIDO (AG15).
- `docs/skills/VALIDATION-REPORT.md` e este arquivo — citam os padrões proibidos de propósito
  (lista de exceções explícita no scanner, com motivo por arquivo).

## 8. Reprodução

```bash
python3 skills/evox-rom-ci-optimizer/scripts/contradiction_scan.py        # 0 erros
python3 skills/evox-rom-ci-optimizer/scripts/coverage_matrix.py --list     # 100% (testado+isento)
skills/evox-rom-ci-optimizer/scripts/audit_loop.sh                         # converge limpo
```
