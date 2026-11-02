# Onde a prova roda — execução em nuvem com retorno item a item

> Pergunta: dá para tirar `make prove` + `make mutation` da máquina local, disparar de fora
> (Actions, Cloudflare Worker, Colab, iximiuz Labs `labctl`, Linear) e receber **item a item**
> de volta? Qual tem a melhor performance com fluxo impecável?
>
> Resposta curta: **GitHub Actions é o executor; Worker/Colab/labctl/Linear não são.**
> Worker entra como *relay* somente-leitura (latência ms, custo ~0); Colab e labctl servem
> para experimento descartável (kernel, namespaces), nunca para a prova de rotina; Linear é
> **ledger** do veredito, não executor. O retorno item a item é feito pelo contrato
> `proof_items.py` (bundle + digest), que qualquer um dos cinco pode transportar — mas só o
> Actions consegue *produzir* os itens.

---

## 1. O que a prova realmente custa (medido, não estimado)

Ambiente de medição: sandbox Linux **2 vCPU / 3 GB**, workspace de **2,6 MB**, `python3.11`,
nenhum device conectado.

| Medida | Valor medido |
|---|---|
| `make prove` (test-state + wrappers + arch + skills/check-all) | **53 s**, 725 linhas `PASS`, 0 FAIL |
| Casos por suíte, no recorte item a item | 12 suítes, **774 itens**, 0 problema |
| `make mutation` (168 mutantes), `--jobs 1` | **6 min 31 s** (soma dos testes: 390 s) |
| `make mutation`, `--jobs auto` (2 núcleos) | **3 min 23 s**, 168/168 mortos por asserção |
| Matrix simulada (4 shards × `--jobs 2`, 2 núcleos) | **50–52 s por shard**, 168/168 na união |
| Simulação completa do job `aggregate` | 16 bundles · **942 itens** · 0 problema; shard ausente = exit **3** |
| Custo médio por mutante | **2,4 s** (cópia do workspace + 1 suíte) |
| Arquivo mais caro do catálogo | `watchdog_anti_bootloop_service.sh` — 85 s em 2 mutantes |
| Carga de I/O do catálogo inteiro | 168 × 2,6 MB ≈ **437 MB** de cópias |
| Núcleos usados | 2 (o gargalo é o `bash` de teste, não a CPU) |

Conclusão de engenharia: **a prova não é cara, é serial.** 390 s de trabalho real divididos
por 2 núcleos dão 6,5 min de parede (3,4 min com `--jobs auto`, medido); nada ali precisa de GPU, device ou 8 GB de RAM. Isso
muda completamente a escolha de plataforma — o critério deixa de ser "quem tem mais CPU" e
passa a ser **quem paraleliza sem inventar estado, quem devolve artefato íntegro e quem não
morre no meio**.

---

## 2. Os cinco candidatos, com o número que decide

| Critério | **GitHub Actions** | Cloudflare Workers | Google Colab | iximiuz Labs (`labctl`) | Linear |
|---|---|---|---|---|---|
| Executa `make`/`bash`/`pytest` | **sim** (runner completo) | **não** (V8 isolate, sem FS/subprocesso) | sim (VM efêmera) | sim (VM com root/docker) | **não** (API/SaaS) |
| Paralelismo | **matrix grátis** (N jobs simultâneos) | nenhum | 1 sessão | 1 VM por playground | n/a |
| Tempo de parede da prova (estimado do medido) | **~1,5–2 min** (4 shards × `--jobs 2`) | n/a | ~4–6 min + 1–2 min de setup, sem garantia | ~5–8 min (boot da VM + clone) | n/a |
| Artefato íntegro nativo | **sim** (`upload-artifact` + `GITHUB_STEP_SUMMARY`) | sim (R2/KV, ms) | manual (Drive), frágil | manual | anexo/comentário |
| Gatilho automático (push/PR/schedule) | **sim** | webhook (mas não executa) | **não** (sem inbound) | **não** (precisa túnel `cloudflared`) | webhook |
| Sobrevive a run longo | sim (`timeout-minutes`) | n/a | **não** (idle 90 min, teto ~12 h, desconexão mata) | **não** (sessão/créditos expiram) | n/a |
| Risco de ToS / cota | baixo (2000 min/mês privado, ilimitado público) | baixo | **alto** (uso não interativo desencorajado) | baixo (mas finito) | baixo |
| Custo da prova inteira | **~6 job-minutos** por execução | ~0 | 0 (com fila e risco) | ~5–10 min de crédito | 0 |
| Serve para HIL (cabo/USB) | não (e é bom que não) | não | não | não | não |

