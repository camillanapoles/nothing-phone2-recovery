# Melhor das duas instalações — adjudicação A × B × B-revisada e sequência fundida v2

**Estado:** proposta auditada e executável como plano, **pendente de ratificação** neste branch.
Ela não substitui `docs/skills/APPROVED-INSTALL-SEQUENCE.md` nem libera download, flash ou cabo.
O grafo executável que acompanha este documento é `docs/skills/install-graph-v2.json`; a prova
estrutural é `tests/test_install_graph_v2.sh`.

## 0. Como ler as três fontes

| Sigla | Fonte | Papel nesta adjudicação |
|---|---|---|
| **A** | Sequência canônica deste branch: `APPROVED-INSTALL-SEQUENCE.md`, M01–M15, R01–R09, matriz do `pong`, contrato DroidSpaces | Base de segurança/kernel/módulos; nenhuma exigência dela some sem decisão explícita abaixo |
| **B** | Proposta colada pela usuária: Vanilla, NikGapps Core enxuto, fases F0–F8, Gemini/Drive/CircleToSearch/Morphe/GMS Doze | Base de produto/apps e várias correções reais; contém premissas e pins que precisaram de prova |
| **B-rev** | Evolução já existente em `origin/main` (PR #11): 21 camadas, `install-stack.json`, TEESimulator-RS, VBMeta Fixer, `decisions.json` | Terceira fonte auditada item a item; foi aproveitada seletivamente, nunca copiada por atacado |

Critério de desempate, nesta ordem: (1) pai upstream realmente atendido; (2) fonte primária do
projeto-pai sobre guia de terceiros; (3) estabilidade e reversibilidade; (4) um único dono por
função; (5) menos binário fechado e menos automação opaca; (6) nenhum PASS sem observação que
possa falhar. “SOTA” aqui não significa release do mesmo dia: significa arquitetura atual,
pinada e com fallback nomeado.

## 1. Resumo executivo da fusão vencedora

```text
stock Android 16 mais recente registrado
  -> Evolution X 11.11 Vanilla
  -> reboot SOMENTE para recovery -> NikGapps Core customizado -> primeiro boot
  -> kernel compilado (DroidSpaces ABI + KernelSU-Next embutido + SUSFS de arvore)
  -> meta-overlayfs -> slot router -> DroidSpaces
  -> SUSFS userspace -> App Profile -> Zygisk Next
  -> PlayIntegrityFork standalone + TEESimulator-RS NoEnhanced
  -> MaxManager -> GenieX -> Camera -> janelas/storage/rede
  -> Gemini / Drive opcional / CircleToSearch / Morphe
  -> GMS Doze apenas se medicao culpar o GMS
  -> snapshots -> 72h de uso certificado
```

As maiores correções em relação às duas listas são:

1. **NikGapps não entra depois do primeiro boot.** Em A/B, a ordem física é ROM → reboot só para
   recovery (troca de slot) → addon → sistema. O M03 “depois do M01” da fila canônica vale para a
   variante com Google embutido ou para a validação de runtime, não para instalar GApps numa
   Vanilla já bootada.
2. **KernelSU 3.x exige um metamódulo.** A e B omitiram esse pai. Sem `meta-overlayfs`, arquivos
   sob `system/` de módulos regulares não têm montagem garantida.
3. **KernelSU-Next embutido e LKM são alternativas, não camadas.** B-rev empilhava os dois. O
   caminho primário é `CONFIG_KSU=y` no mesmo kernel do DroidSpaces; o `.ko` vira fallback com
   kernel sem o driver.
4. **DroidSpaces volta para a fundação**, logo depois de root/metamódulo e antes da ocultação.
   B o omitia, embora ele seja o pai que força o kernel customizado.
5. **HMA-OSS atual depende do provedor Zygisk, não de framework Xposed.** B-rev lhe dava apenas
   KernelSU como pai; este grafo liga `hma-oss -> zygisk-next` e o teste reprova remover essa aresta.
6. **Um escritor de integridade por função:** PIFork standalone cuida de fingerprint/props;
   TEESimulator-RS NoEnhanced cuida de keystore. Duck-ToolBox fica como candidato/manager
   diferido — nunca com a engine PI embutida ligada junto do PIFork.
7. **Keybox não é download automático nem requisito universal.** Ela é condicional ao perfil de
   atestação medido; Yurikey/Specter e rotação automática ficam fora do caminho primário.
8. **Drive não é pai do backup do Android.** O transporte `com.google.android.gms/.backup.BackupTransportService`
   vive no GMS e se prova com `bmgr`; SetupWizard/GoogleRestore é outra decisão, a do fluxo de
   restauração na configuração inicial.
9. **O gate de ocultação de B chamava-se “M04”, colidindo com o M04 canônico.** Na fusão ele vira
   a matriz de detecção dentro de S4/S5, sem renumerar M01–M15.
10. **Nenhum item canônico desapareceu:** M01–M15 continuam cobertos e o teste reprova se um ID sumir.

## 2. Adjudicação caso a caso

Legenda: **ADOTAR** entra como proposto · **ADAPTAR** entra corrigido · **CONDICIONAL** só com
gatilho medido · **CANDIDATO** exige gate A/B próprio · **REJEITAR** não entra.

### D01 — Flavor da ROM e provedor de GApps

- **A:** M03 cobre duas trilhas (variante GApps ou NikGapps sobre Vanilla), mas a fila publicada
  podia ser lida como módulo tardio.
- **B:** Vanilla + NikGapps Core mínimo (GMS, Play Store, GSF e sincronizadores).
- **Veredito: ADAPTAR B como trilha principal.** É o conjunto mais enxuto e controlado. A
  instalação física fica em S1, na mesma sessão da ROM e antes do primeiro boot; a validação de
  Play/GMS acontece em S2. A variante GApps permanece anexo válido se a decisão ratificada mudar.
- **Pais/restrições:** um único provedor; pacote arm64 para Android 16; ZIP e `nikgapps.config`
  pinados por nome, data e SHA-256; `InstallPartition=default`; GoogleChrome/WebViewGoogle/
  TrichromeLibrary, Velvet e DigitalWellbeing explicitamente em `0`.
- **PASS:** `pm list packages` sem Chrome/Velvet/Wellbeing; Play autentica; GMS sem loop de crash;
  `bmgr list transports` mostra o transporte Google.

### D02 — SetupWizard/GoogleRestore, Drive e backup

- **B:** “Core sem o transporte = sem backup; com Drive resolve”.
- **B-rev:** manteve Drive como pai do backup.
- **Veredito: REJEITAR a causalidade; ADAPTAR em duas decisões separadas.**
  Transporte contínuo é do GMS e se testa com `bmgr`; SetupWizard/GoogleRestore só entra se a
  usuária quiser restaurar dados no setup inicial — o contrário da premissa “boot limpo sem
  restore”. Drive é app opcional de arquivos.
- **PASS:** backup contínuo = `bmgr enabled`, transporte selecionado e `bmgr backupnow` medido em
  S10; restore de setup = presença/ausência declarada antes do primeiro boot.

### D03 — Firmware stock e `B4.0-251119-1654`

- **B:** flash do firmware NOS 4.0 nos dois slots, ligado ao commit `4ec5491…`.
- **Verificação:** o commit completo é real e é hoje a ponta de `lineage-23.2`; sua mensagem é
  “treewide: Update changes to Pong-B4.0-251119-1654”. Isso prova a ligação kernel↔baseline,
  não prova sozinho quais partições de firmware o payload da Evolution já atualiza.
- **Veredito: ADAPTAR.** Requisito = stock Android 16 mais recente no aparelho, bootado uma vez
  com chamadas/SMS/IMS testados, com fingerprint e versões de rádio registrados. `B4.0-251119-1654`
  entra como baseline candidata; flash avulso “nos dois slots” só com instrução do mantenedor e
  inventário da L4 dizendo quais partições faltam.
- **PASS:** L4 lista partições; decisão “ROM inclui / stock pré-requisito” fica escrita antes de S1.

### D04 — Kernel customizado e integração KernelSU-Next × SUSFS

- **A:** Decisão C (kernel próprio) por causa do DroidSpaces; B01 (fonte) e E03 (build) abertos.
- **B:** KernelSU-Next + patches SUSFS, sem desenhar a integração.
- **B-rev:** `CONFIG_KSU=y` e instalação via LKM ao mesmo tempo; SUSFS presumido.
- **Veredito: ADAPTAR para um único caminho primário.** Um kernel 5.10 compilado a partir de
  árvore pinada com: patches/CONFIGs do DroidSpaces, `CONFIG_KSU=y` e SUSFS já integrado à
  árvore do KernelSU-Next. A integração precisa ser provada por `.config`/símbolos, não presumida:
  patch SUSFS genérico pode ser descartado em silêncio por runners de CI conhecidos.
- **Pin candidato de fonte:** `lineage-23.2@4ec5491f6b5fd8776207a2a453d6b98b1928de7a` — candidato,
  porque neste branch o B01 continua aberto.
- **Fallback nomeado (nunca acumulativo):** kernel sem `CONFIG_KSU` + `aarch64_android13-5.10_kernelsu.ko`
  da release v3.4.2; ou, só para o SUSFS, `android13-5.10_susfs_guard_lkm.ko` da mesma release,
  com prova separada de paridade de features.
- **PASS:** 7 artefatos com SHA-256; `kernel_compat_check` exit 0; no `.config` compilado constam
  as CONFIGs do contrato DroidSpaces, `CONFIG_KSU`, presença SUSFS e `CONFIG_OVERLAY_FS`.

### D05 — SUSFS em duas metades e o metamódulo esquecido

- **Veredito: ADAPTAR B e completar com o pai novo.** Kernel com feature level ≥ 1.5.2 + userspace
  `susfs4ksu-module` `v1.5.2+_R28`. “Versão idêntica” é exigência forte demais: o binário atual
  seleciona interface 1.5.x/2.x; o contrato é comando respondendo e matriz limpa.
- **Restrições:** hide global de mounts **desligado** (R03/DroidSpaces); `try_umount` por app;
  spoof de `uname` só se um detector nomear essa falha (ele também falsifica evidência de kernel);
  logs ligados só durante diagnóstico.
- **Metamódulo:** `meta-overlayfs` 1.3.1 é a primeira infraestrutura após o Manager e pai de todo
  módulo que monte `system/`. Mountify fica vetado (segundo metamódulo e conflito com DroidSpaces).
- **PASS:** `ksu_susfs show version` + `show enabled_features` sem erro; container do M05 continua vivo
  depois de cada mudança de ocultação; módulo de teste sob `system/` visível após reboot.

### D06 — DroidSpaces (M05)

- **B:** ausente. **Veredito: ADOTAR A integralmente.** M05 é o pai do kernel e entra em S3, antes
  de SUSFS userspace/Zygisk, para que cada camada de ocultação precise re-provar o container.
- **Restrições que continuam valendo:** nada de Magisk/Shamiko/hide global; nunca reiniciar com o
  daemon subindo; POSIX mqueue/SysV IPC completos, não só namespaces.
- **PASS:** Check Requirements verde + `ls /proc/sysvipc/` e `/proc/sys/fs/mqueue/` + container real.

### D07 — Provedor Zygisk

- **B:** Zygisk Next com `just_umount`, linker `builtin` e memória anônima.
- **Veredito: ADAPTAR.** Zygisk Next v1.5.2-864 é o default pela compatibilidade dos módulos
  atuais, com a dívida registrada: binário fechado desde a linha 0.9.2/1.0.
- **Aplicação:** instalar em default primeiro; ligar **um flag por vez** (`just_umount` → linker
  `builtin` → anonymous), rodando a matriz de módulos/detecção entre eles. O próprio upstream
  avisa que o linker embutido pode quebrar módulos — rollback é voltar a `system`/default.
- **Candidatos abertos:** ReZygisk e NeoZygisk, sempre um por vez; trocar de provedor invalida
  todo PASS Zygisk anterior.
- **REJEITAR:** Shamiko (ZN ≥1.3 tornou a função amplamente redundante; conflito com DroidSpaces) e Zygisk Assistant
  (parado em 2025-02 e redundante com SUSFS + App Profile).

### D08 — Ocultação: SUSFS/App Profile primeiro, NoHello e HMA-OSS por gatilho

- **Ordem vencedora:** SUSFS userspace → App Profile (`Umount modules` só nos apps alvo) →
  Zygisk Next → matriz de detecção. Só então camadas condicionais.
- **NoHello: CONDICIONAL.** Sem tag pública `v0.0.8` localizada; última release conferida é
  `0.0.7` (2025-05-31). Pin novo exige commit + SHA-256 do artefato. Whitelist + Mount Rule
  System pode superaquecer; preferir blacklist e avaliar `umount_persist` sem tocar na partição.
- **HMA-OSS: OPCIONAL e corrigido.** O fork atual (frknkrc44, `oss-173`) é módulo Zygisk: o pai é
  o provedor Zygisk. A linhagem antiga dependente de framework Xposed não entra — framework Xposed
  segue fora dos 15 módulos. Só instalar se um app real falhar por enumerar pacotes.
- **Não tocar:** SELinux Enforcing sempre; a partição `persist` nunca é escrita/formatada/
  restaurada de outro aparelho (Goodix `fpcal`); esconder pegadas não pede enfraquecer nenhum dos dois.

### D09 — Fingerprint/props: PIFork standalone × Duck-ToolBox

- **A (R04):** Duck consolida M07/M08; PIF avulso ao lado gera duplicidade.
- **B/B-rev:** PIFork avulso (B-rev pinava v16, já velho).
- **Veredito: ADAPTAR — PIFork standalone no caminho primário; Duck como candidato diferido.**
  Motivos: PIFork é o motor de referência, com release pinável e comportamento documentado;
  o próprio Duck declara que teste local **não** estabelece veredito Play Integrity nem
  compatibilidade física. Caminho estável ganha do consolidado até o gate A/B no aparelho.
- **Pin:** PlayIntegrityFork **v18** (SHA-256 no grafo). A v19 saiu hoje, 2026-11-03 — entra como
  candidata de atualização, não como pin de estabilidade no dia do lançamento.
- **Regra de ouro mantida da R04:** Duck + PIFork com engine PI ligada ao mesmo tempo é conflito;
  o teste do grafo reprova ativar os dois. Se um dia o Duck vencer o gate, ele substitui o PIFork —
  não coexiste.
- **Fingerprint é consumível:** print público pode ser banido; PASS é veredito medido, nunca promessa.

### D10 — Keystore/atestação: TEESimulator-RS × TrickyStore × keybox × VBMeta

- **Veredito: ADAPTAR B-rev.** Motor único = **TEESimulator-RS v6.0.1-360
  `Release-NoEnhanced`** (aberto, substitui a linha TrickyStore e reusa o diretório de config).
  A build *Enhanced* embute daemon de automação/rotação de keybox — mais superfície e fetch de
  material secreto; fica fora do caminho estável.
- **Fallback nomeado:** TrickyStoreOSS (aberto) se o TEESimulator falhar no KeyMint do Android 16;
  o TrickyStore fechado original não é o default.
- **Keybox: CONDICIONAL, nunca baixada por manager.** O perfil software/AOSP pode bastar para o
  objetivo DEVICE; keybox de hardware só entra se necessidade for medida, com material fornecido
  pela usuária, hash registrado fora do repositório e cadeia não revogada. Sem isso, PENDENTE —
  não PASS.
- **VBMeta Fixer: CONDICIONAL de diagnóstico.** O upstream admite que não verifica se deve setar
  o digest; só entra se um detector nomear `ro.boot.vbmeta.digest` e nenhum outro escritor de
  VBHash estiver ligado. B-rev o tratava como obrigatório — rebaixado.
- **Target list mínima:** só apps que precisam (GMS quando o perfil exigir, apps bancários reais).
  Colocar “todos os apps” aumenta risco de quebrar keystore para quem não precisava.

#### Perfis de configuração (nunca misturar)

| Perfil | Objetivo | PIFork | Motor de keystore |
|---|---|---|---|
| **DEVICE** (default) | BASIC+DEVICE medidos | `spoofProps=1`; `spoofProvider` conforme o print e só até onde a medição pedir; security patch do print | cert software/AOSP do motor; target mínimo |
| **Hardware** (se e quando) | tentar atestação de hardware | `spoofProvider=0`; spoof de security patch do PIF desligado | keybox válida; `security_patch.txt` do motor é o dono da data |

A frase de B “spoof de atestação off, fingerprint on” só descreve o segundo perfil. Aplicá-la ao
primeiro é um dos motivos clássicos de DEVICE não vir.

### D11 — Módulos canônicos de performance/camera/janelas/rede

- **Veredito: ADOTAR A.** Nada de B substitui M02/M04/M06/M09–M15; eles entram depois da
  identidade provada, um por reboot, na ordem de risco crescente da fila canônica.
- **MaxManager continua dono exclusivo** de CPU/GPU/thermal/ZRAM/TCP (R01/R02). Nenhum “tuner”
  de app da S8 escreve nesses nós.
- **Camera:** GCam/priv-app exige XML de permissão no metamódulo; nunca sobrescrever `.so`/XML
  de câmera; `cameraserver` estável é o PASS.
- **Bateria honesta:** priv-app fora da imagem economiza storage/dexopt, mas a alegação de
  economia automática vira medição: baseline de idle antes/depois em S6 e S9.

### D12 — WebView, navegador, saneamento e segurança do primeiro boot

- **ADOTAR:** WebView AOSP preservado (sem Chrome/Trichrome), boot limpo sem restore, OTA e
  auto-update da Play **congelados durante** a instalação para o sistema testado ser o sistema pinado.
- **ADAPTAR:** sincronização de contatos/calendário pausa só durante a instalação; volta no uso.
  Congelar update para sempre viraria dívida de segurança — em S10 libera-se seletivamente,
  exceto apps patcheados/detachados.
- **REJEITAR como default:** desligar Play Protect (pausar uma instalação pinada e registrada,
  se ele bloquear, é outra coisa) e desligar Find My Device em nome de bateria.
- **Pai esquecido restaurado:** sem Chrome, algum navegador precisa segurar o role `BROWSER`,
  senão links de Gemini/busca não têm destino. WebView não substitui navegador.
- **PASS:** `dumpsys webviewupdate` com provider válido e versão registrada (WebView velho é
  dívida de Chromium); holder de `BROWSER` lido e registrado.

### D13 — Apps da usuária (U01–U04)

Apps ganham IDs próprios **U01–U04** para não renumerar o cânon.

- **U01 Gemini: ADAPTAR.** Pais: GMS + conta + navegador default. “Funciona sem Velvet” vale para
  o chat standalone; ser o assistente padrão é capacidade separada e disputa o mesmo role com
  o CircleToSearch — um dos dois segura o papel.
- **U02 Drive: OPCIONAL** (ver D02). Entra por sync de arquivos, não por backup.
- **U03 CircleToSearch AKS-Labs `@e4f4614`: ADAPTAR.** O commit existe (2026-10-19) e a árvore
  contém `OCR-translation` com modelos PP-OCR — mas release pública continua a linha 0.x, então o
  artefato é APK **construído do commit**, com SHA-256 e certificado registrados. Pais: Android 10+;
  sem GMS/root por desenho. Preferir pílula/QS tile ao role de assistente se o Gemini ficar como
  assistente. Busca por imagem envia o recorte ao motor escolhido; OCR offline só depois dos
  modelos locais — testar em modo avião. Os 7 critérios de B viram PASS individual; enquanto não
  medidos no `pong`, a camada é PENDENTE, não “OK”.
- **U04 Morphe: ADAPTAR.** “v2.3.0” sozinho não pina nada: Manager e patches versionam separado.
  O pin é o **trio** Manager × patches × versão do YouTube *recomendada por aquele release de
  patches*. Caminho: YouTube stock instalado primeiro → root-mount → **um** método de detach →
  reboot → conferir que a Play não sobrescreveu. Nada de APK pré-patcheado de terceiro.

### D14 — GMS Doze

- **Veredito: CONDICIONAL e renomeado com procedência.** A linha original (gloeyisk) parou em
  1.9.2/2024; `1.9.11` é o fork MarsPatrick. Só entra em S9 se o baseline culpar o GMS e depois da
  arbitragem com o MaxManager. Pode atrasar push/OTP/localização — o PASS inclui FCM entregando.
- **Pais:** GMS funcional + metamódulo (é módulo que monta config) + baseline de idle medido.

### D15 — OTA, snapshots e uso

- **OTA nunca é automático nesta arquitetura:** o boot customizado sai no slot atualizado e
  `/data` (módulos) é único entre slots. Procedimento: nova L4/B01 → rebuild e recertificação do
  kernel → quarentena de módulos no host → OTA → boot customizado no slot novo pelo caminho
  validado → GApps só sobrevivem se o `addon.d` da build provar (senão, reflash em recovery
  antes de bootar o sistema novo) → reexecutar S3–S10 em modo verificação.
- **Snapshots por camada** (M14) guardam artefato+hash+config, nunca keybox nem segredo.
- **Uso diário (M15):** 72h sem panic, matriz de apps reais, `bmgr backupnow`, câmera/rádio/
  térmica no hardware. Staging/AVD não prova vendor, câmera, NPU nem este kernel.

## 3. Sequência fundida final (S0–S10)

Um passo por vez; um módulo por reboot; PASS falhou = rollback daquela camada no grafo.
IDs entre parênteses mapeiam para o cânon (M) ou para apps da usuária (U).

### S0 — Contrato, L4, kernel e staging (nada físico)

1. Conferir SHA-256 do ZIP pinado. **PASS:** hash igual.
2. Extrair a L4 do payload: partições (inclusive a presença da partição de ramdisk inicial é
   listada, não presumida), KMI, configs, boot stock. **PASS:** `rom_assets.json` gerado.
3. Gerar `boot_stock_rollback.img` + `.sha256` byte-idênticos. **PASS:** Guard-4 = VERIFIED.
4. Pinar a árvore do kernel, aplicar patches sem fuzz e compilar (D04). **PASS:** 7 artefatos +
   CONFIGs provadas no `.config`.
5. Staging offline/AVD + scanner + pacote pré-USB (M15 lado release). **PASS:** zero CONFLICT,
   canário por módulo, pacote com hashes.

### S1 — Firmware baseline, ROM e GApps antes do primeiro boot (M03 físico)

1. Provar baseline stock Android 16 e registrar fingerprint/rádio (D03); boot stock com rádio ok.
2. Recovery e partições adicionais conforme instruções do mantenedor e a lista da L4; format data;
   sideload da ROM Vanilla.
3. **Reboot apenas para recovery** (slot A/B) e sideload do NikGapps Core customizado.
   SetupWizard/GoogleRestore só se a decisão de restore estiver ligada na config.
4. Só agora o primeiro boot existe — em S2.

### S2 — Primeiro boot e saneamento

1. Boot sem restore em nuvem; conta; congelar OTA/auto-update durante a instalação.
2. Ler provider/versão do WebView e holder de `BROWSER` (D12).
3. Baseline GMS: Play abre, `bmgr list transports` mostra o transporte Google.
   **PASS de etapa:** `boot_completed=1`, Enforcing, nenhum pacote blacklisted presente.

### S3 — Fundação (M01, M05)

1. Flash do boot do kernel compilado no slot **lido**; Manager KernelSU-Next v3.4.2.
   **PASS:** `su -c id -u` = 0, Enforcing, 10 min sem crash.
2. Instalar `meta-overlayfs` e reboot. **PASS:** montagem de teste visível.
3. Slot router. **PASS:** estado coerente com o slot.
4. DroidSpaces (sem reboot com daemon subindo). **PASS:** requisitos verdes + container real.

### S4 — Ocultação (M08, parte 1)

1. SUSFS userspace R28. **PASS:** versão/features respondem; M05 vivo.
2. App Profile: `Umount modules` apenas nos apps alvo. **PASS:** read-back por app.
3. Zygisk Next em default; um flag por vez com matriz entre eles (D07).
4. Matriz de detecção. NoHello e/ou HMA-OSS entram **somente** se ela nomear a falha (D08).

### S5 — Identidade e integridade (M07/M08)

1. PIFork v18 no perfil DEVICE. **PASS:** veredito parcial medido e registrado.
2. TEESimulator-RS NoEnhanced com target mínimo. **PASS:** keystore estável, attestation demo responde.
3. Keybox somente se o perfil hardware for medido como necessário (D10).
4. VBMeta Fixer somente com gatilho nomeado.
   Apps-detectores usados aqui são removidos antes de S10: detector instalado é superfície de detecção.

### S6 — Performance, IA e câmera (M12A, M12B, M02)

Baseline de idle/térmica antes; MaxManager; GenieX; câmera. Cada um com read-back e reboot próprio.

### S7 — Janelas, storage e rede (M04, M06, M09, M10, M11)

Screen capture → free-form → SAF → rede por app → port-forward (filho do M10, nesta ordem).

### S8 — Apps da usuária (U01–U04)

Gemini → Drive se escolhido → CircleToSearch (7 critérios + modo avião) → YouTube stock pinado →
detach único → Morphe root-mount.

### S9 — Bateria medida

GMS Doze apenas com dreno do GMS provado; repetir baseline e teste de FCM/OTP (D14).

### S10 — Continuidade e uso (M13, M14, M15)

CI ambiente verde → snapshot por camada → liberar sync/updates seletivos → remover detectores →
72h de uso com `evidence.json`. Até aqui, **nenhum** PASS físico foi declarado por este documento.

## 4. Como a garantia “pais atendidos” é mecânica, não retórica

`docs/skills/install-graph-v2.json` declara 43 camadas com `parents`, `conflicts`, pin, restrições,
PASS e rollback. `tests/test_install_graph_v2.sh` reprova (exit ≠ 0) quando:

- um pai não existe, está inativo ou forma ciclo;
- uma filha executa antes do pai (etapa ou passo);
- dois conflitantes estão ativos (ex.: Duck + PIFork);
- há dois donos para root/metamódulo/Zygisk/keystore;
- um ID M01–M15 some da cobertura ativa;
- um pin é `latest`/vazio, ou um pin pendente não está nomeado em `open_gates`;
- as arestas duras somem: `susfs-userspace → {ksu, kernel}`, `hma-oss → zygisk`,
  `pifork → {zygisk, gapps}`, `morphe → {youtube-stock, ksu}`, `droidspaces → {ksu, kernel}`,
  `port-forward → network-per-app`, `meta-overlayfs → {ksu, kernel}`; ou o M05 cai depois da ocultação.

O teste inclui mutantes para cada família acima. Estrutura aprovada **não** é aparelho aprovado:
pins pendentes continuam listados em `open_gates` e nenhum passo físico foi executado.

Comandos:

```sh
bash tests/test_install_graph_v2.sh
python3 skills/evox-rom-ci-optimizer/scripts/architecture_guard.py --check arch
python3 skills/evox-rom-ci-optimizer/scripts/contradiction_scan.py
make -s prove
```

## 5. Vetos e candidatos (não entram por opinião, entram por contrato)

**Vetados neste grafo:** Shamiko · Zygisk Assistant · qualquer framework Xposed ·
Mountify · Magisk · APatch simultâneo · MindTheGapps · microG ao lado do GMS real ·
TrickyStore fechado como default · Yurikey/Specter (fetch de keybox) · segundo provedor Zygisk ·
segundo metamódulo · Chrome/Velvet/Wellbeing na config enxuta.

**Candidatos com gate próprio:** driver LKM do KernelSU-Next · `susfs_guard_lkm` ·
ReZygisk · NeoZygisk · TrickyStoreOSS · OhMyKeymint · Duck-ToolBox como engine/manager ·
TEESimulator *Enhanced* · PIFork v19.

## 6. O que falta para ratificar (ordem de execução)

1. `workspace/decision.json` neste branch (hoje `session_open` acusa decisão ausente): flavor e ZIP.
2. Deliberar a importação da decisão registrada em `origin/main` e dos artefatos úteis do PR #11
   por cherry-pick auditado — nunca merge cego entre grafos sem ancestral comum.
3. Fechar B01: aceitar (ou trocar) o commit candidato e pinar a árvore KernelSU-Next × SUSFS;
   adicionar `CONFIG_OVERLAY_FS` ao contrato do kernel.
4. L4/E03: extrair o payload, compilar e certificar os 7 artefatos.
5. Pinar ZIP do NikGapps + `nikgapps.config` e os artefatos M02/M04/M06/M09–M12 ainda pendentes.
6. Pinar o trio do Morphe e construir o APK do CircleToSearch do commit, com hash/certificado.
7. Registrar os deltas no cânon (`module-requirements.json`, ordem de rollout, R04, plano do
   kernel) e só então promover esta sequência a aprovada com `make -s prove` verde.

Até o item 7 fechar, o estado continua honesto: **arquitetura fundida pronta; execução física
não liberada**.

## 7. Fontes primárias usadas

- LineageOS Wiki (Pong): <https://wiki.lineageos.org/devices/Pong/install/>
- Kernel LineageOS `pong`, commit `4ec5491f…`: <https://github.com/LineageOS/android_kernel_nothing_sm8475/commit/4ec5491f6b5fd8776207a2a453d6b98b1928de7a>
- KernelSU (metamódulo e montagem de módulos): <https://kernelsu.org/guide/metamodule.html> · <https://kernelsu.org/guide/module.html>
- KernelSU-Next: <https://github.com/KernelSU-Next/KernelSU-Next>
- SUSFS userspace: <https://github.com/sidex15/susfs4ksu-module>
- Zygisk Next: <https://github.com/Dr-TSNG/ZygiskNext>
- PlayIntegrityFork: <https://github.com/osm0sis/PlayIntegrityFork>
- TEESimulator-RS: <https://github.com/MashiroSann/TEESimulator-RS>
- Duck-ToolBox: <https://github.com/eltavine/Duck-ToolBox>
- HMA-OSS (fork Zygisk): <https://github.com/frknkrc44/HMA-OSS>
- NoHello: <https://github.com/MhmRdd/NoHello>
- VBMeta Fixer: <https://github.com/reveny/Android-VBMeta-Fixer>
- Android backup transport (`bmgr`): <https://developer.android.com/identity/data/testingbackup>
- CircleToSearch AKS-Labs: <https://github.com/AKS-Labs/CircleToSearch>
- Morphe: <https://morphe.software/faq>
- Universal GMS Doze (fork): <https://github.com/MarsPatrick/universal-gms-doze>
- DroidSpaces (contrato interno): `skills/evox-rom-ci-optimizer/references/droidspaces-requirements.json`
