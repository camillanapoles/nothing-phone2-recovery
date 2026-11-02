#!/usr/bin/env python3
"""root_pair_solver.py — qual par (motor de root × kernel) faz TODAS as condições serem verdadeiras?

Não existe motor "certo", kernel "certo" nem lista de proibidos neste arquivo. O solver:

  1. lê `references/pack-objective.json` (o que se quer: todas as condições verdadeiras, um único par);
  2. lê `references/pack-conditions.json` (as 10 condições, cada uma com regra declarada e um
     contra-exemplo `breaker` obrigatório);
  3. enumera TODOS os pares (motor × candidato de kernel) dos catálogos;
  4. avalia as 10 condições de cada par, com estado `ok` / `falta_prova` / `impossivel`;
  5. devolve determinísticamente: PAR_GARANTIDO (0) · FALTA_PROVA (3) · IMPOSSIVEL (1).

Determinismo: motores e candidatos são ordenados por id, condições na ordem do arquivo, saída JSON com
chaves ordenadas e sem timestamp. Rodar duas vezes no mesmo dado produz bytes idênticos.

Anti-vacuidade (exit 4, entrada inválida):
  - menos condições que `params.min_conditions`  → conjunto vazio/ralo não "passa tudo";
  - id duplicado, regra desconhecida;
  - condição sem `breaker` (não falseável = decoração).

`--selftest` prova a falseabilidade de cada condição: pega um dataset onde um par é PAR_GARANTIDO,
quebra UMA condição por vez com o `breaker` declarado e exige que o par caia por causa EXATAMENTE
daquela condição. Condição decorativa reprova o selftest.

Uso:
  root_pair_solver.py [--root DIR] [--json] [--pairs] [--show]
  root_pair_solver.py --write-decision        # regenera references/root-decision.json (derivado)
  root_pair_solver.py --check-decision        # falha se a decisão no disco divergir do solver
  root_pair_solver.py --selftest             # prova de falseabilidade das 10 condições
  root_pair_solver.py --break C06 [--json]   # aplica o contra-exemplo de uma condição e avalia

Exit: 0 PAR_GARANTIDO · 3 FALTA_PROVA · 1 IMPOSSIVEL · 2 uso · 4 entrada inválida
"""
from __future__ import annotations

import copy
import json
import os
import sys

SK = "skills/evox-rom-ci-optimizer"
FILES = {
    "objective": f"{SK}/references/pack-objective.json",
    "conditions": f"{SK}/references/pack-conditions.json",
    "engines": f"{SK}/references/root-engines.json",
    "candidates": f"{SK}/references/kernel-candidates.json",
    "droid": f"{SK}/references/droidspaces-requirements.json",
    "modules": f"{SK}/references/module-requirements.json",
    "hiding": f"{SK}/references/hiding-stack.json",
}
DECISION = f"{SK}/references/root-decision.json"

OK, PROVA, IMPOSSIVEL = "ok", "falta_prova", "impossivel"
RANK = {OK: 0, PROVA: 1, IMPOSSIVEL: 2}


