#!/usr/bin/env python3
"""droidspaces_preflight.py — o DroidSpaces (M05) está pronto para entrar, por teste?

Três modos, todos verificáveis sem device físico:

  --static        contrato preenchido: versão/hash/URL reais, ordem de instalação
                  (depois de M01, antes de M03), requisitos de kernel, R03, motor suportado.
  --kernel-evidence F  prova de que o kernel da ROM tem os CONFIG_* exigidos (L4 ou candidato
                  certificado). Sem essa prova o estado é PENDENTE, nunca "ok".
  --device --adb CMD   checagem no aparelho/AVD: pong, root, SELinux Enforcing, namespaces,
                  /proc/sysvipc, posix-mqueue, caminhos do runtime. `--expect-installed` exige
                  também os diretórios do módulo (pós-instalação).

Uso:
  droidspaces_preflight.py --static [--engine apatch] [--json]
  droidspaces_preflight.py --kernel-evidence kernel.json [--json]
  droidspaces_preflight.py --device --adb adb [--expect-installed] [--json]

Exit: 0 pronto · 3 pendente/reprovado · 2 uso · 4 JSON/arg inválido
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

SK = "skills/evox-rom-ci-optimizer"
DROID = f"{SK}/references/droidspaces-requirements.json"
MODULES = f"{SK}/references/module-requirements.json"
DECISION = f"{SK}/references/root-decision.json"
HEX64 = re.compile(r"[0-9a-f]{64}")
PLACEHOLDER = re.compile(r"(?i)\b(todo|tbd|placeholder|preencher|a-definir|xxx)\b")


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def walk_strings(obj):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from walk_strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from walk_strings(v)


def check_static(root: str, engine: str) -> list[dict]:
    out: list[dict] = []

    def add(name: str, ok: bool, detail: str = "") -> None:
        out.append({"check": name, "ok": bool(ok), "detail": detail})

    droid_p = os.path.join(root, DROID)
    mod_p = os.path.join(root, MODULES)
    if not os.path.exists(droid_p) or not os.path.exists(mod_p):
        add("arquivos", False, "droidspaces-requirements.json ou module-requirements.json ausente")
        return out
    try:
        d = load(droid_p)
        mods = load(mod_p).get("modules") or []
    except Exception as exc:
        add("json", False, f"JSON inválido: {exc}")
        return out

    add("schema", d.get("schema") == "evox-droidspaces/1", f"schema={d.get('schema')}")
    add("module_id", d.get("module_id") == "M05", f"module_id={d.get('module_id')}")

    # contrato preenchido (nenhum placeholder, hash/url reais)
    bad = [s for s in walk_strings(d) if PLACEHOLDER.search(s)]
    add("sem_placeholder", not bad, f"{len(bad)} campo(s) com TODO/TBD" if bad else "todos preenchidos")

    app = d.get("app") or {}
    apk = app.get("apk") or {}
    add("versao", bool(re.fullmatch(r"v\d+\.\d+\.\d+", str(app.get("version", "")))),
        f"version={app.get('version')}")
    add("data_release", bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(app.get("released_at", "")))),
        f"released_at={app.get('released_at')}")
    add("apk_sha256", bool(HEX64.fullmatch(str(apk.get("sha256", "")))), "hash de 64 hex")
    add("apk_tamanho", int(apk.get("size_bytes") or 0) > 0, f"size={apk.get('size_bytes')}")
    add("apk_https", str(apk.get("url", "")).startswith("https://github.com/"),
        f"url={apk.get('url', '')[:40]}…")

    inst = d.get("install") or {}
    add("ordem_depois_de_M01", "M01" in (inst.get("after") or []), f"after={inst.get('after')}")
    add("ordem_antes_de_M03", "M03" in (inst.get("before") or []), f"before={inst.get('before')}")
    add("fase_F0", inst.get("phase") == "F0", f"phase={inst.get('phase')}")

    ker = d.get("kernel") or {}
    cfgs = ker.get("configs_required") or []
    run = d.get("runtime") or {}
    dec_p0 = os.path.join(root, DECISION)
    dec0 = load(dec_p0) if os.path.exists(dec_p0) else {}
    add("kernel_do_pacote_ou_build",
        (ker.get("source") == dec0.get("kernel_source"))
        and ker.get("custom_kernel_allowed") == dec0.get("custom_kernel_allowed"),
        f"contrato={ker.get('source')}/{ker.get('custom_kernel_allowed')} "
        f"decisão={dec0.get('kernel_source')}/{dec0.get('custom_kernel_allowed')}")

    iso = d.get("isolation") or {}
    iso_cfg = iso.get("required_configs") or []
    iso_ns = iso.get("required_namespaces") or []
    add("isolation_userns_pidns",
        all(c in cfgs for c in ("CONFIG_USER_NS", "CONFIG_PID_NS"))
        and all(n in (run.get("namespaces") or []) for n in ("user", "pid")),
        f"configs={[c for c in ('CONFIG_USER_NS', 'CONFIG_PID_NS') if c in cfgs]} "
        f"namespaces={[n for n in ('user', 'pid') if n in (run.get('namespaces') or [])]} "
        f"(declarado: {iso_cfg} / {iso_ns})")

    add("configs_declaradas", len(cfgs) >= 8 and all(c.startswith("CONFIG_") for c in cfgs),
        f"{len(cfgs)} CONFIG_* exigidas")

    add("namespaces", len(run.get("namespaces") or []) >= 6, f"{run.get('namespaces')}")
    add("proc_checks", all(str(p).startswith("/proc/") for p in (run.get("proc_checks") or [])),
        f"{len(run.get('proc_checks') or [])} caminhos /proc")
    add("paths_absolutos", all(str(p).startswith("/") for p in (run.get("paths") or [])),
        f"{run.get('paths')}")

    cons = d.get("constraints") or {}
    add("r03_mount_hide_desligado", cons.get("mount_hide_global") is False,
        f"mount_hide_global={cons.get('mount_hide_global')}")
    add("selinux_enforcing", cons.get("selinux") == "Enforcing", f"selinux={cons.get('selinux')}")
    add("motor_suportado", engine in (cons.get("supported_engines") or []),
        f"engine={engine} suportados={cons.get('supported_engines')}")
    dec_p = os.path.join(root, DECISION)
    if not os.path.exists(dec_p):
        add("motor_ratificado", False, "root-decision.json ausente — decisão do motor desconhecida")
    else:
        dec = load(dec_p)
        add("motor_ratificado", engine == dec.get("engine") and dec.get("ratified") is True,
            f"decisão {dec.get('decision')} ratificada em {dec.get('decided_at')} fixa "
            f"{dec.get('engine')}; usado={engine}")

    m05 = next((m for m in mods if m.get("id") == "M05"), None)
    add("m05_no_contrato_de_modulos", m05 is not None, "M05 presente em module-requirements.json")
    if m05:
        add("m05_versao_igual_ao_contrato",
            (m05.get("app") or {}).get("version") == app.get("version"),
            f"module-requirements={((m05.get('app') or {}).get('version'))} "
            f"contrato={app.get('version')}")
        add("m05_depends_on_M01", "M01" in (m05.get("depends_on") or []),
            f"depends_on={m05.get('depends_on')}")
        add("m05_exige_root", bool(m05.get("root_required")), f"root_required={m05.get('root_required')}")
        add("m05_kernel_level", bool(m05.get("kernel_level")), f"kernel_level={m05.get('kernel_level')}")
    return out


def check_kernel(root: str, evidence_path: str) -> list[dict]:
    out: list[dict] = []

    def add(name: str, ok: bool, detail: str = "") -> None:
        out.append({"check": name, "ok": bool(ok), "detail": detail})

    droid = load(os.path.join(root, DROID))
    if not os.path.exists(evidence_path):
        add("evidencia_do_kernel", False, f"arquivo ausente: {evidence_path}")
        return out
    try:
        ev = load(evidence_path)
    except Exception as exc:
        add("evidencia_do_kernel", False, f"JSON inválido: {exc}")
        return out
    configs = ev.get("configs")
    if not isinstance(configs, dict) or not configs:
        add("evidencia_do_kernel", False, "sem mapa 'configs' (CONFIG_X: y|n|m)")
        return out
    missing = []
    for cfg in droid["kernel"]["configs_required"]:
        val = str(configs.get(cfg, "n"))
        if val not in ("y", "m"):
            missing.append(f"{cfg}={val}")
    add("kernel_configs", not missing,
        "todas presentes" if not missing else "faltando: " + ", ".join(missing))
    add("kernel_kmi", bool(ev.get("kmi")), f"kmi={ev.get('kmi')}")
    add("kernel_base", str(ev.get("kernel_base", "")).startswith(droid["kernel"]["min_kernel_base"]),
        f"base={ev.get('kernel_base')} mínimo={droid['kernel']['min_kernel_base']}")
    return out


def adb_cmd(adb: str, shell: str) -> tuple[int, str]:
    proc = subprocess.run([adb, "shell", shell], capture_output=True, text=True)
    return proc.returncode, proc.stdout.replace("\r", "").strip()


def check_device(root: str, adb: str, expect_installed: bool) -> list[dict]:
    out: list[dict] = []
    droid = load(os.path.join(root, DROID))

    def add(name: str, ok: bool, detail: str = "") -> None:
        out.append({"check": name, "ok": bool(ok), "detail": detail})

    def run(cmd: str) -> str:
        rc, text = adb_cmd(adb, cmd)
        return text if rc == 0 else ""

    device = run("getprop ro.product.device")
    add("device_pong", device == "pong", f"ro.product.device={device or '(vazio)'}")

    kernel = run("uname -r")
    add("kernel_legivel", bool(kernel), f"uname -r={kernel or '(vazio)'}")

    uid = run("id -u")
    add("root_ativo", uid.strip() == "0", f"id -u={uid or '(vazio)'}")

    enforcing = run("getenforce")
    add("selinux", enforcing == droid["constraints"]["selinux"], f"getenforce={enforcing or '(vazio)'}")

    ns = set(run("ls /proc/self/ns").split())
    missing_ns = [n for n in droid["runtime"]["namespaces"] if n not in ns]
    add("namespaces", not missing_ns,
        "todos presentes" if not missing_ns else "faltando: " + ", ".join(missing_ns))

    proc_missing = []
    for p in droid["runtime"]["proc_checks"]:
        if not run(f"cat {p}"):
            proc_missing.append(p)
    add("procfs_ipc", not proc_missing,
        "sysvipc + posix-mqueue legíveis" if not proc_missing else "ilegível: " + ", ".join(proc_missing))

    if expect_installed:
        path_missing = [p for p in droid["runtime"]["paths"] if not run(f"ls -d {p}")]
        add("runtime_instalado", not path_missing,
            "caminhos presentes" if not path_missing else "faltando: " + ", ".join(path_missing))
        svc = run("ls /data/adb/service.d")
        add("daemon_no_boot", "droidspaces" in svc, f"service.d={svc or '(vazio)'}")
    return out


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = "."
    if "--root" in argv:
        root = argv[argv.index("--root") + 1]
    as_json = "--json" in argv
    if "--engine" in argv:
        engine = argv[argv.index("--engine") + 1]
    else:
        dec_pref = os.path.join(root, DECISION)
        engine = (load(dec_pref).get("engine") if os.path.exists(dec_pref) else "apatch")

    if "--static" in argv:
        checks, label = check_static(root, engine), "static"
    elif "--kernel-evidence" in argv:
        path = argv[argv.index("--kernel-evidence") + 1]
        checks, label = check_kernel(root, path), "kernel"
    elif "--device" in argv:
        adb = argv[argv.index("--adb") + 1] if "--adb" in argv else "adb"
        checks, label = check_device(root, adb, "--expect-installed" in argv), "device"
    else:
        print("Uso: droidspaces_preflight.py {--static|--kernel-evidence F|--device} [--json]",
              file=sys.stderr)
        return 2

    failed = [c for c in checks if not c["ok"]]
    verdict = "PRONTO" if not failed else "PENDENTE"
    payload = {"schema": "evox-droidspaces-preflight/1", "mode": label, "engine": engine,
               "verdict": verdict, "checks": checks,
               "reasons": [f"{c['check']}: {c['detail']}" for c in failed]}
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"[droidspaces] modo={label} → {verdict}")
        for c in checks:
            print(f"  {'OK  ' if c['ok'] else 'FALHA'} {c['check']}: {c['detail']}")
    return 0 if not failed else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
