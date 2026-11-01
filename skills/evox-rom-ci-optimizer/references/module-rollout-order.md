# Ordem incremental ratificada dos módulos (15 itens)

> Sua lista é a **intenção**; esta é a **ordem de execução** com dependência explícita.
> Onde eu mudei a ordem, o motivo está na coluna "por que antes/depois". Nada foi removido.

## 1. Mapa: sua numeração → código → fase

| Sua # | Módulo | Código | Fase ratificada | Mudou? |
|---|---|---|---|---|
| 1 | APatch Root (Guard-4) | **M01** | **F0** fundação | não (é o primeiro mesmo) |
| 5 | DroidSpaces | **M05** | **F0** fundação | sobe para 2º (companheiro de kernel) |
| 3 | Google Unlocked (GApps A16) | **M03** | **F1** identidade | sobe (base para 7 e 8) |
| 7 | Fingerprint Google | **M07** | **F1** identidade | sobe (depende de GApps) |
| 8 | Banking / Play Integrity | **M08** | **F1** identidade | sobe (depende de 3+7) |
| — | Duck-ToolBox | **M08** | **F1** identidade | consolida 7+8 (ver §3) |
| — | MaxManager | **M12A** | **F2** desempenho | entra antes de câmera |
| — | GenieX | **M12B** | **F2** desempenho | idem |
| 2 | Camera (GCam) | **M02** | **F3** mídia | **desce** (ver §2) |
| 4 | Screen Capture | **M04** | **F4** janelas/storage/rede | desce (reinicia Zygote) |
| 6 | Free-Form Windows | **M06** | **F4** | desce (mesmo motivo) |
| 9 | SAF | **M09** | **F4** | desce |
| 10 | Network/socket por app | **M10** | **F4** | desce (netfilter depois do core) |
| 11 | Port-forward intranet | **M11** | **F4** | desce (depende de 10) |
| 13 | Ambient Open CI | **M13** | **F5** continuidade | — |
| 14 | Snapshots por camada | **M14** | **F5** | — |
| 15 | Release pré-USB | **M15** | **F5** | — (último, por definição) |

## 2. Por que a câmera desce (sua #2 → F3)

Câmera injeta `.so` e XML em `/product/priv-app` e `/vendor`, e é o módulo com maior chance de
derrubar `cameraserver`. Instalada antes de root/identidade, qualquer falha vira ambiguidade:
"foi a câmera ou o kernel?". Colocada depois de F0–F2, o baseline já está provado e o rollback é
cirúrgico (`boot_stock_rollback.img` + remoção do módulo).

## 3. Duck-ToolBox cobre sua #7 e #8 (não some com elas)

Ele é hub de atestação (RKP/X.509/P-256) com `duckd` e WebUI, e consolida fingerprint + banking.
Portanto a fase F1 fica:

```text
M03 GApps  →  M07 fingerprint (props base)  →  M08 Duck-ToolBox (hub: RKP + banking)
```

Se você quiser manter as duas coisas em módulos separados, o ledger trata como módulos distintos —
mas **não** empilhe spoofers concorrentes (regra R04: um único dono da escrita de identidade).

## 4. Dependências que o ledger faz cumprir

| Módulo | Exige antes | Se faltar |
|---|---|---|
| M05 | M01 (root) | daemon não sobe / seccomp bloqueia |
| M07 | M03 | sem base Google, props não têm efeito |
| M08 | M03 + M07 | atestação sem chave coerente |
| M12A/M12B | M01 (root) | sem escrita em `sysfs`/NPU |
| M02 | M01 + M03 | conflito de identidade de câmera mascarado |
| M04/M06/M09/M10/M11 | F0–F3 estáveis | `stop; start` em sistema instável = bootloop |
| M13/M14/M15 | todas as fases | release sem base = artefato inválido |

`rollout_gate.sh` recusa onda decrescente e módulo seguinte sem PASS — a tabela acima é a política;
o ledger é a trava.

## 5. O que entra em cada fase (com critério de saída)

| Fase | Módulos | Critério de saída (binário) |
|---|---|---|
| **F0** | M01, M05 | boot_completed=1 com root ativo · `rollout_gate` PASS nos dois · rollback verificado |
| **F1** | M03, M07, M08 | GMS sem crash · fingerprint lida de volta · atestação responde |
| **F2** | M12A, M12B | escrita única em `sysfs` (sem corrida) · NPU responde |
| **F3** | M02 | `cameraserver` estável · XML sem colisão |
| **F4** | M04, M06, M09, M10, M11 | SurfaceFlinger/SystemUI estáveis · SAF R/W · regra por UID ativa |
| **F5** | M13, M14, M15 | 10/10 gates · snapshot com manifesto · pacote pré-USB com SHA256SUMS |

## 6. Compatibilidade conjunta (versão × kernel × módulo)

```text
build   EvolutionX-16.0-20260915-Pong-11.11   (Vanilla ou GAPPS — decisão da usuária)
API     36 / Android 16
kernel  o do pacote (L4); se custom, mesma base major.minor e KMI idêntico
módulos cada um declara: android_api=36, kmi=<da ROM>, arch=arm64-v8a,
        root_engine (apatch|kernelsu|magisk), susfs/zygisk, url+sha256
```

O gate 1 (`kernel_compat_check.sh`) cobre kernel; o scanner cobre colisão de arquivo; o
`rollout_gate` cobre ordem e estabilidade. **ABI/versão de módulo** é o único eixo que ainda é
declarativo: se o módulo não declarar `android_api`/`kmi`, ele é rejeitado antes de entrar.
