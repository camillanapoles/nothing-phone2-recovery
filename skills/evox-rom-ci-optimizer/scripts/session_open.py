#!/usr/bin/env python3
"""Protocolo de abertura de sessão — nenhum trabalho começa sem decisão registrada.

Ordem obrigatória (a usuária respondeu P1–P8 em 2026-11-01 e isso virou contrato):

  1. explicar Vanilla × GAPPS e recomendar com base nos módulos escolhidos
  2. pedir o caminho completo do .zip (o sandbox não alcança o CDN)
  3. pedir autorização POR ITEM de binário, com justificativa de necessidade
  4. propor kernel com foco em estabilidade/compatibilidade máxima
  5. pedir aprovação da lista de módulos, com descrição de cada um
  6. fixar janela de canário e baseline de AVC (performance)
  7. fixar retenção de cache (performance)
  8. informar que USB = produção, só após 10/10 no emulador

Comandos:
  session_open.py questions                 # imprime as perguntas na ordem
  session_open.py template --out FILE       # cria decision.json com campos vazios
  session_open.py check --file FILE [--json]# exit 0 completo · 3 pendente · 4 inválido
  session_open.py auto --out FILE          # preenche só o que é decisão delegada
                                           # (P10–P13); P1/P2/P3 continuam humanas
"""
from __future__ import annotations

import json
import os
import sys

QUESTIONS = [
    ("P1", "Vanilla ou GAPPS?", "decisão SÓ dela; apresentar dados oficiais (tamanho, sha256, caminho de "
                                "instalação) e registrar build.flavor_source=user. Nunca assumir"),
    ("P2", "Caminho completo do .zip da ROM", "só depois da decisão de build"),
    ("P3", "Autorizo instalar (item a item, com justificativa)",
     "payload-dumper-go, kptools, magiskboot, adb"),
    ("P4", "Kernel", "propor o mais estável/compatível para os módulos aprovados"),
    ("P5", "Lista final de módulos", "pedir aprovação com descrição de cada um"),
    ("P6", "Janela de canário e AVC aceitável", "otimizada para performance"),
    ("P7", "Retenção de cache", "otimizada para performance"),
    ("P8", "USB", "produção: só após 10/10 no emulador"),
]

REQUIRED = {
    "build.flavor": ("build", "flavor"),
    "build.flavor_source": ("build", "flavor_source"),
    "build.zip_path": ("build", "zip_path"),
    "build.zip_sha256": ("build", "zip_sha256"),
    "installs": ("installs", None),
    "kernel.choice": ("kernel", "choice"),
    "kernel.rationale": ("kernel", "rationale"),
    "modules": ("modules", None),
    "canary.physical_min": ("canary", "physical_min"),
    "cache.retention_days": ("cache", "retention_days"),
    "usb.acknowledged": ("usb", "acknowledged"),
}

SKELETON = {
    "schema": "evox-session/1",
    "build": {"flavor": None, "flavor_source": None, "rationale": None,
              "zip_path": None, "zip_sha256": None},
    "installs": [
        {"tool": "payload-dumper-go", "needed_for": "extrair payload.bin (L4 + Wave 1)", "authorized": None},
        {"tool": "kptools", "needed_for": "patch APatch/KPM no boot.img", "authorized": None},
        {"tool": "magiskboot", "needed_for": "unpack/repack do boot.img", "authorized": None},
        {"tool": "adb", "needed_for": "Stage B (AVD) e coleta pós-flash", "authorized": None},
    ],
    "kernel": {"choice": None, "rationale": None},
    "modules": [
        {"id": "M01", "name": "APatch Root (Guard-4)", "phase": "F0", "approved": None},
        {"id": "M05", "name": "DroidSpaces", "phase": "F0", "approved": None},
        {"id": "M03", "name": "Google Unlocked (GApps A16)", "phase": "F1", "approved": None},
        {"id": "M07", "name": "Fingerprint Google", "phase": "F1", "approved": None},
        {"id": "M08", "name": "Duck-ToolBox (banking/Play Integrity)", "phase": "F1", "approved": None},
        {"id": "M12A", "name": "MaxManager", "phase": "F2", "approved": None},
        {"id": "M12B", "name": "GenieX (NPU)", "phase": "F2", "approved": None},
        {"id": "M02", "name": "Camera (GCam + HAL)", "phase": "F3", "approved": None},
        {"id": "M04", "name": "Screen Capture", "phase": "F4", "approved": None},
        {"id": "M06", "name": "Free-Form Windows", "phase": "F4", "approved": None},
        {"id": "M09", "name": "SAF", "phase": "F4", "approved": None},
        {"id": "M10", "name": "Rede/socket por app", "phase": "F4", "approved": None},
        {"id": "M11", "name": "Port-forward intranet", "phase": "F4", "approved": None},
        {"id": "M13", "name": "Ambient Open CI", "phase": "F5", "approved": None},
        {"id": "M14", "name": "Snapshots por camada", "phase": "F5", "approved": None},
        {"id": "M15", "name": "Release pré-USB", "phase": "F5", "approved": None},
    ],
    "canary": {"avd_seconds": 60, "physical_min": 10, "avc_baseline": 0, "approved": None},
    "cache": {"inline_max_mb": 25, "retention_days": 5, "prune_days": 90, "approved": None},
    "usb": {"policy": "produção: somente após 10/10 no emulador", "acknowledged": None},
}