### Veredito por plataforma

- **GitHub Actions — executor. Nota alta em tudo que importa.** 4 vCPU por runner, matrix
  sem custo, artefato com retenção, `$GITHUB_STEP_SUMMARY` para a tabela item a item e
  anotações `::error::` por item. É o único dos cinco que fecha o ciclo
  **dispara → executa → devolve → reprova sozinho**.
- **Cloudflare Worker — relay, jamais executor.** Limite de CPU por requisição (10 ms free /
  até 30 s pago, sem I/O de disco e sem subprocesso) torna impossível rodar `bash`/`make`.
  Mas é imbatível como **porteiro do retorno**: recebe o bundle, valida o `digest` sha256 e a
  paridade, publica badge/dashboard em <50 ms e repassa um item por vez ao Linear. Custo ~0.
- **Google Colab — não.** Roda a prova (tem CPU e shell), mas não tem gatilho de entrada, a
  sessão cai, o disco é efêmero e a fila não é determinística: um mutante morto no minuto 6
  pode simplesmente não voltar. "Fluxo impecável" e Colab são incompatíveis.
- **iximiuz Labs (`labctl`) — laboratório, não CI.** VM real com root e docker é o lugar
  certo para **compilar o kernel arm64** ou provar namespaces do DroidSpaces (M05), não para
  rodar 168 mutantes todo push: sessão expira, não há webhook nativo (precisa de túnel) e não
  existe retenção de artefato.
- **Linear — ledger.** Não executa nada. É onde o veredito **item a item** vira rastro
  auditável (um comentário por execução, um débito por item vermelho), consumindo o bundle
  que o Actions produziu.

---

## 3. O fluxo escolhido (implementado em `.github/workflows/prove.yml`)

```text
push / PR / dispatch
        │
        ▼
┌──────────────────────────────────────────────────────────────────────┐
│ job static (1 runner, ~1 min)                                        │
│  12 suítes: state · wrappers · arch · validate · core-check ·        │
│             scanner · preflight · rom · gates · ci · guard · eval    │
│  → 774 itens  → workspace/proof/<suíte>.json (bundle + digest)       │
└──────────────────────────────────────────────────────────────────────┘
        │                                    ┌──────────────────────────┐
        │                                    │ job mutation (matrix 4)  │
        │                                    │  --shard K/4 --jobs 2    │
        │                                    │  4 baldes de ~102 s      │
        │                                    │  ~60 s de parede/runner  │
        │                                    └──────────────────────────┘
        ▼                                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ job aggregate (needs: [static, mutation], if: always())              │
│  1) faltou shard/suíte?           → ::error:: + exit 3               │
│  2) união dos shards == catálogo? → faltando/duplicado/sobrando = 3  │
│  3) proof_items.py --validate *.json                                 │
│       paridade TOTAL declarado × observado                           │
│       id contíguo (ninguém apagou item do meio)                      │
│       digest sha256 (transporte não editou o payload)                │
│  → tabela item a item em $GITHUB_STEP_SUMMARY + artefato (7 dias)    │
└──────────────────────────────────────────────────────────────────────┘
        │ (opcional)
        ▼
Cloudflare Worker (verifica digest) ──► badge/dashboard ──► item no Linear
```

