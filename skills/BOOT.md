# BOOT — contrato de inicialização do agente neste repositório

> Ler **antes** de qualquer comando. O repositório é evidência histórica; a instrução é o contrato.
> Stack atual: **8 skills** (`registry.json` é a fonte de verdade da lista).

## 1. Ordem de carregamento (nunca pular)

1. `skills/BOOT.md` (este arquivo) — regras de operação.
2. `skills/registry.json` — quais skills existem, tier, classe, gatilhos.
3. `skills/<skill>/SKILL.md` — só as que casarem com a tarefa.
4. Tarefa de ROM/kernel/módulos → **obrigatório**, nesta ordem:
   `evox-rom-ci-optimizer/references/module-matrix-5w1h.md` (a instrução) →
   `external-engines-arbitration.md` (R01–R09) → `pong-hardware-matrix.md` (hardware).
5. Tarefa de criar/atualizar skill → `fabrica-de-agentes/SKILL.md` (+
   `references/geracao-em-9-fases.md` e `references/validacao-12-testes-e-erros-fatais.md`).

## 2. Camadas da stack (quem manda em quê)

| Camada | Skill | Decide |
|---|---|---|
| Epistêmica | `sci-scientific-mindset` | o que conta como evidência; hipótese falseável; contra-argumento obrigatório |
| Governança | `agent-governance-orchestrator` | DAG, ownership ledger, Guard-4, gates binários |
| Criação | `fabrica-de-agentes` | como uma skill nova nasce e é validada (9 fases, 12 testes) |
| Domínio | `evox-rom-ci-optimizer` (pré-flash) · `android16-root-guardian` (pós-flash) | o que fazer no Android 16 |
| Apoio | `github` · `act-github-pat` | operações `gh` e execução local de workflow |
| Saída | `cogni-synapse` | como o resultado é entregue (BLUF, matriz, vetor semiótico) |

Fluxo: **sci** dá o crivo → **governance** monta o DAG → **domínio** executa → **fabrica** versiona
o que virou skill → **cogni-synapse** empacota a entrega.

## 3. Invariantes (violação = parar e pedir decisão)

- **Nada físico sem estágio.** Sem 10 gates + `boot_stock_rollback.img` com SHA-256, não existe
  `fastboot flash`.
- **`persist` é intocável** (calibração Goodix) — escrita = `CONFLICT` (R06).
- **SELinux `Enforcing`** é requisito de produto (R08).
- **MaxManager tem exclusividade de escrita** em CPU/GPU/Thermal/ZRAM/TCP (R01/R02).
- **Duck-ToolBox consolida M07/M08** — não empilhar spoofers avulsos (R04).
- **DroidSpaces × SuSFS**: mount-hide global desabilitado (R03).
- **Uma fonte de verdade.** Código divergiu da instrução → corrige o código.
- **Sem GitHub** enquanto a usuária não liberar (hoje: Drive + local).
- **Sem segredos no repo** — o harness falha em `ghp_*`, `github_pat_*`, chaves privadas.
- **Skill nova sem `validate` + `eval` verde não entra no `registry.json`.**

## 4. Como provar que está tudo de pé (≈40 s)

```bash
make -C skills check-all
```

Esperado: `[harness] OK (0 falhas)` · `[core] make check OK` · `13 PASS` (regras) ·
`8 PASS` (preflight) · `8 PASS` (evidência) · `[eval] APROVADO`.

## 4-A. Abertura de sessão (obrigatória antes de qualquer download)

1. Explicar o plano em 1 tela: o que será feito, em que ordem, com quais gates.
2. **Perguntar qual build**: Vanilla ou GAPPS — com prós/contras (tabela em
   `evox-rom-ci-optimizer/SKILL.md` §VI-A). Não escolher pela usuária.
3. Registrar `workspace/decision.json` (versão, URL, sha256 esperado). Sem isso, parar (exit 2).
4. Fechar **L4** com `scripts/extract_rom_assets.sh --zip <zip> --expect-sha256 <hash>`:
   kernel/KMI e hashes vêm do **pacote**, não do aparelho. O device só confirma slot/fingerprint.

## 5. Fluxo canônico de uma tarefa de ROM

```text
0. abertura     briefing + pergunta Vanilla × GAPPS + decision.json
1. epistemica   sci-scientific-mindset      → hipótese + como seria refutada
2. governanca   agent-governance-orchestrator → DAG, ownership ledger, 5W1H
3. instrucao    module-matrix-5w1h           → módulo, onda, gate
4. preflight    scripts/preflight_deps.sh    → binários externos antes de começar
4b. lacuna L4   scripts/extract_rom_assets.sh→ hashes+kernel do .zip oficial (não do device)
4c. gate kernel kernel_compat_check.sh       → COMPATIBLE? senão não patcheia boot
5. estatico     make scan / make audit       → CLEAN? senão VETO
6. estagio A    make extract → make forge    → Guard-4 + KMI + guard4_verify.sh VERIFIED
7. estagio B    AVD API 36 x86_64 (KVM)      → boot_completed, logcat, RescueParty
                 (a ROM arm64 do pong NÃO boota em runner; valida a camada de módulos)
7b. rollout     rollout_gate start/record     → 1 módulo por vez, PASS antes do próximo
7c. cache       cache_manager put/verify     → fase verde endereçável por SHA-256
8. estado       make snapshot                → snapshot/<camada>/<tag> + manifesto
9. release      gate 10 (pre-USB)            → só com 10/10 PASS
10. pos-flash   collect_evidence.sh          → evidence.json + MANIFEST.sha256
11. entrega     cogni-synapse                → 1 tela: decisão, evidência, o que falta
```

## 6. O que ainda não existe (não fingir que existe)

- `skill-updater` (citada pela governança; `fabrica-de-agentes` cobre a criação, não o update
  incremental automático).
- Dados do device da usuária (kernel exato, hashes `boot_b`/`vendor_boot_b`/`vbmeta_b`) — **L4**.
- Binários externos (`payload-dumper-go`, `kptools`, `magiskboot`, `adb`, `act`): o preflight
  detecta e explica; não instala.