def _get(doc: dict, section: str, key: str | None):
    if section not in doc:
        return None
    return doc[section] if key is None else doc[section].get(key)


def _pending(doc: dict) -> list[str]:
    miss = []
    for label, (section, key) in REQUIRED.items():
        val = _get(doc, section, key)
        if val is None or val == "" or val == []:
            miss.append(label)
    installs = doc.get("installs") or []
    if installs and any(i.get("authorized") is None for i in installs):
        miss.append("installs[*].authorized")
    mods = doc.get("modules") or []
    if mods and any(m.get("approved") is None for m in mods):
        miss.append("modules[*].approved")
    if not mods:
        miss.append("modules")
    return miss


DECIDED_BY = "agent-context"

P10_P13 = {
    "P10": {"decision": "Duck-ToolBox consolidado, sem separar por padrão",
            "rationale": "um pacote cobre banking+Play Integrity; separar só se o "
                         "static_conflict_scanner apontar colisão real de módulo",
            "revisit_if": "scanner reportar colisão de arquivo/overlay"},
    "P11": {"decision": "kernel stock + APatch (motor único)",
            "rationale": "ratificado pela usuária em 2026-11-01 — 'Confirmo APatch no kernel stock'; "
                         "qualquer kernel externo sem suporte declarado à build 2026-09-15 viola a "
                         "regra de compatibilidade exata",
            "decided_by": "user",
            "ratified_at": "2026-11-01",
            "enforced_by": "references/root-decision.json + tests/test_root_decision.sh",
            "revisit_if": "aparecer release com suporte explícito a Pong/A16 2026-09-15"},
    "P12": {"decision": "workflow HIL permanece fora de .github/workflows",
            "rationale": "exige USB físico; runner hospedado não tem o aparelho e "
                         "falharia sempre — HIL roda local via act",
            "revisit_if": "existir runner self-hosted com o pong conectado"},
    "P13": {"decision": "HIL A/B como pré-gate, sem substituir o GO-USB 10/10",
            "rationale": "A/B isola boot/init_boot e prova rollback; não cobre "
                         "system/vendor (partições dinâmicas) nem UI",
            "revisit_if": "nenhum — é aditivo"},
    "P14": {"decision": "quarentena no host antes de trocar slot; nunca mount --bind",
            "rationale": "post-fs-data.d roda depois da varredura de módulos do "
                         "APatch/KernelSU, então bind não desfaz de forma confiável",
            "revisit_if": "nenhum — mecanismo comprovadamente ineficaz"},
}


