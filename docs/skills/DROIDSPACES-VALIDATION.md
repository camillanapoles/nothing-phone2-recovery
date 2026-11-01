# DroidSpaces (M05) — validação executável, não promessa

> Escopo: garantir que o M05 entre **no momento que a documentação do próprio app manda**, com
> **todas as variáveis preenchidas** e **todos os requisitos provados por teste**.
> Contrato: `skills/evox-rom-ci-optimizer/references/droidspaces-requirements.json`.
> Gate: `skills/evox-rom-ci-optimizer/scripts/droidspaces_preflight.py`
> (0 PRONTO · 3 PENDENTE · 2 uso).
> Suíte: `skills/evox-rom-ci-optimizer/tests/test_droidspaces_preflight.sh` — **26 casos**.

## 1. Veredito em uma linha

**O M05 está pronto para entrar como contrato e como gate — e está PENDENTE na única coisa que
depende de dado que eu não tenho:** o arquivo de `CONFIG_*` do kernel da build pinada. Sem ele o
`--kernel-evidence` sai 3, e 3 **não** é aprovação.

| Modo | O que prova | Estado hoje |
|---|---|---|
| `--static` | app v7.1.0 + sha256, ordem F0/W1 pos. 2 depois do M01, 12 `CONFIG_*`, `proc_checks`, caminhos, R03, motores, rollback | **PRONTO** (23 checks OK) |
| `--kernel-evidence F` | o kernel da ROM tem as 12 configs que o DroidSpaces exige | **PENDENTE** — falta o arquivo (sai da L4 ou de candidato certificado) |
| `--device --adb adb` | `pong`, root ativo, SELinux Enforcing, 6 namespaces, `/proc/sysvipc*`, posix-mqueue | **PENDENTE** — não há device/AVD nesta sessão |
| `--device --expect-installed` | `/data/local/Droidspaces/bin`, `/data/adb/modules/droidspaces_kernel`, `service.d` | **PENDENTE** — só depois da instalação |

## 2. O que a documentação do app manda (e como está codificado)

| Exigência da documentação | Campo no contrato | Check que reprova se faltar |
|---|---|---|
| Instalar **depois do root** | `install.after = ["M01"]` | `ordem_depois_de_M01` |
| Antes de GApps/identidade/desempenho | `install.before = ["M03","M07","M08","M12A","M12B"]` | `ordem_antes_de_M03` |
| Fase fundação, 2º da fila | `install.phase = "F0"`, `position = 2` | `fase_F0` |
| APK universal oficial com hash | `app.apk.url/sha256/size_bytes` | `apk_sha256`, `apk_tamanho`, `apk_https` |
| Kernel com SysV IPC + POSIX mqueue | `kernel.configs_required` (12 itens) | `configs_declaradas` + `--kernel-evidence` |
| Namespaces uts/ipc/pid/net/user/mnt | `runtime.namespaces` | `namespaces` (estático e no device) |
| `/proc/sysvipc/{shm,sem,msg}` e `posix-mqueue/qsize` legíveis | `runtime.proc_checks` | `procfs_ipc` |
| Binário, módulo de kernel e `service.d` | `runtime.paths` | `runtime_instalado` |
| **Proibido** mount-hide global do SUSFS (R03) | `constraints.mount_hide_global = false` | `r03_mount_hide_desligado` |
| SELinux Enforcing | `constraints.selinux = "Enforcing"` | `selinux` |
| Motores suportados: apatch/kernelsu/sukisu (**Magisk não**) | `constraints.supported_engines` | `motor_suportado` + `root_engine_gate.py` |
| Nunca reiniciar com o daemon subindo; incompatível com Shamiko/Mountify/Riru | `constraints.prohibitions` | `sem_placeholder` + leitura no contrato |
| Rollback sem consumir `boot_stock_rollback.img` | `rollback` | declarado e usado pelo ledger |

