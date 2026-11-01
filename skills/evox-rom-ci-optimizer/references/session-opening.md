# Protocolo de abertura de sessão (P1–P8 ratificados em 2026-11-01)

> **Nenhum download, nenhuma instalação e nenhum patch acontece antes disto.**
> O agente executa `session_open.py`; sem `workspace/decision.json` completo, a execução para (exit 3).

```bash
python3 scripts/session_open.py questions            # imprime a ordem
python3 scripts/session_open.py template --out workspace/decision.json
python3 scripts/session_open.py check --file workspace/decision.json --json
```

## Ordem e conteúdo de cada pergunta

### P1 · Vanilla ou GAPPS — explicar e recomendar

O agente **não pergunta seco**: apresenta a comparação e recomenda com base nos módulos aprovados.

| Critério | Vanilla | GAPPS |
|---|---|---|
| Google/banking | só após GApps manual | pronto |
| M03 (Google core) | vira tarefa manual | satisfeita |
| Superfície de conflito | menor | maior |
| Play Integrity | caminho longo | caminho curto |

Com o escopo do projeto (banking, IA local, câmera, uso diário), a recomendação padrão é **GAPPS**,
explicitando o custo: bloat, mais serviços em background, mais superfície para o scanner na F1.

### P2 · Caminho completo do `.zip`

Só **depois** da decisão de build. O agente pede o caminho absoluto e confere `sha256` contra o valor
publicado antes de extrair (`--expect-sha256`). Sem caminho válido → nada roda.

### P3 · Autorização de binário, item a item

| Binário | Necessidade | Sem ele |
|---|---|---|
| `payload-dumper-go` | abrir `payload.bin` → `boot/vendor_boot/vbmeta` (L4 + F0) | L4 não fecha; nenhum patch |
| `kptools` | aplicar APatch/KPM no kernel | M01 não existe |
| `magiskboot` | unpack/repack do `boot.img` | patch e rollback sem base |
| `adb` | Stage B (AVD) e coleta pós-flash | sandbox e evidência pós-flash não rodam |

O agente pergunta **um por um**, com essa justificativa; "sim" parcial é aceito (o pipeline adapta e
declara o que fica bloqueado).

### P4 · Kernel — propor o mais estável/compatível

Padrão recomendado: **stock + APatch no `boot.img` oficial**. Motivos: (a) é o único kernel com
suporte garantido à build exata; (b) rollback é byte-idêntico ao pacote; (c) não cria dependência de
KMI de terceiro. Kernel externo só entra se o candidato declarar `model=pong`, API 36, KMI igual e
`supported_rom_builds` com a build exata — e ainda assim depois de F0 estável.

### P5 · Lista final de módulos — pedir aprovação com descrição

O agente apresenta a tabela F0–F5 (16 itens, incluindo os 15 do escopo), com uma linha de descrição e
o que cada um toca. Aprovação é por módulo; módulo não aprovado não entra no ledger.

### P6 · Canário e AVC — otimizado para performance

| Ambiente | Janela | Justificativa |
|---|---|---|
| AVD (Stage B) | **60 s** de observação por módulo | rápido sem perder crash de boot; soft-reboot já exercita Zygote |
| Aparelho (Stage D) | **10 min** por módulo | captura falha tardia (watchdog, thermal, GMS) |
| AVC | **0 denial novo** vs. baseline | denial novo = política errada, não ruído |

### P7 · Cache — otimizado para performance

| Item | Política | Efeito |
|---|---|---|
| manifesto + hashes | versionados para sempre | cache sempre verificável |
| artefato ≤ 25 MB | inline no repo | restaura sem rede |
| artefato > 25 MB | referência externa + sha256 | repo não incha |
| `actions/cache` | chave por `sha256` da ROM | não rebaixa 6 GB |
| artefatos de CI | `retention-days: 5` | storage não acumula |
| poda local | `prune --days 90` | cache quente sem lixo |

### P8 · USB = produção

O agente **informa** que o cabo é Stage D (produção) e que só entra após **10/10 gates verdes no
emulador + Stage C empacotado + `guard4_verify` VERIFIED**. Não existe "flash rápido para testar".

## Regra de bloqueio

```text
decision.json incompleto  → session_open.py check = exit 3 → nada executa
decisão completa          → execução liberada (Stage A → B → C)
```
