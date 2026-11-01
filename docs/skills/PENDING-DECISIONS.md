# Pendências — o que já está decidido e o que ainda depende da usuária

**Data:** 2026-11-01 · **Máquina:** `skills/evox-rom-ci-optimizer/scripts/session_open.py`
**Regra:** P1–P3 e P9 são **humanas** (mudam conteúdo/instalação/remote). P10–P14 foram
**delegadas** (“decida por contexto”) e estão gravadas em `decision.json` com
`decided_by: "agent-context"`.

## 1. Bloqueantes (sem isto a execução não começa)

| ID | Pergunta | Por que trava | O que o agente já preparou |
|---|---|---|---|
| **P1** | Vanilla × GApps | muda o `/system` de origem e o conjunto de módulos (GApps A16 + Google Unlocked) | [`VANILLA-VS-GAPPS.md`](VANILLA-VS-GAPPS.md) (diferenças, impacto módulo a módulo, continuidade e recomendação) + coleta determinística das **duas** variantes via `rom_artifact_fetch.sh --variant both` |
| **P2** | Caminho do `.zip` + sha256 | sandbox sem egress ao CDN; sem zip não há L4 real | `extract_rom_assets.sh --zip … --expect-sha256 …` pronto, sai 3 sem binário |
| **P3** | Autorização de binários (item a item) | instalação no *seu* host | `preflight_deps.sh --hints` com a receita de cada um |
| **P9** | Autorizar o PR | regra sua: remote só com liberação | commit já empurrado na branch da arena; PR **não aberto** |

`session_open.py check` retorna **3** enquanto P1–P3 estiverem vazios. Isso é intencional.

## 2. Delegadas (decididas por contexto — aceitas)

| ID | Decisão | Justificativa | Revisitar se |
|---|---|---|---|
| P10 | Duck-ToolBox **consolidado** | um pacote cobre banking + Play Integrity; separar aumenta superfície de conflito | o scanner apontar colisão real de arquivo/overlay |
| P11 | Kernel **stock + APatch** | nenhum kernel externo declara suporte à build 2026-09-15 do Pong | aparecer release com suporte explícito |
| P12 | HIL **fora** do `.github/workflows` | exige USB físico; runner hospedado não tem o aparelho | existir runner self-hosted com o Pong |
| P13 | HIL A/B como **pré-gate** | isola `boot`/`init_boot`; não cobre `system`/`vendor` nem UI | — (aditivo, nunca substitui o gate 10) |
| P14 | Quarentena **no host**, nunca `mount --bind` | `post-fs-data.d` roda depois da varredura de módulos | — (mecanismo comprovadamente ineficaz) |

## 3. Parâmetros fixados por performance (P6/P7)

| Parâmetro | Valor | Efeito |
|---|---|---|
| Canário em AVD | 60 s | detecta crash de `system_server` sem custo longo |
| Canário físico | 10 min | cobre primeiro boot completo |
| Baseline de AVC | 0 novos `avc: denied` | regressão de SELinux falha o gate |
| Retenção de cache | 5 dias (Actions) / 90 dias (prune local) | evita rebaixar ~6 GB por run |
| Cache inline máximo | 25 MB | mantém o repo leve |

## 4. Como desbloquear em um comando

```bash
# 1) você responde P1–P3 editando (ou ditando) o decision.json
python3 skills/evox-rom-ci-optimizer/scripts/session_open.py auto --out workspace/decision.json
# 2) preencha build.flavor, build.zip_path, build.zip_sha256
# 3) confirme
python3 skills/evox-rom-ci-optimizer/scripts/session_open.py check --file workspace/decision.json
# exit 0 → execução liberada (P1–P3 resolvidos); exit 3 → ainda falta algo
```

## 5. O que **não** é pendência (fechado)

- Ordem F0–F5 dos 15 módulos · kernel stock+APatch · HIL A/B como gate autoritativo ·
  AVD como pré-gate · quarentena no host · `boot.img` de rollback · cache versionado ·
  Release Artifact antes do USB · encerramento automático na inatividade.