A documentação do aparelho (`ci-build-full/build-package/instructions/install-guide.md`, Step 6)
fecha na mesma ordem: ZygiskNext → TrickyStore → PIFork → LSPosed → **Droidspaces por último**,
com "DO NOT reboot until Droidspaces boots safely". Duas fontes independentes, mesma conclusão.

## 3. Presença do M05 no projeto (não só menção)

| Onde | O que está lá |
|---|---|
| `references/droidspaces-requirements.json` | contrato completo (app, hash, ordem, kernel, runtime, R03, motores, rollback, fontes) |
| `references/module-requirements.json` | M05 com `app.version`, `requirements_ref`, `install_phase`, `install_position`, `depends_on: ["M01"]`, `supported_engines` |
| `references/module-rollout-order.md` | §4.1 "o momento é ditado pela documentação do app" — tabela item→prova |
| `references/module-matrix-5w1h.md` | M05 em W1 com os 4 namespaces e o dono do runtime |
| `scripts/droidspaces_preflight.py` | gate de 3 modos |
| `scripts/root_engine_gate.py` | `m05_motor`, `m05_ordem`, `m05_kernel_configs` (condição/pendente) |
| `tests/test_droidspaces_preflight.sh` | 26 casos, com fixtures que reprovam |
| `Makefile` (raiz) | `make m05` = contrato estático + gate do motor |
| `Makefile` (skill) | `test-droidspaces` + ligado em `test-gates` → `make prove` |

## 4. Como rodar

```bash
make m05                                                        # contrato + gate do motor
python3 skills/evox-rom-ci-optimizer/scripts/droidspaces_preflight.py --root . --static
python3 skills/evox-rom-ci-optimizer/scripts/droidspaces_preflight.py --root . \
        --kernel-evidence workspace/l4/kernel-config.json        # PENDENTE até este arquivo existir
python3 skills/evox-rom-ci-optimizer/scripts/droidspaces_preflight.py --root . \
        --device --adb adb --expect-installed                    # depois do PASS do canário
bash skills/evox-rom-ci-optimizer/tests/test_droidspaces_preflight.sh   # 26/26
```

## 5. Falsificação (o teste prova que sabe reprovar)

9 mutantes novos, todos mortos por asserção:

| Mutante | Mutação | Quem mata |
|---|---|---|
| M107 | hash do APK vira sempre-verde | "sha256 inválido reprova" |
| M108 | R03 (mount-hide global) vira sempre-verde | "mount-hide global reprova" |
| M109 | loop de `CONFIG_*` ignorado | "config faltando reprova" |
| M110 | SELinux sempre-verde | "SELinux Permissive reprova" |
| M111 | namespaces sempre-verdes | "namespace faltando reprova" |
| M112 | ordem (depois do M01) sempre-verde | "instalar sem M01 reprova" |
| M113 | versão do M05 não casa com o app | "versão divergente reprova" |
| M114 | motor fora da lista liberado | "Magisk → INCOMPATÍVEL" |
| M115 | evidência de kernel incompleta liberada | "evidência sem SYSVIPC deixa PENDENTE" |

## 6. Limites — o que ainda **não** está provado

1. **Configs do kernel da build pinada**: não há arquivo de `CONFIG_*` nesta sessão (a L4 depende do
   `.zip` oficial; o CDN da Evolution X não é alcançável daqui). O contrato **exige** a prova; até
   ela existir, o M05 fica PENDENTE — e é assim que deve ser.
2. **Instalação real**: nada foi instalado no aparelho. `--device --expect-installed` é o teste que
   fecha isso, e só roda depois do PASS do canário na staging (regra: nada no USB antes do Release
   Artifact testado).
3. **Conflitos declarados** (Shamiko / Mountify / LSPosed-Riru): estão no contrato como proibição, mas
   o teste de conflito real é o `static_conflict_scanner.py` rodando sobre os ZIPs reais.
4. **Decisão A (APatch)** segue como **recomendação minha**, não como escolha confirmada por você.
