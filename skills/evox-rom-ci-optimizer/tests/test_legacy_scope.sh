#!/usr/bin/env bash
# legacy_scope.py — passado que manda o contrário não pode passar por instrução atual. (15 casos)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; S="$HERE/../scripts/legacy_scope.py"; ROOT="$(cd "$HERE/../../.." && pwd)"
P=0; F=0
ok(){ printf 'PASS  %-58s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-58s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

rc=$(python3 "$S" --help >/dev/null 2>&1; echo $?); ck "--help sai 0" "exit" "$rc" "0"
rc=$(python3 "$S" --root /nao/existe >/dev/null 2>&1; echo $?); ck "root sem registro é entrada inválida" "exit" "$rc" "4"
rc=$(python3 "$S" --root "$ROOT" >/dev/null 2>&1; echo $?); ck "escopo do repo está limpo" "exit" "$rc" "0"
verdict=$(python3 "$S" --root "$ROOT" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["verdict"])')
ck "veredito ESCOPO_LIMPO" "ESCOPO_LIMPO" "$verdict" "ESCOPO_LIMPO"
# o número de legados é DERIVADO do registro — escrever "3" aqui faz o teste envelhecer sozinho
n=$(python3 "$S" --root "$ROOT" --list | grep -c "^LEGADO")
esperado=$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["legacy"]))' \
  "$ROOT/skills/evox-rom-ci-optimizer/references/legacy-sources.json")
ck "registro lista exatamente os legados declarados" "coerente" \
  "$([ "$n" = "$esperado" ] && echo coerente || echo "listou $n, registro tem $esperado")" "coerente"
hasbanner=$(python3 "$S" --root "$ROOT" --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print("sim" if any("carimbo" in c["detail"] for c in d["checks"]) else "nao")')
ck "carimbo histórico é verificado" "sim" "$hasbanner" "sim"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/skills/evox-rom-ci-optimizer/references"; mkdir -p "$R"
cp "$ROOT/skills/evox-rom-ci-optimizer/references/legacy-sources.json" "$R/"
mkdir -p "$T/docs/skills" "$T/legacy" "$T/arbitragem"
# canônicos mínimos + legados + conflitos declarados
python3 - "$R" "$T" <<'PY'
import json, sys, pathlib
R, T = sys.argv[1], pathlib.Path(sys.argv[2])
reg = json.load(open(R + "/legacy-sources.json"))
reg["canonical"] = ["docs/skills/APPROVED-INSTALL-SEQUENCE.md"]
reg["legacy"] = [{"path": "legacy/antigo.md", "kind": "file", "banner": "HISTÓRICO — NÃO EXECUTAR", "replaced_by": "x"}]
reg["removed"] = [{"path": "init_plan.md", "reason": "antigo"}]
reg["documented_conflicts"] = [{"id": "ordem", "doc": "docs/skills/APPROVED-INSTALL-SEQUENCE.md",
                                "must_mention": "install-guide", "why": "x"}]
json.dump(reg, open(R + "/legacy-sources.json", "w"))
(T / "docs/skills/APPROVED-INSTALL-SEQUENCE.md").write_text("ver install-guide\n")
(T / "legacy/antigo.md").write_text("# antigo\nsem carimbo\n")
PY
rc=$(python3 "$S" --root "$T" >/dev/null 2>&1; echo $?)
ck "legado sem carimbo reprova" "exit" "$rc" "3"
out=$(python3 "$S" --root "$T" --json); why=$(printf '%s' "$out" | python3 -c 'import json,sys;print(",".join(p["kind"] for p in json.load(sys.stdin)["problems"]))')
ck "motivo é legado_sem_carimbo" "legado_sem_carimbo" "$why" "legado_sem_carimbo"

printf '# HISTÓRICO — NÃO EXECUTAR\nreceita antiga\n' > "$T/legacy/antigo.md"
rc=$(python3 "$S" --root "$T" >/dev/null 2>&1; echo $?)
ck "legado com carimbo passa" "exit" "$rc" "0"

# legado registrado apontando para NADA: ausência é o estado bom — não há o que alguém siga
rm "$T/legacy/antigo.md"
rc=$(python3 "$S" --root "$T" >/dev/null 2>&1; echo $?)
ck "legado ausente do repo não reprova (ausência é o estado bom)" "exit" "$rc" "0"
printf '# HISTÓRICO — NÃO EXECUTAR\nreceita antiga\n' > "$T/legacy/antigo.md"

printf '# plano\n' > "$T/init_plan.md"
rc=$(python3 "$S" --root "$T" >/dev/null 2>&1; echo $?)
ck "arquivo removido que volta reprova" "exit" "$rc" "3"
out=$(python3 "$S" --root "$T" --json); why=$(printf '%s' "$out" | python3 -c 'import json,sys;print(",".join(p["kind"] for p in json.load(sys.stdin)["problems"]))')
ck "motivo é legado_voltou" "legado_voltou" "$why" "legado_voltou"
rm "$T/init_plan.md"

printf '# sequencia\nsem citar o guia antigo\n' > "$T/docs/skills/APPROVED-INSTALL-SEQUENCE.md"
rc=$(python3 "$S" --root "$T" >/dev/null 2>&1; echo $?)
ck "conflito apagado reprova" "exit" "$rc" "3"
out=$(python3 "$S" --root "$T" --json); why=$(printf '%s' "$out" | python3 -c 'import json,sys;print(",".join(p["kind"] for p in json.load(sys.stdin)["problems"]))')
ck "motivo é conflito_apagado" "conflito_apagado" "$why" "conflito_apagado"

rm "$T/docs/skills/APPROVED-INSTALL-SEQUENCE.md"
rc=$(python3 "$S" --root "$T" >/dev/null 2>&1; echo $?)
ck "fonte canônica ausente reprova" "exit" "$rc" "3"
out=$(python3 "$S" --root "$T" --json); why=$(printf '%s' "$out" | python3 -c 'import json,sys;print(",".join(sorted(set(p["kind"] for p in json.load(sys.stdin)["problems"]))))')
ck "motivo cita canônico e conflito" "canonico_ausente,conflito_sem_doc" "$why" "canonico_ausente,conflito_sem_doc"

printf '%s\n' "-----------------------------------------------------------------------"
printf 'TOTAL: %d PASS / %d FAIL\n' "$P" "$F"
[ "$F" -eq 0 ]
