# P1 — Vanilla × GApps: a diferença real e o que muda na continuidade

**Build em jogo:** `2026-09-15` · `EvolutionX-16.0-…-Pong-11.11` · Android 16 · device Pong
**Decisão:** sua (P1). Este documento existe para você decidir com o trade-off na mão — e para a
coleta das duas variantes ficar **pinada**, sem “baixar de novo e vir outra coisa”.

## 1. O que muda tecnicamente

| Camada | Vanilla | GApps |
|---|---|---|
| `/system/priv-app` | sem GMS/Play Store/Vending | GMS Core, Play Store, GSF, GSA e afins já instalados |
| Permissões privileged | sysconfig mínimo | `sysconfig/*.xml` do Google (permissões que só build assinada recebe) |
| Fingerprint / certificação | build sem certificação Google | fingerprint do build Evolve, caminho curto para Play Integrity |
| Atualização (OTA) | updater da Evolution X mantém o build limpo | updater mantém Google + ROM juntos, sem reflash |
| Superfície de conflito | menor (`priv-app` e `.so` do Google não existem) | maior (GMS, sysconfig, permissões, serviços em background) |
| Consumo em repouso | menor | maior (Play Services, GSA, telemetria) |
| Espaço em `/system` | menor | maior (não muda `/data`) |

## 2. Impacto nos 15 módulos (o que você pediu)

| Módulo | Vanilla | GApps |
|---|---|---|
| **M03 Google Unlocked / GApps A16** | obrigatório instalar GApps A16 (NikGApps/MindTheGapps) — e é o módulo de **maior risco**: mexe em `system` já assinado | **satisfeito de origem**; o módulo passa a ser só “unlocked/Pixel features” |
| **M07 Fingerprint Google** | caminho longo: precisa de props + certificação | curto: build já certificada; só ajuste de feature |
| **M08 Banking / Play Integrity** | depende de PIFork + TrickyStore + props manuais; mais frágil | mesma stack, porém com base certificada → taxa de sucesso maior |
| **M02 Camera GCam** | GCam funciona, mas sem Play Services alguns recursos/backup ficam limitados | GCam com backup/sync do Google funcionando |
| **M04/M06/M09/M10/M11** | iguais nos dois | iguais nos dois |
| **M12A/M12B (MaxManager, GenieX)** | iguais; menos serviços competindo por RAM | iguais; mais serviços em repouso |
| **M01 APatch (Guard-4)** | igual | igual |

Resumo: **Vanilla joga trabalho para os módulos** (você constrói o Google por cima);
**GApps tira trabalho dos módulos** (você herda o Google pronto e paga em peso/superfície).

## 3. Continuidade (o critério que pesa mais para você)

| Cenário | Vanilla | GApps |
|---|---|---|
| Nova build da ROM (ex.: outubro) | reflash do pacote GApps + revalidar M03/M07/M08 + refazer snapshot da camada `system` | atualiza e revalida M07/M08 apenas |
| Rollback de um módulo | fácil (nada do Google no sistema) | fácil, mas GMS atualiza sozinho — precisa congelar versão |
| Snapshot por partes (M14) | 3 partes mudam a cada update (ROM, GApps, patch) | 2 partes (ROM+patch) |
| “Deu ruim, volta” | volta para `boot.img` stock + slot A/B | idem |
| Custo de disco do laboratório | dois zips (~2,5 GB cada) se quiser manter as duas opções | idem |

**Continuidade na prática:** GApps tem menos passos repetidos por atualização; Vanilla tem menos
estado escondido (nada atualiza por baixo dos panos).

## 4. Performance (o que você pediu em P6/P7)

- **Vanilla** tende a ganhar em RAM/repouso e tempo de boot — menos processos privilegiados.
- **GApps** perde um pouco em repouso, mas você recupera desativando o que não usa (GSA, Drive,
  backups) e mantendo o resto. O gargalo real de performance no Pong é térmico/Governor, não o GMS.
- Nos dois casos o ajuste fino é o mesmo: baseline de AVC = 0, canário de 10 min e comparação de
  `dumpsys batterystats`/`meminfo` antes e depois de cada módulo (já no `rollout_gate.sh`).

## 5. Recomendação do agente (você decide)

**Recomendo GApps** para o seu caso, porque seus objetivos declarados são *performance estável +
continuidade* e o escopo inclui Google Unlocked/GApps A16, Fingerprint Google e banking/Play
Integrity. Com GApps:

- M03 deixa de ser um flash arriscado em `system` assinado (maior fonte de bootloop do plano);
- Play Integrity e fingerprint saem de “montanha-russa de props” para “base certificada + ajuste”;
- cada atualização da ROM custa menos passos e menos revalidação.

**Escolha Vanilla se** o objetivo virar privacidade/controle total, laboratório mínimo, ou se você
quiser o Google **fora** do `/system` (ex.: microG/perfil separado). Nesse caso aceite: mais
trabalho em M03/M07/M08 e mais um passo por atualização.

## 6. Coleta determinística das duas (o “objeto passageiro”)

Regra: **as duas variantes da MESMA build** são pinadas por nome + URL + sha256. O primeiro fetch
define o pin; qualquer divergência depois é **drift** (exit 4), nunca substituição silenciosa.

```bash
# 1) baixa/confere as duas (idempotente, retomável, atômico)
skills/evox-rom-ci-optimizer/scripts/rom_artifact_fetch.sh --variant both \
  --dest "$PWD/workspace/artifacts" \
  --lock "$PWD/workspace/artifacts/rom-artifacts.lock.json" \
  --env-out "$PWD/workspace/evox.env"

# 2) depois de decidir, fixe a variante no env e no decision.json
source workspace/evox.env          # exporta EVOX_ZIP, EVOX_SHA256_*, EVOX_VARIANT
python3 skills/evox-rom-ci-optimizer/scripts/session_open.py check --file workspace/decision.json
```

**O que o env fixa (caminhos absolutos, para não errar de alvo):**
`EVOX_ARTIFACTS_DIR` · `EVOX_VARIANT` · `EVOX_ZIP_VANILLA` · `EVOX_ZIP_GAPPS` ·
`EVOX_SHA256_VANILLA` · `EVOX_SHA256_GAPPS` · `EVOX_ZIP` (atalho para a variante escolhida).

**Determinismo:** o manifesto `skills/evox-rom-ci-optimizer/references/rom-artifacts.json` é a
única fonte de nome/URL/build. O lock `rom-artifacts.lock.json` guarda `sha256`, `bytes`,
`source_url` e `pinned_at` de cada variante. Rodar de novo **não** troca o arquivo; se o CDN
mudar o conteúdo, o script para em exit 4 e guarda o suspeito como `.zip.mismatch` para perícia.

**Sobrevive a:** reinício de sessão, novo worktree, reexecução do workflow — o lock e os arquivos
ficam em `workspace/artifacts/` (ignorado pelo Git, mas persistente no seu disco).
**Só se perde em:** reset completo do ambiente (recriação do workspace/máquina) — aí o primeiro
fetch refaz o pin; o `sha256` esperado pode ser conferido contra o que você já tinha.

## 7. O que preciso de você (2 linhas)

1. **Vanilla ou GApps** (a recomendação acima é GApps; se preferir Vanilla, sem problema).
2. Confirmar que posso rodar o fetch das duas variantes no **seu** host (o sandbox não tem egress
   para `cdn.evolution-x.org` — aqui o script sai 3 de propósito, sem fingir download).
