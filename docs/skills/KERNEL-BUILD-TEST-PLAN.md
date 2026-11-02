# Kernel do pack — build por GitHub Actions, box de kernel e plano de teste do par

**Pacote alvo:** `custom-build-pong-ksu-susfs-droidspaces` (KernelSU-Next v3.4.2 embutido + SUSFS opcional
+ configs do DroidSpaces), para `pong` / SM8475 / KMI `android13-5.10` / EvolutionX 11.11 (A16).
**Fonte do plano:** `references/kernel-build-plan.json` · **Gate:** `scripts/kernel_build_gate.py`
**Regra de ouro:** o kernel só entra no pack como **candidato com evidência**. Build verde no CI é
**pré-requisito**, não conclusão. `C06` só fecha com as 12 CONFIG_* **provadas** no `.config` do build.

---

## 1. Build e deploy pela GitHub Actions

### 1.1 Ações pinadas (tag → SHA de 40 hex, conferidos na API em 2026-11-01)

| Uso | Tag | SHA | Papel no pipeline |
|---|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | source + patch set |
| `actions/cache` | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | ccache por (pin + defconfig + patches) |
| `actions/upload-artifact` | v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | `Image`, `.config`, `kernel-config.json`, `.rej` |
| `actions/download-artifact` | v8.0.2 | `9000827ccba6bdab643e8b6fd33ac0654aef8333` | job de empacotamento → release |
| `actions/attest-build-provenance` | v4.2.2 | `4d101475d8b20a2381f78447822ac1eab6504dd8` | proveniência (NFR-04) |
| `softprops/action-gh-release` | v3.0.3 | `efb35369e0ad2afab669f228072c1b0d510eae64` | **draft** release (nunca direto público) |
| `sigstore/cosign-installer` | v4.1.2 | `6f9f17788090df1f26f669e9d70d6ae9567deba6` | assinatura do `SHA256SUMS` |

**Recusadas e por quê** (`actions_avoided`): `lemniskett/*` (85★), `feicong/*` (56★), `zclkkk/*` (108★),
`UnicomAndroid/kerneler` (176★) — nenhuma com pin auditável de tag→commit, foco em LKM, ou genérica
demais para GKI com config de vendor. Não se usa wrapper de terceiro para o build: `run:` explícito
sobre a imagem DDK, com os comandos auditáveis no repositório.

### 1.2 Jobs

```
build (ubuntu-latest, timeout 90 min, permissões: contents: read, id-token: write, attestations: write)
  ├─ checkout (source pinado + patch set do repo)
  ├─ cache ccache   (chave: sha256(source pin | defconfig | patch set))
  ├─ docker run ghcr.io/ylarod/ddk-min:android13-5.10-2025-04
  │    make -C $KDIR O=$OUT ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 <defconfig + fragmentos> Image dtbo.img -j$(nproc)
  │    (KernelSU embutido via drivers/kernelsu; SUSFS por patch; rejeição = falha — drop declarado só p/ 004)
  ├─ dump de config:  .config  → kernel-config.json  (CONFIG_*=y/m, formato do gate)
  ├─ upload: Image, dtbo.img, evox_pong_pack.config, kernel-config.json, SHA256SUMS, *.rej
  └─ attest-build-provenance (todos os artefatos)

package (needs: build)
  ├─ baixa artefatos, empacota AnyKernel3 (boot.img dentro)
  ├─ cosign sign SHA256SUMS
  └─ gh-release DRAFT: Image, boot.img, dtbo.img, config, kernel-config.json, zip AK3, SHA256SUMS
```

Regras duras: **sem `fastboot flash` no CI**; **sem secret** (NFR-10, roda em fork público); draft
primeiro, hash conferido, `gh attestation verify`, e só então promoção — e **nunca** USB antes de
`M15` (Release Artifact validado).

### 1.3 Sequência que fecha as pendências do gate

