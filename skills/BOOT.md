# BOOT — contrato de inicialização do agente neste repositório

> Ler **antes** de qualquer comando. Este arquivo manda mais que o repositório: o repo é
> evidência histórica; a instrução é o contrato.

## 1. Ordem de carregamento (nunca pular)

1. `skills/BOOT.md` (este arquivo) — regras de operação.
2. `skills/registry.json` — quais skills existem, tier, gatilhos.
3. `skills/<skill>/SKILL.md` — apenas as skills cujo gatilho casar com a tarefa.
4. Se a tarefa for ROM/kernel/módulos: **obrigatório** abrir, nesta ordem,
   `skills/evox-rom-ci-optimizer/references/module-matrix-5w1h.md` (a instrução),
   `.../external-engines-arbitration.md` (regras R01–R09),
   `.../pong-hardware-matrix.md` (matriz do hardware).

## 2. Invariantes (violação = parar e pedir decisão)

- **Nada físico sem estágio.** Sem aprovação nos 10 gates + `boot_stock_rollback.img` com
  SHA-256, não existe `fastboot flash`. O Nothing Phone 2 é santuário, o runner é descartável.
- **`persist` é intocável** (calibração Goodix). O scanner trata escrita como `CONFLICT` (R06).
- **SELinux `Enforcing`** é requisito de produto (R08).
- **MaxManager tem exclusividade de escrita** em CPU/GPU/Thermal/ZRAM/TCP (R01/R02).
- **Duck-ToolBox consolida M07/M08**: não empilhar spoofers avulsos (R04).
- **DroidSpaces × SuSFS**: mount-hide global desabilitado para `droidspaces` (R03).
- **Uma fonte de verdade.** Se código e instrução divergirem, corrige-se o código.
- **Sem GitHub** enquanto a usuária não liberar explicitamente (hoje: apenas Drive + local).
- **Sem segredos no repo.** O harness falha em `ghp_*`, `github_pat_*`, chaves privadas.

## 3. Como provar que está tudo de pé (30 s)

```bash
make -C skills check-all     # validate + make check + 13 testes de regra
```

Saída esperada: `[harness] OK (0 falhas)` · `[core] make check OK` · `13 PASS / 0 FAIL`.

## 4. Fluxo canônico de uma tarefa de ROM

```text
1. governança   agent-governance-orchestrator  → DAG, ownership ledger, 5W1H
2. instrução    module-matrix-5w1h             → qual módulo, qual onda, qual gate
3. estático     make scan / make audit          → CLEAN? senão VETO
4. estágio A    make extract → make forge       → Guard-4 + KMI
5. estágio B    make runtime-test               → boot_completed, logcat, RescueParty
6. estado       make snapshot                   → snapshot/<camada>/<tag> + manifesto
7. release      gate 10 (pre-USB)               → só com 10/10 PASS
8. pós-flash    android16-root-guardian         → OTA A/B, bootloop, telemetria real
```

## 5. O que ainda não existe (não fingir que existe)

- `fabrica-de-agentes` / `skill-updater` (citadas pela governança, **não instaladas**).
- Coletor de telemetria no device (`android16-root-guardian` é doutrina pura).
- Binários externos: `payload-dumper-go`, `kptools`, `magiskboot`, `adb`, `act`, `gh`.
- Kernel exato e hashes da build da usuária (só existem parcialmente no Drive).