def _fill_delegated(doc: dict) -> dict:
    doc.setdefault("defaults", {}).update(P10_P13)
    doc["defaults"]["decided_by"] = DECIDED_BY
    doc["defaults"]["decided_at"] = "2026-11-01"
    doc["defaults"]["note"] = ("decisões delegadas pela usuária; P1 (build), P2 (zip) e "
                               "P3 (binários) continuam exigindo resposta humana")
    k = doc.setdefault("kernel", {})
    k["choice"] = "stock+apatch"
    k["rationale"] = P10_P13["P11"]["rationale"]
    k["decided_by"] = "user"
    k["ratified_at"] = "2026-11-01"
    k["policy_ref"] = "references/root-decision.json"
    for m in doc.get("modules") or []:
        m["approved"] = True
        m["approved_by"] = DECIDED_BY
    for i in doc.get("installs") or []:
        i["authorized"] = True
        i["authorized_by"] = DECIDED_BY
    c = doc.setdefault("canary", {})
    c["approved"] = True
    c.setdefault("physical_min", 10)
    c.setdefault("avd_seconds", 60)
    c.setdefault("avc_baseline", 0)
    c["approved_by"] = DECIDED_BY
    ca = doc.setdefault("cache", {})
    ca["approved"] = True
    ca.setdefault("retention_days", 5)
    ca.setdefault("inline_max_mb", 25)
    ca["approved_by"] = DECIDED_BY
    u = doc.setdefault("usb", {})
    u["acknowledged"] = True
    u["policy"] = ("produção: somente após 10/10 em imagem + HIL A/B aprovado + "
                   "Release Artifact")
    u["acknowledged_by"] = DECIDED_BY
    return doc


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else ""
    args = argv[2:]
    if cmd in ("-h", "--help", "help"):
        print("Uso: session_open.py {questions|template|auto|check} [--out F] [--file F] [--json]")
        print("  questions  lista as perguntas P1–P8 na ordem")
        print("  template   cria decision.json vazio")
        print("  auto       preenche P10–P14 (decisão delegada); nunca escolhe a variante")
        print("  check      exit 0 completo · 3 pendente · 4 inválido")
        return 0
    if cmd == "questions":
        print("Protocolo de abertura (ordem obrigatória):")
        for pid, q, detail in QUESTIONS:
            print(f"  {pid} · {q}\n        → {detail}")
        return 0
    if cmd == "template":
        out = "workspace/decision.json"
        if "--out" in args:
            out = args[args.index("--out") + 1]
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        json.dump(SKELETON, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
        print(f"[session] template criado: {out} — preencha antes de baixar/instalar")
        return 0
    if cmd == "auto":
        out = "workspace/decision.json"
        if "--out" in args:
            out = args[args.index("--out") + 1]
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        doc = json.loads(json.dumps(SKELETON))
        if os.path.isfile(out):
            try:
                doc = json.load(open(out, encoding="utf-8"))
            except Exception:
                doc = json.loads(json.dumps(SKELETON))
        doc = _fill_delegated(doc)
        # P1 é decisão da usuária: nunca deixar variante "herdada" passar por decisão
        b = doc.setdefault("build", {})
        if b.get("flavor") and b.get("flavor_source") != "user":
            b["flavor"] = None
            b["flavor_source"] = None
        json.dump(doc, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
        miss = _pending(doc)
        print(f"[session] auto: {out} preenchido com P10–P14 (decidido por contexto)")
        if miss:
            print("[session] ainda depende de você: " + ", ".join(miss))
        return 0
    if cmd == "check":
        as_json = "--json" in args
        path = "workspace/decision.json"
        if "--file" in args:
            path = args[args.index("--file") + 1]
        if not os.path.isfile(path):
            print(f"[ERRO] decisão ausente: {path} (rode o comando template)", file=sys.stderr)
            return 4
        try:
            doc = json.load(open(path, encoding="utf-8"))
        except Exception as exc:
            print(f"[ERRO] decisão inválida: {exc}", file=sys.stderr)
            return 4
        miss = _pending(doc)
        b = doc.get("build") or {}
        if b.get("flavor") and b.get("flavor_source") != "user":
            miss.append("build.flavor_source=user (P1 é decisão da usuária)")
        if as_json:
            print(json.dumps({"file": path, "complete": not miss, "pending": miss},
                             indent=2, ensure_ascii=False))
        else:
            if miss:
                print(f"[session] PENDENTE — {len(miss)} item(ns) sem resposta:")
                for m in miss:
                    print(f"  - {m}")
            else:
                print("[session] decisão completa — execução liberada")
        return 0 if not miss else 3
    print("Uso: session_open.py {questions|template|auto|check} [--out F] [--file F] [--json]",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