| Passo | Comando | Fecha |
|---|---|---|
| 1. Pinar o source | gravar commit (40 hex) em `source.pin` | **B01** |
| 2. Materializar a árvore | `--kernel-tree <árvore>` com `evox_pong_pack.config` e os `001`/`002` | **B03, B04** |
| 3. Rodar o build (workflow) | dispatch do `pong-build.yml` com o kernel do pack | **B06** (após baixar o draft) |
| 4. Derivar a evidência de config | `.config` → `kernel-config.json` (`{"kmi": "...", "configs": {"CONFIG_X": "y"}}`) | **B05 → C06** |
| 5. Re-rodar solver | `make -s pack` | resolve o empate de 3 pares **por dado** |

Trecho para derivar a evidência (o gate valida o conteúdo, então não há como "provar" com arquivo vazio):

```bash
python3 - .config kernel-config.json <<'PY'
import json, sys
cfgs = {}
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if line.startswith("CONFIG_") and "=" in line:
        k, v = line.strip().split("=", 1)
        cfgs[k] = v
json.dump({"kmi": "android13-5.10", "configs": cfgs}, open(sys.argv[2], "w"), indent=1)
PY
```

> **Nota:** `CONFIG_X=n` no `.config` **não** é ausência — é negação explícita e o gate trata como
> não-provado (`y`/`m` apenas). Isso é intencional: `# CONFIG_USER_NS is not set` reprova `C06`.

---

## 2. O que o pré-build exige antes de qualquer build (checklist item por item)

`python3 skills/evox-rom-ci-optimizer/scripts/kernel_build_gate.py --root . --prebuild`

- **P01–P20 (plano):** 20/20 verde hoje. Alvo/SM8475/build/KMI/partição, fonte com licença, toolchain,
  defconfig + 4 fragmentos (incluindo o do pack), 4 patches com política, 13 configs de contrato,
  19 de módulo, 11 FR + 10 NFR falseáveis, ids únicos, sem placeholder, 7 ações com SHA e versão,
  4 alternativas recusadas, 7 artefatos (3 essenciais), hash+proveniência, deploy em 6 passos, 16
  módulos com critério falseável, 4 riscos com mitigação.
- **B01–B07 (pré-build):** hoje `B02`/`B07` OK e `B01`/`B03`/`B05`/`B06` PEND. **PENDENTE não é falha**
  e não é OK: é `exit 3` com o nome do que falta.

Nada aqui substitui `guard4_verify.sh` (backup + sha256) antes de qualquer flash, e nada aqui autoriza
subir no físico.

---

## 3. Box de kernel recebido via GitHub (`kernel-source/`, `zeroharcoderd/knowledge/`)

O box é **fonte de hipótese**, não autoridade. "O passado era erro" vale para ele como para tudo.
Decisão em três portas, com critério objetivo:

| Opção | Quando | Como fica | Rollback |
|---|---|---|---|
| **(a) Validar como referência** *(padrão)* | claims úteis, mas nenhum build ainda | entra em `source.alternatives` com `status: a_validar`; nada do box é usado no build | remover a entrada do JSON |
| **(b) Fork alterado como candidato do pack** | item por item conferido **e** build verde **e** `C06` provado | vira candidato próprio com `pin`, `configs_proven`, `patches_present`, `supported_rom_builds` | apagar o candidato (o pack volta a `FALTA_PROVA`, sem brick) |
| **(c) Outro módulo / descartar** | contradição insolúvel ou EOL | fica no box como documentação histórica; **não** entra no pack | nenhum (nada foi usado) |

**Conferências que o box de hoje ainda deve** (cada uma é um `PENDENTE`, não um "sim"):

1. `make sm8475_defconfig` — o plano usa `gki_defconfig` + `vendor/waipio_GKI.config` +
   `vendor/nothing/waipio_GKI.config` + `vendor/debugfs.config` + nosso fragmento. **Defconfig do box
   não confere com o source declarado**; `B03` decide quem está certo.
2. `patch -p1 < ../patches/*.diff` sem `--check`/`--dry-run` → **viola NFR-03**. Só entra via
   `git apply --check` e, no build, rejeição = falha.
3. Nomes de patch (`sysvipc_patch.diff`, `posix_mqueue_patch.diff`, `glyph_interface_patch.diff`)
   **não** são os oficiais do DroidSpaces (`001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`,
   `002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch`). Usar os oficiais, com sha256.
4. `5.10.246-gki-g4ec5491f6b5f` e `gki_defconfig` são **claims**: a versão real sai de leitura
   read-only do device (`uname -r`, via L4 quando houver) e o KMI do build assinado.
