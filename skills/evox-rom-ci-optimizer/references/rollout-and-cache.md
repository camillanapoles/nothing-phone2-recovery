# Rollout canário + cache de pipeline (requisitos 3 e 4)

## 1. Um módulo por vez, com prova antes do próximo

Instalar cinco módulos e reiniciar uma vez não é teste — é aposta. O contrato é **canário**:

```text
para cada módulo, na ordem da onda:
  1. preflight do módulo (API, KMI, arquitetura, motor de root, URL+sha256)
  2. instalar SOMENTE esse módulo
  3. reiniciar e coletar evidência (collect_evidence.sh)
  4. exigir: boot_completed=1 · 0 crash de sistema · 0 AVC denial novo · uptime ≥ 10 min
  5. registrar PASS no ledger  →  só então o próximo módulo é liberado
```

`rollout_gate.sh` é o carcereiro: recusa abrir o módulo N+1 enquanto o N não tiver evidência
aprovada, e recusa dois módulos abertos ao mesmo tempo.

```bash
./scripts/rollout_gate.sh start  --state ./skills/evox-rom-ci-optimizer/references/rollout-ledger.json --wave W1 --module M01 --artifact ./out/boot_patched.img
./scripts/rollout_gate.sh record --state ./skills/evox-rom-ci-optimizer/references/rollout-ledger.json --module M01 --evidence ./evidence/evidence.json
./scripts/rollout_gate.sh status --state ./skills/evox-rom-ci-optimizer/references/rollout-ledger.json --json
# exit 0 = liberado · 3 = bloqueado (pendência/anterior sem PASS) · 2 = uso · 4 = evidência inválida
```

### Critério de PASS (binário, sem opinião)

| Condição | Fonte |
|---|---|
| `boot.ok == true` (`sys.boot_completed=1`) | `evidence.json` |
| `crashes == 0` (sem `FATAL EXCEPTION` de sistema) | `evidence.json` |
| `avc_denials` não aumentou vs. baseline | `evidence.json` + último PASS |
| estabilidade observada ≥ 10 min | campo `stability.uptime_min` |
| artefato instalado tem o sha256 registrado no `start` | ledger |

Falhou um critério → o módulo fica `FAILED`, o próximo **não abre** e o rollback do módulo
(ou do `boot.img`) é obrigatório antes de qualquer nova tentativa.

## 2. Ondas: a ordem não é decorativa

| Onda | Regra | Por que |
|---|---|---|
| W1 | kernel/root **antes** de qualquer módulo | módulo que depende de root falha silenciosamente sem ele |
| W2 | identidade **antes** de performance | GMS/fingerprint quebrados mascaram crash de desempenho |
| W3 | performance/NPU/câmera juntos | disputam `sysfs`, `.so` e `adsprpc` |
| W4 | janelas/SAF/rede por último | reinício de Zygote e netfilter quebram boot se vierem antes |
| W5 | CI/snapshot/release | só depois de W1–W4 verdes |

Violação de ordem é detectada por R09 no scanner — e agora também pelo ledger (`wave` decrescente
é recusada).

## 3. Cache de pipeline: o que já funcionou não se refaz

Regra: **toda fase verde deixa um artefato endereçável por hash**. Se o passo 5 falhar, o passo 1–4
não é reexecutado do zero.

```bash
./scripts/cache_manager.sh put    --phase extract --file ./workspace/rom_assets/boot.img --state ./cache
./scripts/cache_manager.sh get    --phase extract --name boot.img --state ./cache --to ./workspace/rom_assets/boot.img
./scripts/cache_manager.sh list   --state ./cache --json
./scripts/cache_manager.sh verify --state ./cache
# exit 0 = ok · 3 = cache miss / hash divergente · 2 = uso
```

### Política de tamanho (por que não vai tudo para o Git)

| Artefato | Tamanho típico | Política |
|---|---|---|
| `rom_assets.json`, manifestos, `.sha256`, relatórios | KB | **versionado** em `cache/<phase>/` |
| `boot_patched.img`, `boot_stock_rollback.img` | ~96 MB | **referência + hash** no manifesto; arquivo fica em `workspace/` (fora do Git) |
| bundles de módulos | 1–50 MB | versionar só o `manifest.json` e o `sha256`; binário em storage externo |

`cache_manager.sh` decide sozinho: arquivo ≤ 25 MB é copiado; acima disso entra como
`"external": true` com caminho e hash. Assim o repositório guarda **o que foi testado**, sem inchar.

### Manifesto (`cache/manifest.json`)

```json
{
  "schema": "evox-cache/1",
  "entries": [{
    "phase": "extract", "name": "boot.img",
    "sha256": "…", "size_bytes": 100663296,
    "source_rom_sha256": "…",
    "created_at": "2026-11-01T18:00:00Z",
    "external": true, "path": "workspace/rom_assets/boot.img",
    "proven_by": "test_extract_rom_assets.sh"
  }]
}
```

`verify` recomputa o hash de toda entrada não-externa e falha se algo divergir — cache corrompido
não pode virar "verde" por decurso de prazo.

## 3-bis. Onde cada arquivo vive (e o que o `workspace/` NÃO pode guardar)

`workspace/` é ignorado pelo Git **e limpo a cada sessão**. Tudo o que precisa sobreviver tem
endereço próprio, declarado em `references/artifact-paths.json` (fonte única, cobrada pelo gate
`RC11` do `refactor_gate.py`):

| classe | onde | exemplos | se sumir |
|---|---|---|---|
| **durável versionado** | `references/` (Git) | `decisions.json`, `rollout-ledger.json`, `install-stack.json` | não some: está no commit |
| **cache persistente** | `${EVOX_CACHE:-$HOME/.cache/evox}/` | zips (2,4 GB), `rom-artifacts.lock.json`, `evox.env` (pins sha256) | só em reset da máquina; o fetch refaz o pin |
| **derivado** | `workspace/` | `out/`, `extracted/`, `rom_assets/`, `l4/`, `backup/`, `staging/`, `kernels/` | recalculado do cache |
| **efêmero** | `workspace/` | `audit/*.json`, `evidence/`, `conflict_report.json` | por definição; o veredito vai para o ledger |

Regra: **nome durável dentro do `workspace/` é falha de gate** — inclusive em subpasta liberada
(um ledger gravado dentro de `workspace/audit/` reprova, apesar de `audit/` ser liberado). Cada caminho novo sob `workspace/` precisa ser
classificado no manifesto, senão `RC11` reprova.

## 4. Ligação com as outras travas

- Cache **não** substitui gate: artefato em cache ainda passa por `scan`/`audit` antes de entrar.
- `snapshot_branch_manager.sh` versiona estado por camada; `cache_manager.sh` versiona **insumo de
  build**. Um não apaga o outro.
- Rollback (`boot_stock_rollback.img` + `.sha256`) é verificado por `guard4_verify.sh` antes de
  qualquer flash — ver `kernel-selection-gate.md` §1 e `SKILL.md` §VI-D.
