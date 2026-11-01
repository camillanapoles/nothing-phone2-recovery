#!/usr/bin/env python3
"""
validate_skills.py - validador do HARNESS de skills do repositorio.

Nao valida conteudo doutrinario; valida o CONTRATO que faz um agente encontrar e
carregar a skill sem alucinar caminho:

  1. existe `SKILL.md` em cada diretorio de skill
  2. front matter YAML com `name` + `description`
  3. `name` == nome do diretorio (descoberta deterministica)
  4. `description` >= 40 caracteres (gatilho utilizavel) e <= 1024
  5. nomes unicos no ecossistema
  6. links relativos markdown resolvem para arquivo existente
  7. caminhos citados em backticks (`scripts/x.sh`, `references/y.md`) existem
  8. scripts em `scripts/` sao executaveis
  9. sem segredos obvios (token PAT, chave privada, AKIA)
 10. `registry.json` cobre exatamente os diretorios instalados
 11. `SKILL.md` <= 64 KB (contrato de runtime, nao livro)

Uso:  python3 tools/validate_skills.py [--root .] [--json]
Exit: 0 = OK | 1 = violacoes
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

SKILLS_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRONT_MATTER = re.compile(r"^---\n(.*?)\n---\n", re.S)
LINK = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
BACKTICK_PATH = re.compile(r"`((?:scripts|references|assets|tests)/[A-Za-z0-9_./-]+)`")
SECRETS = [
    (re.compile(r"ghp_[A-Za-z0-9]{20,}"), "GitHub classic PAT"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{20,}"), "GitHub fine-grained PAT"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS access key"),
    (re.compile(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"), "private key block"),
]
SKIP_DIRS = {"tools", "node_modules", "__pycache__", ".git"}


def parse_front_matter(texto: str) -> dict:
    match = FRONT_MATTER.match(texto)
    if not match:
        return {}
    data: dict[str, str] = {}
    key = None
    for raw in match.group(1).splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if re.match(r"^[A-Za-z0-9_-]+:\s*$", raw):
            key = raw.split(":")[0].strip()
            data[key] = ""
            continue
        if re.match(r"^[A-Za-z0-9_-]+:", raw):
            key, _, value = raw.partition(":")
            key = key.strip()
            data[key] = value.strip().strip(">|").strip()
            continue
        if key and raw.startswith((" ", "\t")):
            data[key] = (data.get(key, "") + " " + raw.strip()).strip()
    return data


def validate(root: str) -> dict:
    violations: list[dict] = []
    infos: list[dict] = []

    def add(level: str, skill: str, rule: str, detail: str):
        (violations if level == "FAIL" else infos).append(
            {"skill": skill, "rule": rule, "detail": detail}
        )

    dirs = sorted(
        d
        for d in os.listdir(root)
        if os.path.isdir(os.path.join(root, d)) and d not in SKIP_DIRS and not d.startswith(".")
    )

    names: dict[str, str] = {}
    for skill in dirs:
        skill_dir = os.path.join(root, skill)
        skill_md = os.path.join(skill_dir, "SKILL.md")
        if not os.path.isfile(skill_md):
            add("FAIL", skill, "SKILL_MD_MISSING", "diretorio de skill sem SKILL.md")
            continue

        texto = open(skill_md, encoding="utf-8", errors="ignore").read()
        size = len(texto.encode("utf-8"))
        if size > 65_536:
            add("FAIL", skill, "SKILL_MD_TOO_LARGE", f"{size} B > 65536 B (mova detalhe para references/)")

        fm = parse_front_matter(texto)
        for field in ("name", "description"):
            if not fm.get(field):
                add("FAIL", skill, "FRONT_MATTER_MISSING", f"campo obrigatorio ausente: {field}")
        if fm.get("name") and fm["name"] != skill:
            add("FAIL", skill, "NAME_DIR_MISMATCH", f"name='{fm['name']}' != dir='{skill}'")
        desc = fm.get("description", "")
        if desc and len(desc) < 40:
            add("FAIL", skill, "DESCRIPTION_TOO_SHORT", f"{len(desc)} chars (min 40)")
        if len(desc) > 1024:
            add("FAIL", skill, "DESCRIPTION_TOO_LONG", f"{len(desc)} chars (max 1024)")
        if fm.get("name"):
            if fm["name"] in names:
                add("FAIL", skill, "DUPLICATE_NAME", f"ja definido por {names[fm['name']]}")
            names[fm["name"]] = skill

        # 6. links relativos
        for target in LINK.findall(texto):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            clean = target.split("#")[0]
            if not clean:
                continue
            if not os.path.exists(os.path.join(skill_dir, clean)):
                add("FAIL", skill, "BROKEN_LINK", f"link nao resolve: {clean}")

        # 7. caminhos citados em backticks
        for rel in set(BACKTICK_PATH.findall(texto)):
            if not os.path.exists(os.path.join(skill_dir, rel)):
                add("FAIL", skill, "DANGLING_REFERENCE", f"caminho citado inexistente: {rel}")

        # 8. executaveis
        scripts_dir = os.path.join(skill_dir, "scripts")
        if os.path.isdir(scripts_dir):
            for f in sorted(os.listdir(scripts_dir)):
                full = os.path.join(scripts_dir, f)
                if f.endswith((".sh", ".py")) and not os.access(full, os.X_OK):
                    add("WARN", skill, "SCRIPT_NOT_EXECUTABLE", f"chmod +x scripts/{f}")

        # 9. segredos
        for path, _, files in os.walk(skill_dir):
            if "__pycache__" in path:
                continue
            for f in files:
                full = os.path.join(path, f)
                try:
                    blob = open(full, encoding="utf-8", errors="ignore").read()
                except OSError:
                    continue
                for pattern, label in SECRETS:
                    if pattern.search(blob):
                        add("FAIL", skill, "SECRET_LEAK", f"{label} em {os.path.relpath(full, root)}")

        counts = {
            ext: len([f for _, _, fs in os.walk(skill_dir) for f in fs if f.endswith(ext)])
            for ext in (".md", ".sh", ".py", ".json", ".yml")
        }
        add("INFO", skill, "SUMMARY", f"{size} B SKILL.md · {counts}")

    # 10. registry
    registry_path = os.path.join(root, "registry.json")
    if os.path.isfile(registry_path):
        try:
            registry = json.load(open(registry_path, encoding="utf-8"))
            declared = {s["name"] for s in registry.get("skills", [])}
            installed = set(names)
            for missing in sorted(installed - declared):
                add("FAIL", missing, "REGISTRY_MISSING", "skill instalada ausente no registry.json")
            for extra in sorted(declared - installed):
                add("FAIL", extra, "REGISTRY_ORPHAN", "registry.json aponta skill inexistente")
        except json.JSONDecodeError as exc:
            add("FAIL", "registry.json", "REGISTRY_INVALID", str(exc))
    else:
        add("WARN", "registry.json", "REGISTRY_ABSENT", "sem registry.json (descoberta fica ad-hoc)")

    return {
        "root": root,
        "skills": sorted(names),
        "failures": violations,
        "warnings": infos,
        "ok": not violations,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validador do harness de skills")
    parser.add_argument("--root", default=SKILLS_ROOT)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    report = validate(os.path.abspath(args.root))
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    elif not args.quiet:
        print(f"[harness] root={report['root']} skills={len(report['skills'])}")
        for item in report["failures"]:
            print(f"  FAIL {item['skill']:<32} {item['rule']}: {item['detail']}")
        for item in report["warnings"]:
            if item["rule"] != "SUMMARY":
                print(f"  WARN {item['skill']:<32} {item['rule']}: {item['detail']}")
        print(f"[harness] {'OK' if report['ok'] else 'VIOLACOES ENCONTRADAS'} "
              f"({len(report['failures'])} falhas)")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
