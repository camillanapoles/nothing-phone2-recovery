import re

p = "skills/evox-rom-ci-optimizer/scripts/success_guarantee.py"
s = open(p, encoding="utf-8").read()

s = s.replace('''Avalia as cinco solicitações da usuária sob a Decisão A e devolve, uma a uma:

  R1 motor único            APatch, exclusivo, ratificado
  R2 root oculto            pilha de ocultação (APatch + Zygisk Next + Zygisk Assistant)
  R3 integridade/fingerprint Tricky Store + PIFork sem spoofers concorrentes
  R4 zero conflito          varredura estática dos módulos reais
  R5 DroidSpaces oficial    instalação conforme doc do app + kernel com as CONFIG_*

Estados: PROVADO · FALTA_PROVA · IMPOSSIVEL (a Decisão A impede e não há prova que resolva).''',
'''Avalia as cinco solicitações da usuária contra o PAR (motor × kernel) e devolve, uma a uma:

  R1 par único do pack      existe exatamente 1 par que fecha as 10 condições (root_pair_solver.py)
  R2 root oculto            camada de ocultação utilizável pelo par + medição por app
  R3 integridade/fingerprint Tricky Store + PIFork sem spoofers concorrentes
  R4 zero conflito          varredura estática dos módulos reais
  R5 DroidSpaces oficial    instalação conforme doc do app + kernel com as CONFIG_* e os patches

Estados: PROVADO · FALTA_PROVA · IMPOSSIVEL (nenhum par consegue, nem com prova nova).''')

s = s.replace('''import json
import os
import sys
''', '''import importlib.util
import json
import os
import sys
''')

s = s.replace('''SK = "skills/evox-rom-ci-optimizer"''',
'''SK = "skills/evox-rom-ci-optimizer"
HERE = os.path.dirname(os.path.abspath(__file__))


def load_pack(root: str):
    """Roda o solver do pack (mesmas 10 condições do gate). Ausente/quebrado → None."""
    try:
        spec = importlib.util.spec_from_file_location(
            "root_pair_solver", os.path.join(HERE, "root_pair_solver.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        data = mod.load_all(root)
        if mod.validate(data):
            return None, None
        return mod, mod.solve(data)
    except Exception:
        return None, None


def c06_states(pack: dict) -> set:
    if not pack:
        return set()
    return {c["state"] for p in pack.get("pairs") or []
            for c in p["conditions"] if c["id"] == "C06"}''')

old_r1 = '''    # R1 — motor único
    allow = [e["id"] for e in eng.get("engines") or [] if e.get("allowed")]
    if dec.get("ratified") is True and allow == [dec.get("engine")] and dec.get("engine"):
        add("R1", "motor único ratificado", "PROVADO",
            f"decisão {dec.get('decision')} ratificada; único motor permitido={allow[0]}")
    else:
        add("R1", "motor único ratificado", "FALTA_PROVA",
            f"motores permitidos={allow} decisão={dec.get('engine')}",
            "root_engine_gate.py --engine apatch → exit 0")'''

new_r1 = '''    # R1 — par único que fecha as 10 condições (sem motor preferido no código)
    if pack is None:
        add("R1", "par único do pack", "FALTA_PROVA",
            "solver do pack indisponível/ inválido (pack-conditions.json, catálogos)",
            "root_pair_solver.py --root . → 0 (PAR_GARANTIDO)")
    elif pack.get("verdict") == "PAR_GARANTIDO" and len(pack.get("selected") or []) == 1:
        sel = pack["selected"][0]
        add("R1", "par único do pack", "PROVADO",
            f"1 par fecha as 10 condições: {sel['engine']} × {sel['kernel']}")
    elif pack.get("verdict") == "AMBIGUO":
        add("R1", "par único do pack", "FALTA_PROVA",
            f"{len(pack.get('selected') or [])} pares fecham as 10 condições — single_method exige 1",
            "registrar critério de desempate no pack-objective.json (ou reduzir o catálogo)")
    elif pack.get("verdict") == "IMPOSSIVEL":
        add("R1", "par único do pack", "IMPOSSIVEL",
            "nenhum par do catálogo consegue fechar as 10 condições",
            "mudar o dado (novo motor/kernel/evidência) — não o texto da decisão")
    else:
        best = pack.get("best")
        who = f"{best['engine']} × {best['kernel']}" if best else "empate sem escolha"
        falta = ",".join(best["failed"]) if best else "ver pack"
        add("R1", "par único do pack", "FALTA_PROVA",
            f"nenhum par fecha as 10 ainda; melhor={who}; aberto={falta}",
            "root_pair_solver.py --root . (detalha por condição) e fechar o que falta")'''

assert old_r1 in s
s = s.replace(old_r1, new_r1)

old_r5 = '''    elif cfgs and lacking:
        hard = [c for c in lacking if c in ((iso.get("required_configs") or []) + abi_trio)]
        if dec.get("kernel_source") == "stock-rom":
            add("R5", "DroidSpaces conforme doc oficial", "IMPOSSIVEL",
                f"kernel stock sem {hard} e decisão {dec.get('decision')} não permite kernel compilado",
                "só resolve com nova decisão sua (revisar custom_kernel_allowed) — não com código")
        else:'''

new_r5 = '''    elif cfgs and lacking:
        hard = [c for c in lacking if c in ((iso.get("required_configs") or []) + abi_trio)]
        estados = c06_states(pack)
        if hard and estados == {"impossivel"}:
            add("R5", "DroidSpaces conforme doc oficial", "IMPOSSIVEL",
                f"nenhum kernel do catálogo consegue {hard} (C06 impossível em todos os pares)",
                "mudar o dado: kernel candidato com as CONFIG_* (não o texto da decisão)")
        else:'''

assert old_r5 in s
s = s.replace(old_r5, new_r5)

# pack precisa existir antes das regras
s = s.replace('''    dev = ev.get("device") or {}''',
'''    _, pack = load_pack(root)

    dev = ev.get("device") or {}''')

open(p, "w", encoding="utf-8").write(s)
print("ok")
