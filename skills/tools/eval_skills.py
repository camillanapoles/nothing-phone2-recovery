#!/usr/bin/env python3
"""
eval_skills.py - harness de AVALIACAO das skills (lacuna L5).

Diferente de `validate_skills.py` (que checa contrato mecânico), este avalia
QUALIDADE em eixos falseáveis — um eixo só pontua se houver marcador verificável
no artefato (texto, tabela de gate, script, teste). Postura epistêmica:
`skills/sci-scientific-mindset` (nada de "parece bom"; cada nota tem evidência).

Eixos (0-3 cada) e o que conta como evidência:
  E1 evidência      hash/sha256/manifesto/logget/'PASS se'/'PASS'  no SKILL/refs
  E2 reversibilidade rollback|backup|restore|guard-4|watchdog
  E3 testabilidade  tests/ presente + teste citado + critério PASS/FAIL
  E4 custo          timeout|concurrency|idle|poweroff|custo
  E5 handoff        cita outras skills / 'handoff' / composição / registry
  E6 executabilidade scripts/ ou alvos make (não só doutrina)
  E7 falseabilidade 'NUNCA'/'anti-identidade'/'FAIL se'/'gatilho' na descrição

Score = soma ponderada normalizada 0-100.

Duas classes de skill (detectadas pelo artefato, não declaradas):
  executable  -> tem scripts/ ou tests/
  doctrine    -> só contrato em texto
Para `doctrine`, o eixo E6 (executabilidade) NÃO é cobrado: o peso é redistribuído.
Penalizar doutrina por não ter script seria erro de métrica, não achado de qualidade.

Limite por classe + tier (registry.json):
  executable: core >= 70 | meta >= 55 | support >= 55
  doctrine:   core >= 60 | meta >= 50 | support >= 45

Uso:
  python3 tools/eval_skills.py [--json] [--fail-under N] [--thresholds]

Exit: 0 = todas >= limite | 1 = alguma abaixo | 2 = erro
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIER_MIN = {
    "executable": {"core": 70, "meta": 55, "support": 55, "*": 55},
    "doctrine": {"core": 60, "meta": 50, "support": 45, "*": 45},
}
WEIGHTS = {
    "executable": {"E1": 1.15, "E2": 1.15, "E3": 1.2, "E4": 0.8, "E5": 0.9, "E6": 1.1, "E7": 1.0},
    "doctrine": {"E1": 1.15, "E2": 1.15, "E3": 1.0, "E4": 0.9, "E5": 1.2, "E7": 1.2},
}

PATTERNS = {
    "E1": [
        r"sha-?256", r"hash", r"manifesto", r"evid[eê]ncia", r"\bPASS\b", r"logcat|dmesg",
    ],
    "E2": [
        r"rollback", r"backup", r"restore", r"guard-?4", r"watchdog", r"revers",
        r"revog\w*|revoke", r"revert", r"cancel", r"confirma[cç][aã]o",
    ],
    "E3": [
        r"\bPASS se\b", r"\bFAIL se\b", r"teste[s]? bin[aá]rio", r"gates?", r"make test",
    ],
    "E4": [
        r"timeout-minutes|timeout \d+", r"cancel-in-progress", r"poweroff|idle", r"custo",
    ],
    "E5": [
        r"handoff", r"composi[cç][aã]o", r"depende de|depends_on", r"skill[s]? `[a-z0-9-]+`",
    ],
    "E6": [
        r"scripts/", r"`make ", r"install_local", r"entrypoint",
    ],
    "E7": [
        r"\bNUNCA\b", r"anti-?identidade", r"anti-?padr[aã]o", r"quando usar|when to use",
        r"viola[cç][aã]o",
    ],
}


def load_registry() -> dict:
    path = os.path.join(ROOT, "registry.json")
    if not os.path.isfile(path):
        return {"skills": []}
    return json.load(open(path, encoding="utf-8"))


def skill_dirs() -> list[str]:
    skip = {"tools", "node_modules", "__pycache__", ".git", "tests"}
    return sorted(
        d for d in os.listdir(ROOT)
        if os.path.isdir(os.path.join(ROOT, d)) and d not in skip and not d.startswith(".")
    )


def corpus(skill_dir: str) -> tuple[str, dict]:
    """texto agregado (SKILL.md + references/*.md) e fatos estruturais"""
    parts = []
    skill_md = os.path.join(skill_dir, "SKILL.md")
    if os.path.isfile(skill_md):
        parts.append(open(skill_md, encoding="utf-8", errors="ignore").read())
    refs_dir = os.path.join(skill_dir, "references")
    refs = []
    if os.path.isdir(refs_dir):
        for name in sorted(os.listdir(refs_dir)):
            full = os.path.join(refs_dir, name)
            if os.path.isfile(full) and name.endswith((".md", ".yml", ".json")):
                refs.append(name)
                if name.endswith(".md"):
                    parts.append(open(full, encoding="utf-8", errors="ignore").read())
    facts = {
        "has_scripts": os.path.isdir(os.path.join(skill_dir, "scripts")),
        "has_tests": os.path.isdir(os.path.join(skill_dir, "tests")),
        "scripts": [],
        "tests": [],
        "refs": refs,
    }
    for kind in ("scripts", "tests"):
        d = os.path.join(skill_dir, kind)
        if os.path.isdir(d):
            facts[kind] = sorted(
                f for f in os.listdir(d) if f.endswith((".sh", ".py")) and not f.startswith(".")
            )
    return "\n".join(parts), facts


def score_axis(text: str, hits: list[str], facts: dict, axis: str) -> tuple[int, list[str]]:
    matched = []
    for pattern in PATTERNS[axis]:
        m = re.search(pattern, text, re.I)
        if m:
            matched.append(m.group(0)[:40])
    if axis == "E3":
        if facts["has_tests"] and facts["tests"]:
            matched.append(f"tests/ ({len(facts['tests'])})")
        elif not facts["has_tests"]:
            # doutrina pura não zera, mas teto é 1
            return (1 if matched else 0), matched
    if axis == "E6":
        if facts["has_scripts"] and facts["scripts"]:
            matched.append(f"scripts/ ({len(facts['scripts'])})")
        elif not matched:
            return 0, matched
    points = min(3, len(set(matched)))
    return points, sorted(set(matched))[:4]


def evaluate() -> dict:
    registry = load_registry()
    tiers = {s["name"]: s.get("tier", "*") for s in registry.get("skills", [])}
    results = []
    for name in skill_dirs():
        skill_dir = os.path.join(ROOT, name)
        text, facts = corpus(skill_dir)
        if not text.strip():
            continue
        klass = "executable" if (facts["has_scripts"] or facts["has_tests"]) else "doctrine"
        weights = WEIGHTS[klass]
        axes = {}
        total_weight = 0.0
        weighted = 0.0
        for axis, weight in weights.items():
            points, evidence = score_axis(text, [], facts, axis)
            axes[axis] = {"points": points, "max": 3, "evidence": evidence}
            weighted += (points / 3) * weight
            total_weight += weight
        score = round(100 * weighted / total_weight)
        tier = tiers.get(name, "*")
        minimum = TIER_MIN[klass].get(tier, TIER_MIN[klass]["*"])
        results.append(
            {
                "skill": name,
                "tier": tier,
                "class": klass,
                "score": score,
                "min_required": minimum,
                "pass": score >= minimum,
                "axes": axes,
                "facts": {
                    "scripts": len(facts["scripts"]),
                    "tests": len(facts["tests"]),
                    "references": len(facts["refs"]),
                },
            }
        )
    return {"root": ROOT, "thresholds": TIER_MIN, "results": results}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Avaliação de qualidade das skills (eixos falseáveis)")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--fail-under", type=int, default=None,
                        help="limite global (sobrepõe o limite por tier)")
    parser.add_argument("--thresholds", action="store_true", help="imprime os limites e sai")
    args = parser.parse_args(argv)

    if args.thresholds:
        print(json.dumps(TIER_MIN, indent=2, ensure_ascii=False))
        return 0

    report = evaluate()
    failed = []
    for item in report["results"]:
        effective_min = args.fail_under if args.fail_under is not None else item["min_required"]
        item["effective_min"] = effective_min
        item["pass"] = item["score"] >= effective_min
        if not item["pass"]:
            failed.append(item)

    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print(f"[eval] {len(report['results'])} skills · eixos E1..E7 · limite por classe+tier")
        print(f"{'':<4}{'skill':<31}{'classe':<12}{'tier':<9}{'score':>6}{'min':>5}  eixos")
        for item in report["results"]:
            axes = " ".join(f"{k[1]}={v['points']}" for k, v in item["axes"].items())
            flag = "OK " if item["pass"] else "LOW"
            print(f"{flag} {item['skill']:<31}{item['class']:<12}{item['tier']:<9}"
                  f"{item['score']:>6}{item['effective_min']:>5}  {axes}")
        print(f"[eval] {'APROVADO' if not failed else 'REPROVADO'} "
              f"({len(failed)} abaixo do limite)")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