5. `boot.img (NOT init_boot)` / slot `boot_b`: plausível, **não confirmado**; `R3` do plano cobre o
   caso de `init_boot` separado. `M01` cobre as duas partições se existirem.

Enquanto as 5 não fecharem, o box **não** é kernel do pack — e isso **não** é uma proibição por origem
(a regra é do resultado, não do autor): é ausência de prova.

---

## 4. Como testar o par root × kernel

### 4.1 Estático (sem device) — porta de entrada

```bash
make -s pack          # qual par fecha as 10 condições, por dado
make -s m05           # contrato estático do DroidSpaces (C05/C06/C07)
make -s kernel        # plano + pré-build do kernel (P01–P20, B01–B07)
make -s garantia      # 5 requisitos: prova ou PENDENTE (exit 3)
```

Nenhum desses substitui observação no device; eles **evitam** subir no device o que já reprova aqui.

### 4.2 Staging AVD (antes do físico)

1. `boot.img` do draft → conferir sha256 contra `SHA256SUMS` e `gh attestation verify`.
2. AVD com a build 11.11 (mesma base), flash em AVD/staging, reboot ×3.
3. Coletar `dmesg` (sem `Kernel panic`), `uname -r`, `/proc/config.gz` (se exposto) para segunda
   evidência de `C06`, e `M01` (`su -c 'id -u'`).
4. **Só com PASS de staging** o físico entra.

### 4.3 Físico (autorizado, um módulo por vez)

| Ordem | Ação | PASS quando | Parada (stop condition) |
|---|---|---|---|
| 0 | `guard4_verify.sh` — backup + sha256 do `boot.img` stock | backup confere | sem backup → **não flasha** |
| 1 | flash do `boot.img` do draft | `uname -r` = o buildado, sem panic | panic/bootloop → rollback imediato |
| 2 | **M01** root | `su -c 'id -u'` = 0, SELinux Enforcing | Manager recusa → parar e voltar ao estático |
| 3 | **M05** DroidSpaces | *Check Requirements* 100% + container com 5 namespaces + shm/mq | qualquer requisito faltando → parar (é `C06`/`C07`) |
| 4 | **M07/M08** integridade + ocultação | `MEETS_DEVICE_INTEGRITY`; app alvo não detecta root | detecção → parar |
| 5 | **M02/M03/M04/M06/M09/M11** features | critério da tabela de requisitos | falha → parar no módulo |
| 6 | **M10/M12A/M12B** rede por app, CPU/GPU/thermal, NPU | critério da tabela | regressão → parar |
| 7 | **M13/M14/M15** CI de ambiente, snapshot/rollback, Release Artifact | job verde, restaurar estado, artefato+hash | — |

Regras: `M(n+1)` não começa sem `M(n)` com PASS; HIL A/B **não** é gate final (só diagnóstico depois
de staging); nada no USB antes de `M15`; `P6`/`P7` medem performance (NFR-07, ≤3%) e `P8` é produção.

### 4.4 O que conta como "par validado"

Um par (motor × kernel) está validado quando, **ao mesmo tempo**:

1. as 10 condições `C01`–`C10` estão verdadeiras **por dado** (`make -s pack` sem `FALTA_PROVA`);
2. o kernel tem build verde, artefatos com hash+proveniência (`B06` fechado);
3. as 12 CONFIG_* estão provadas no `.config` do build (`B05` → `C06`);
4. `M01` e `M05` têm PASS no staging **e** no físico com backup verificado;
5. a decisão de seguir (P1, variante) está registrada pela usuária.

Até lá, a resposta honesta do sistema é `FALTA_PROVA` com a lista de pendências — e é isso que se
reporta.

---

## 5. Dependências de decisão (não inferir)

- **P1 (Vanilla × GApps)** aberta: **bloqueia** download e flash de ROM. Perguntar com a tabela pinada e parar.
- **P2** fixa as builds de **2026-09-15** (11.11): build diferente está fora de escopo.
- **P3 = "Sim"**: autorização registrada; não re-perguntar.
- **L4** não é pedida ao agente; leitura read-only apenas. `init_boot` e versão real do kernel são
  confirmados por aí, quando houver.
