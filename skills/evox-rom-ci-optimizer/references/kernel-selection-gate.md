# Gate de seleção de kernel e versão (requisitos 1 e 6)

> Vale **antes** de qualquer patch de boot. Kernel errado é a causa nº 1 de bootloop em `pong`.
> Nada aqui é escolha do agente: ele **verifica**, reporta e pede decisão.

## 0. Antes do kernel: qual motor de root (e a que custo)

O motor de root não é detalhe de instalação — ele decide **se o kernel oficial continua no lugar**:

| Motor | Kernel próprio? | SUSFS | Efeito no escopo |
|---|---|---|---|
| APatch | não | não | kernel da ROM permanece; rollback pela imagem stock |
| Magisk | não | não | idem (root em userspace) |
| KernelSU / SukiSU | **sim** | **sim** | kernel de terceiro entra no caminho crítico; OTA deixa de valer |

Quem cruza motor × kernel × requisitos dos 15 módulos é `root_engine_gate.py`
(`references/root-engines.json`, `references/kernel-candidates.json`,
`references/module-requirements.json`). Ele devolve `COMPATÍVEL` (0), `PENDENTE` (3) — falta dado,
por exemplo L4 da build — ou `INCOMPATÍVEL` (1). Auditoria completa: `docs/skills/ROOT-ENGINE-AUDIT.md`.

## 1. Tríade obrigatória: kernel × ROM × device

Um kernel só é candidato se as três igualdades valerem:

| Eixo | O que comparar | Como provar |
|---|---|---|
| **Device** | modelo `pong` / SoC `SM8475` | manifesto do kernel declara `model: pong`; `ro.product.device=pong` no device |
| **ROM** | build exata `EvolutionX-16.0-20260915-Pong-11.11` | `rom_assets.json` (`source.zip_sha256`) tem que ser o mesmo pacote que será gravado |
| **Android** | API 36 / Android 16 (Baklava) | `ro.build.version.sdk=36`; kernel declara suporte a API 36 |
| **KMI** | `android14-11`, `android15-6.19`, … | string igual à do `boot.img` do `payload.bin` (extraída na L4) |
| **Base do kernel** | `major.minor` idêntico ao da ROM | `6.1.x` da ROM não aceita módulo compilado para `6.6.x` |

`kernel_compat_check.sh` faz exatamente essas cinco comparações e devolve
`COMPATIBLE` ou `INCOMPATIBLE` com a lista de motivos — nunca "acho que serve".

```bash
./scripts/kernel_compat_check.sh \
  --rom-assets  ./workspace/rom_assets/rom_assets.json \
  --candidate   ./workspace/kernels/candidato.json \
  --json
# exit 0 = COMPATIBLE · 3 = INCOMPATIBLE · 2 = uso · 4 = entrada inválida
```

### Manifesto do candidato (contrato mínimo)

```json
{
  "name": "APatch-patched pong 6.1.75",
  "model": "pong",
  "soc": "SM8475",
  "android_api": 36,
  "android_release": "16",
  "kmi": "android14-11",
  "kernel_base": "6.1",
  "supported_rom_builds": ["EvolutionX-16.0-20260915-Pong-11.11"],
  "developer_support": { "declared": true, "source": "https://…", "notes": "suporte explícito ao build" },
  "source_url": "https://…",
  "sha256": "<hash do artefato do kernel>"
}
```

Regra: `developer_support.declared` tem que ser `true` **e** `supported_rom_builds` conter a build
exata. "Funciona em A16" não é suporte à *sua* build. Sem isso → `INCOMPATIBLE`.

## 2. Escolha da versão: a mais estável *atualizada*, não a mais nova

Ordem de decisão (a primeira que falhar decide):

1. **A build é oficial e o pacote tem hash publicado?** Não → descartar.
2. **É a mesma base que você já usa ou uma atualização da mesma linha 11.x?** Salto de linha
   (11.x → 12.x) é migração, não atualização: exige plano separado.
3. **Os módulos do escopo declaram suporte a API 36 + KMI da build?** Não → travar na versão anterior.
4. **O kernel candidato suporta a build exata?** Não → kernel stock + APatch (patch no `boot.img`
   oficial) é a opção estável; kernel de terceiro entra só depois.
5. **Empate técnico** → escolher a de maior tempo de vida em campo (mais tempo desde o release,
   mais relatos de boot estável) e menor superfície de mudança.

> Pinned por padrão: `EvolutionX-16.0-20260915-Pong-11.11` (Vanilla ou GAPPS, decisão da usuária).
> "Última versão" só entra por decisão explícita, com novo ciclo de gates.

## 3. Compatibilidade de módulo (o que o scanner não vê)

`static_conflict_scanner.py` pega colisão de arquivo/serviço. Não pega **ABI/versão**. Antes de cada
módulo entrar no ledger de rollout, declarar:

| Campo | Exemplo | Trava |
|---|---|---|
| `android_api` | `36` | ≠ 36 → rejeitar |
| `kmi` | `android14-11` | ≠ KMI da ROM → rejeitar |
| `architecture` | `arm64-v8a` | ≠ → rejeitar |
| `requires_root_engine` | `apatch` | ≠ motor escolhido → rejeitar |
| `requires_susfs` / `requires_zygisk` | `false` | verdadeiro sem base → rejeitar |
| `source_url` + `sha256` | release oficial | ausente → rejeitar |

## 4. Estratégia de decisão para o `pong` (estabilidade × eficiência)

| Cenário | Escolha | Por quê |
|---|---|---|
| Primeira instalação | ROM stock + APatch no `boot.img` oficial | menor variável; reversível por `boot_stock_rollback.img` |
| Kernel de terceiro | só com suporte declarado à build exata e KMI igual | KMI divergente = módulo vendor quebrado |
| Performance | MaxManager antes de kernel custom | resolve escrita concorrente sem trocar kernel |
| IA local | GenieX dentro de DroidSpaces | isola dependências do NPU do sistema |
| Banking/Play Integrity | Duck-ToolBox consolidado | evita pilha de spoofers concorrentes |
| Dúvida entre duas versões | a mais antiga e mais testada | estabilidade > novidade em device de uso diário |

## 5. Evidência que fecha o gate

```text
rom_assets.json  (L4)            -> build, kernel, KMI, hashes
candidato.json                   -> declaração do kernel + suporte
kernel_compat_check.sh --json    -> COMPATIBLE (exit 0) ou INCOMPATIBLE + motivos
cache/<phase>/manifest.json      -> comprova que o artefato testado é o artefato usado
```