### Por que isso é "impecável" e não só "verde"

1. **Verde não é prova; item é.** O Actions de hoje diria "tudo verde" mesmo se uma suíte
   não tivesse rodado. Aqui, suíte ausente = reprovado; item ausente = paridade quebrada;
   item inventado = `id` fora de sequência.
2. **O transporte não é confiável, então não é confiado.** O `digest` cobre suíte + modo +
   itens + paridade; qualquer consumidor (Worker, Colab, Linear) recalcula e recusa payload
   editado.
3. **A partição é verificada, não presumida.** A união dos 4 shards tem de ser exatamente o
   catálogo — o agregador compara com `mutation-catalog.json`, então shard que "passa" sem
   rodar tudo é impossível. E o corte é por **custo medido** (`catalog["costs"]`, segundos por
   mutante), não por contagem: contar mutantes produzia baldes de 53 s e 186 s, porque 2
   mutantes do `watchdog` custam 85 s sozinhos. Com peso, os 4 baldes ficam em **102 s de
   trabalho cada** — medido: 50, 51, 52 e 52 s de parede (39/42/44/43 mutantes), contra 6 min
   31 s de uma execução serial.
4. **O harness é falseável.** `proof_items.py` tem 3 mutantes próprios (M186 paridade,
   M187 digest, M188 contiguidade), todos mortos por asserção em `test_proof_items.sh` (19
   casos). Se alguém desligar a validação, o catálogo denuncia.
5. **Custo travado.** `concurrency.cancel-in-progress`, `timeout-minutes` 20/30/10,
   `permissions: contents: read`, retenção de 7 dias — nenhum run órfão fica queimando cota.

---

## 4. Matriz de decisão em uma linha

| Se você quer… | Use |
|---|---|
| a prova de rotina (774 itens de suíte + 168 mutantes) com veredito por item | **GitHub Actions** (`prove.yml`) |
| receber o resultado fora do GitHub (badge, dashboard, Linear) com 50 ms | **Cloudflare Worker** (relay do bundle) |
| histórico auditável de quem reprovou o quê | **Linear** (item vermelho → débito) |
| compilar kernel arm64 / provar namespaces DroidSpaces | **iximiuz Labs** (`labctl`) |
| experimento descartável e descartável de verdade | **Google Colab** |
| flash e coleta de evidência | **humano, Stage D** (nenhuma nuvem toca o cabo) |

---

## 5. Como rodar (local e nuvem)

```bash
# local: 2 núcleos, tudo em paralelo
make prove                       # 53 s, 774 itens
make mutation JOBS=auto          # 3 min 23 s (era 6 min 31 s serial)
make mutation JOBS=1             # determinístico, ordem do catálogo

# recorte: só os mutantes que você mexeu
python3 skills/evox-rom-ci-optimizer/scripts/mutation_check.py --only M186,M187,M188 --jobs 3

# shard (é o que a matrix do Actions usa; o corte é por custo medido)
python3 skills/evox-rom-ci-optimizer/scripts/mutation_check.py --shard 2/4 --jobs 2

# item a item, de qualquer log
python3 skills/evox-rom-ci-optimizer/scripts/proof_items.py \
  --log workspace/proof/gates.log --suite gates --out workspace/proof/gates.json
python3 skills/evox-rom-ci-optimizer/scripts/proof_items.py --validate workspace/proof/*.json \
  --summary-md resumo.md
```

## 6. O que continua fora da nuvem (e por quê)

`fastboot flash`, coleta pós-flash (`collect_evidence.sh`) e a decisão de promover slot
continuam humanos. Nenhum dos cinco candidatos tem `/dev/bus/usb` do `pong`; prometer HIL em
nuvem seria o mesmo erro que prometer boot da ROM arm64 em runner x86_64 (ver
`emulation-sandbox.md`). A nuvem prova o que é **engenharia**; o cabo prova o que é
**hardware**.