# ----------------------------------------------------------------------------- dados
def load(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def load_all(root: str, override: dict | None = None) -> dict:
    data = {}
    for k, rel in FILES.items():
        p = os.path.join(root, rel)
        if not os.path.exists(p):
            raise FileNotFoundError(p)
        data[k] = load(p)
    if override:
        data.update(override)
    return data


def norm_patch(s: str) -> str:
    """'001.foo.patch (ou alternativa da pasta)' → '001.foo.patch'."""
    return s.split(" (")[0].strip()


def cfg_name(entry: str) -> str:
    """'CONFIG_KSU=y' → 'CONFIG_KSU'."""
    return entry.split("=")[0].strip()


# ----------------------------------------------------------------------- validação
def validate(data: dict) -> list[str]:
    problems: list[str] = []
    obj = data.get("objective") or {}
    conds = (data.get("conditions") or {}).get("conditions") or []
    minimum = int(((obj.get("params") or {}).get("min_conditions")) or 1)
    if not conds:
        problems.append("conjunto de condições VAZIO — 'tudo verdadeiro' sem condições é vacuidade")
    elif len(conds) < minimum:
        problems.append(f"condições insuficientes: {len(conds)} < min_conditions={minimum}")
    seen: set[str] = set()
    for c in conds:
        cid = c.get("id") or "(sem id)"
        if cid in seen:
            problems.append(f"id duplicado: {cid}")
        seen.add(cid)
        if c.get("rule") not in RULES:
            problems.append(f"{cid}: regra desconhecida {c.get('rule')!r}")
        if not (c.get("breaker") or {}):
            problems.append(f"{cid}: sem contra-exemplo declarado (breaker) — condição não falseável")
    if not (data.get("engines") or {}).get("engines"):
        problems.append("catálogo de motores vazio — não há par a avaliar")
    if not (data.get("candidates") or {}).get("candidates"):
        problems.append("catálogo de kernels vazio — não há par a avaliar")
    return problems


# ------------------------------------------------------------------------- regras
def r_engine_root(ctx: dict, params: dict) -> tuple[bool, str, str]:
    e = ctx["engine"]
    art = e.get("artifact") or {}
    if e.get("status") == "rejected_eol":
        return False, IMPOSSIVEL, f"{e['id']} está EOL"
    if not art.get("version"):
        return False, PROVA, f"{e['id']} sem versão de artefato pinada"
    return True, OK, f"{e['id']} {art.get('version')} pinado ({art.get('released_at', 's/d')})"


def r_kernel_serves_engine(ctx: dict, params: dict) -> tuple[bool, str, str]:
    e, c = ctx["engine"], ctx["candidate"]
    supports = c.get("kernel_supports") or []
    if not e.get("requires_custom_kernel"):
        return True, OK, f"{e['id']} não exige kernel próprio ({c['id']} serve)"
    if e["id"] in supports:
        return True, OK, f"{c['id']} embute {e['id']}"
    return False, PROVA, f"{c['id']} não declara suporte a {e['id']}"


def r_build_match(ctx: dict, params: dict) -> tuple[bool, str, str]:
    c, rom = ctx["candidate"], ctx["rom"]
    builds = c.get("supported_rom_builds") or []
    if rom["build"] in builds and c.get("model") == rom.get("device") and c.get("android_api") == rom.get("android_api"):
        return True, OK, f"{c['id']} declara {rom['build']} ({c.get('kmi', '?')})"
    return False, PROVA, (f"{c['id']} não declara a build {rom['build']} "
                          f"(builds={builds or '[]'}, model={c.get('model')}, api={c.get('android_api')})")


def r_kernel_maintained(ctx: dict, params: dict) -> tuple[bool, str, str]:
    c = ctx["candidate"]
    obj = ctx["objective"]
    limit = int(params.get("max_stale_days")
                or ((obj.get("params") or {}).get("max_stale_days")) or 365)
    if c.get("status") == "rejected_eol":
        return False, IMPOSSIVEL, f"{c['id']} marcado rejected_eol"
    if (c.get("developer_support") or {}).get("declared") is not True:
        return False, PROVA, f"{c['id']} sem suporte declarado pelo autor"
    stale = int(c.get("stale_days") or 0)
    if stale > limit:
        return False, IMPOSSIVEL, f"{c['id']} sem release há {stale} dias (> {limit})"
    return True, OK, f"{c['id']} mantido (último release há {stale} dias)"


def r_droid_engine(ctx: dict, params: dict) -> tuple[bool, str, str]:
    e = ctx["engine"]
    supported = ((ctx["droid"].get("constraints") or {}).get("supported_engines")) or []
    if e["id"] in supported:
        return True, OK, f"DroidSpaces declara suporte a {e['id']}"
    return False, IMPOSSIVEL, f"DroidSpaces não declara suporte a {e['id']} (aceita: {supported or '[]'})"


def r_droid_configs(ctx: dict, params: dict) -> tuple[bool, str, str]:
    c, droid = ctx["candidate"], ctx["droid"]
    required = list((droid.get("kernel") or {}).get("configs_required") or [])
    required += list((droid.get("isolation") or {}).get("required_configs") or [])
    required = sorted(dict.fromkeys(required))
    # só evidência conta: `configs_extra` é intenção de build, não prova
    provided = set(c.get("configs_proven") or [])
    missing = [x for x in required if x not in provided]
    if not missing:
        return True, OK, f"{len(required)} CONFIG_* provadas em {c['id']}"
    abi = set((droid.get("kernel") or {}).get("abi_trio_not_in_stock_gki") or [])
    stock_verdict = (droid.get("kernel") or {}).get("stock_rom_verdict")
    if c.get("origin") == "stock-rom" and stock_verdict == "impossible" and (set(missing) & abi):
        return False, IMPOSSIVEL, (f"{c['id']} (kernel stock) não tem {sorted(set(missing) & abi)} "
                                   f"e stock_rom_verdict={stock_verdict}")
    return False, PROVA, (f"{c['id']} ainda não prova {len(missing)}/{len(required)}: {missing}"
                          if len(missing) < len(required) else
                          f"{c['id']} não prova nenhuma das {len(required)} CONFIG_* exigidas")


def r_kabi_patch(ctx: dict, params: dict) -> tuple[bool, str, str]:
    c, droid = ctx["candidate"], ctx["droid"]
    if not c.get("gki"):
        return True, OK, f"{c['id']} não é GKI — defconfig direto não desloca kABI"
    need = [norm_patch(x) for x in ((droid.get("kernel") or {}).get("patches_required") or [])]
    have = {norm_patch(x) for x in (c.get("patches_present") or [])}
    missing = [x for x in need if x not in have]
    if not missing:
        return True, OK, f"patches de kABI presentes em {c['id']} ({len(need)})"
    return False, PROVA, f"{c['id']} sem {missing} — ligar o trio sem eles dá bootloop"


def r_hiding_available(ctx: dict, params: dict) -> tuple[bool, str, str]:
    e, c = ctx["engine"], ctx["candidate"]
    caps = set(e.get("capabilities") or [])
    if c.get("kernel_supports_susfs"):
        caps.add("susfs")
    need_n = int(params.get("min_layers")
                 or ((ctx["objective"].get("params") or {}).get("min_hiding_layers")) or 1)
    usable, reasons = [], []
    for layer in (ctx["hiding"].get("layers") or []):
        if layer.get("engine_only") and layer["engine_only"] != e["id"]:
            reasons.append(f"{layer['id']}(motor)")
            continue
        miss = [n for n in (layer.get("needs") or []) if n not in caps]
        if miss:
            reasons.append(f"{layer['id']}(falta {miss})")
            continue
        usable.append(layer["id"])
    if len(usable) >= need_n:
        return True, OK, f"camadas utilizáveis: {usable}"
    return False, IMPOSSIVEL, f"nenhuma camada utilizável: {reasons}"


def r_modules_capabilities(ctx: dict, params: dict) -> tuple[bool, str, str]:
    e, c = ctx["engine"], ctx["candidate"]
    caps = set(e.get("capabilities") or [])
    if c.get("kernel_supports_susfs"):
        caps.add("susfs")
    broken = []
    for m in (ctx["modules"].get("modules") or []):
        needs = []
        if m.get("root_required"):
            needs.append("root")
        if m.get("needs_zygisk"):
            needs.append("zygisk")
        if m.get("requires_susfs"):
            needs.append("susfs")
        miss = [n for n in needs if n not in caps]
        if miss:
            broken.append(f"{m['id']}→{miss}")
    if broken:
        return False, IMPOSSIVEL, f"módulos sem capacidade: {broken}"
    return True, OK, f"{(ctx['modules'].get('modules') or []) and len(ctx['modules']['modules'])} módulos atendidos"


def r_rollback_ota(ctx: dict, params: dict) -> tuple[bool, str, str]:
    e, c = ctx["engine"], ctx["candidate"]
    miss = []
    if not (e.get("rollback") or "").strip():
        miss.append(f"rollback de {e['id']}")
    if not (c.get("rollback") or "").strip():
        miss.append(f"rollback de {c['id']}")
    if not (e.get("ota_plan") or "").strip():
        miss.append(f"plano de OTA de {e['id']}")
    if miss:
        return False, PROVA, f"sem {miss}"
    return True, OK, "rollback + plano de OTA declarados para o par"


RULES = {
    "engine_root": r_engine_root,
    "kernel_serves_engine": r_kernel_serves_engine,
    "build_match": r_build_match,
    "kernel_maintained": r_kernel_maintained,
    "droid_engine": r_droid_engine,
    "droid_configs": r_droid_configs,
    "kabi_patch": r_kabi_patch,
    "hiding_available": r_hiding_available,
    "modules_capabilities": r_modules_capabilities,
    "rollback_ota": r_rollback_ota,
}


# ----------------------------------------------------------------------- avaliação
def evaluate_pair(data: dict, engine: dict, cand: dict) -> dict:
    rom = (data["candidates"].get("rom_target") or {})
    ctx = {"engine": engine, "candidate": cand, "rom": rom, "droid": data["droid"],
           "modules": data["modules"], "hiding": data["hiding"], "objective": data["objective"]}
    results = []
    for cond in data["conditions"]["conditions"]:
        fn = RULES[cond["rule"]]
        ok, state, detail = fn(ctx, cond.get("params") or {})
        results.append({"id": cond["id"], "name": cond["name"], "feature": cond.get("feature", ""),
                        "state": state if not ok else OK, "detail": detail})
    worst = max((RANK[r["state"]] for r in results), default=RANK[PROVA])
    verdict = "PAR_GARANTIDO" if worst == RANK[OK] else ("IMPOSSIVEL" if worst == RANK[IMPOSSIVEL] else "FALTA_PROVA")
    return {"engine": engine["id"], "kernel": cand["id"], "origin": cand.get("origin"),
            "verdict": verdict, "failed": [r["id"] for r in results if r["state"] != OK],
            "conditions": results}


def _tied(provable: list[dict]) -> list[dict]:
    """Pares empatados no menor conjunto de pendências — o solver NÃO desempata por preferência."""
    if not provable:
        return []
    low = min(len(p["failed"]) for p in provable)
    low_set = {tuple(p["failed"]) for p in provable if len(p["failed"]) == low}
    if len(low_set) != 1:
        return []
    tied = [p for p in provable if len(p["failed"]) == low]
    return [{"engine": p["engine"], "kernel": p["kernel"], "failed": p["failed"]} for p in tied]


def _best(guaranteed: list[dict], provable: list[dict]) -> dict | None:
    """Só existe 'melhor par' quando há um único par garantido ou um único par no menor empate."""
    if guaranteed:
        return guaranteed[0] if len(guaranteed) == 1 else None
    tied = _tied(provable)
    if len(tied) != 1:
        return None
    return next(p for p in provable if p["engine"] == tied[0]["engine"] and p["kernel"] == tied[0]["kernel"])


def solve(data: dict) -> dict:
    engines = sorted(data["engines"]["engines"], key=lambda e: e["id"])
    cands = sorted(data["candidates"]["candidates"], key=lambda c: c["id"])
    pairs = [evaluate_pair(data, e, c) for e in engines for c in cands]
    guaranteed = [p for p in pairs if p["verdict"] == "PAR_GARANTIDO"]
    provable = [p for p in pairs if p["verdict"] == "FALTA_PROVA"]
    if guaranteed:
        overall, code = "PAR_GARANTIDO", 0
        if len(guaranteed) > 1 and (data["objective"].get("single_method") is True):
            overall, code = "AMBIGUO", 1
    elif provable:
        overall, code = "FALTA_PROVA", 3
    else:
        overall, code = "IMPOSSIVEL", 1
    return {
        "schema": "evox-pack-verdict/1",
        "objective": data["objective"].get("goal"),
        "conditions": [c["id"] for c in data["conditions"]["conditions"]],
        "counts": {"engines": len(engines), "kernels": len(cands), "pairs": len(pairs),
                   "guaranteed": len(guaranteed), "pendente": len(provable)},
        "verdict": overall,
        "exit": code,
        "selected": [{"engine": p["engine"], "kernel": p["kernel"]} for p in guaranteed],
        "best": _best(guaranteed, provable),
        "tied": _tied(provable),
        "pairs": pairs,
    }


# -------------------------------------------------------------------------- breaker
def pointer_get(node, path: str):
    for tok in [t for t in path.split("/") if t != ""]:
        node = node[int(tok)] if isinstance(node, list) else node[tok]
    return node


def apply_breaker(data: dict, breaker: dict) -> dict:
    out = copy.deepcopy(data)
    key = next((k for k, rel in FILES.items() if rel.endswith("/" + breaker["file"])), None)
    if key is None:
        raise KeyError(f"arquivo do breaker desconhecido: {breaker['file']}")
    node = out[key]
    toks = [t for t in breaker["pointer"].split("/") if t != ""]
    parent = pointer_get(node, "/".join(toks[:-1])) if len(toks) > 1 else node
    last = toks[-1]
    action = breaker.get("action", "set")
    if action == "set":
        if isinstance(parent, list):
            parent[int(last)] = breaker["value"]
        else:
            parent[last] = breaker["value"]
    elif action == "remove":
        target = parent[int(last)] if isinstance(parent, list) else parent[last]
        if breaker["value"] in target:
            target.remove(breaker["value"])
    else:
        raise KeyError(f"ação de breaker desconhecida: {action}")
    return out


# -------------------------------------------------------------------------- saída
def render_solve(res: dict) -> None:
    print(f"[pack] {res['verdict']} · {res['counts']['pairs']} pares "
          f"({res['counts']['engines']} motores × {res['counts']['kernels']} kernels) · "
          f"garantidos={res['counts']['guaranteed']} pendentes={res['counts']['pendente']}")
    for p in res["pairs"]:
        mark = {"PAR_GARANTIDO": "OK  ", "FALTA_PROVA": "PEND", "IMPOSSIVEL": "NAO "}[p["verdict"]]
        print(f"  {mark} {p['engine']:10} × {p['kernel']:42} {p['verdict']}"
              + (f"  falta: {','.join(p['failed'])}" if p["failed"] else ""))
    if res.get("best") is None and res["counts"]["guaranteed"] == 0 and res.get("tied"):
        print(f"[pack] EMPATE determinístico em {len(res['tied'])} pares com as mesmas pendências "
              f"{res['tied'][0]['failed']} — nenhum é escolhido por preferência (single_method)")
        for t in res["tied"]:
            print(f"        {t['engine']} × {t['kernel']}")
    if res.get("best"):
        b = res["best"]
        print(f"[pack] melhor par hoje: {b['engine']} × {b['kernel']} — "
              f"condições em aberto: {', '.join(b['failed']) or '(nenhuma)'}")
        for c in b["conditions"]:
            if c["state"] != OK:
                print(f"        {c['id']} {c['name']}: {c['detail']}")


def write_decision(root: str, data: dict, res: dict) -> int:
    dec = {
        "schema": "evox-root-decision/2",
        "generated": True,
        "generated_by": "root_pair_solver.py",
        "derived_from": [FILES["objective"], FILES["conditions"], FILES["engines"],
                         FILES["candidates"], FILES["droid"], FILES["modules"], FILES["hiding"]],
        "note": ("Arquivo DERIVADO. Não se escreve motor nem kernel à mão aqui: o par é consequência "
                 "das 10 condições avaliadas pelo solver. Editar este arquivo à mão quebra "
                 "--check-decision (e a suíte)."),
        "objective": data["objective"].get("goal"),
        "single_method": data["objective"].get("single_method"),
        "verdict": res["verdict"],
        "selected": res["selected"],
        "best": ({"engine": res["best"]["engine"], "kernel": res["best"]["kernel"],
                  "failed": res["best"]["failed"]} if res.get("best") else None),
        "tied": res.get("tied") or [],
        "conditions": {c["id"]: c["name"] for c in data["conditions"]["conditions"]},
        "pairs": [{"engine": p["engine"], "kernel": p["kernel"], "verdict": p["verdict"],
                   "failed": p["failed"]} for p in res["pairs"]],
    }
    p = os.path.join(root, DECISION)
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(dec, fh, indent=1, ensure_ascii=False, sort_keys=True)
        fh.write("\n")
    print(f"[pack] decisão derivada gravada: {p} ({res['verdict']})")
    return 0


def check_decision(root: str, res: dict) -> int:
    p = os.path.join(root, DECISION)
    if not os.path.exists(p):
        print(f"[ERRO] decisão derivada ausente: {p}", file=sys.stderr)
        return 4
    on_disk = load(p)
    if on_disk.get("generated") is not True:
        print("[ERRO] decisão não é derivada do solver — escrita à mão não é permitida", file=sys.stderr)
        return 1
    if on_disk.get("verdict") != res["verdict"]:
        print(f"[ERRO] decisão no disco ({on_disk.get('verdict')}) ≠ solver ({res['verdict']})", file=sys.stderr)
        return 1
    disk_pairs = [(x["engine"], x["kernel"], x["verdict"]) for x in (on_disk.get("pairs") or [])]
    now_pairs = [(x["engine"], x["kernel"], x["verdict"]) for x in res["pairs"]]
    if disk_pairs != now_pairs:
        print("[ERRO] decisão no disco divergiu dos pares avaliados — rodar --write-decision", file=sys.stderr)
        return 1
    print(f"[pack] decisão derivada confere ({len(now_pairs)} pares, veredito {res['verdict']})")
    return 0


def selftest(root: str) -> int:
    data = load_all(root)
    res = solve(data)
    if not res["selected"]:
        print(f"[selftest] dataset {root} não tem par garantido ({res['verdict']}) — "
              "selftest precisa de um pack completo (fixtures)", file=sys.stderr)
        return 3
    base = res["selected"][0]
    print(f"[selftest] par de referência: {base['engine']} × {base['kernel']} (PAR_GARANTIDO)")
    fails = 0
    for cond in data["conditions"]["conditions"]:
        broken = apply_breaker(data, cond["breaker"])
        r = solve(broken)
        hit = next((p for p in r["pairs"]
                    if p["engine"] == base["engine"] and p["kernel"] == base["kernel"]), None)
        if hit is None:
            print(f"  FALHA {cond['id']}: par de referência desapareceu após o breaker")
            fails += 1
            continue
        if hit["failed"] == [cond["id"]]:
            print(f"  OK    {cond['id']} {cond['name'][:52]:52} → cai só por {cond['id']}")
        else:
            print(f"  FALHA {cond['id']}: esperado falhar só {cond['id']}, falhou {hit['failed']}")
            fails += 1
    print(f"[selftest] {len(data['conditions']['conditions'])} condições · {fails} decorativa(s)")
    return 0 if fails == 0 else 1


def main(argv: list[str]) -> int:
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    root = argv[argv.index("--root") + 1] if "--root" in argv else "."
    as_json = "--json" in argv
    try:
        data = load_all(root)
    except FileNotFoundError as exc:
        print(f"[ERRO] arquivo ausente: {exc}", file=sys.stderr)
        return 4
    except Exception as exc:  # JSON inválido
        print(f"[ERRO] JSON inválido: {exc}", file=sys.stderr)
        return 4

    problems = validate(data)
    if problems:
        for p in problems:
            print(f"[ERRO] {p}", file=sys.stderr)
        return 4

    if "--selftest" in argv:
        return selftest(root)

    if "--break" in argv:
        cid = argv[argv.index("--break") + 1]
        cond = next((c for c in data["conditions"]["conditions"] if c["id"] == cid), None)
        if cond is None:
            print(f"[ERRO] condição desconhecida: {cid}", file=sys.stderr)
            return 4
        data = apply_breaker(data, cond["breaker"])
        problems = validate(data)
        if problems:
            for p in problems:
                print(f"[ERRO] após breaker {cid}: {p}", file=sys.stderr)
            return 4

    res = solve(data)
    if "--pairs" in argv:
        print(len(res["pairs"]))
        return res["exit"]
    if "--check-decision" in argv:
        return check_decision(root, res)
    if "--write-decision" in argv:
        write_decision(root, data, res)
        return res["exit"]
    if as_json:
        print(json.dumps(res, indent=2, ensure_ascii=False, sort_keys=True))
    else:
        render_solve(res)
    return res["exit"]


if __name__ == "__main__":
    sys.exit(main(sys.argv))
