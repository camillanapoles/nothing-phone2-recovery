#!/usr/bin/env bash
# base_gate.py — a branch tem de CONTER a main. Este gate existe porque o contrário já aconteceu 4×:
# branch nascida de commit velho, PR que *apaga* o que a main ganhou (achado E12).
# 8 casos: sanidade/CLI + a DIREÇÃO da ancestralidade (o erro fácil) + clone raso + sem ref.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
K="$ROOT/scripts/base_gate.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=0; F=0
ok(){ P=$((P+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad(){ F=$((F+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

# repo de brinquedo: 3 commits, main aponta para o 3º
brinquedo(){   # $1 = destino
  git init -q "$1" && cd "$1" || return 1
  git config user.email t@t; git config user.name t
  for i in 1 2 3; do echo "conteudo $i" > "arq$i.txt"; git add -A; git commit -qm "c$i"; done
  git branch -M main
  git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
  cd - >/dev/null
}

# ---------------------------------------------------------------- 0. sanidade
out="$(cd "$ROOT" && python3 "$K" --root . 2>&1)"; rc=$?
ck "repo real: branch contém a main (exit 0)" "exit $rc" "$rc" "0"
case "$out" in *"ancestral de HEAD"*) ok "repo real explica a direção" "OK" ;; *) bad "repo real explica a direção" "$out" ;; esac

python3 "$K" --root . --bogus >/dev/null 2>&1; ck "flag inválida = exit 4 (uso)" "exit" "$?" "4"
mkdir -p "$T/naogit"
python3 "$K" --root "$T/naogit" >/dev/null 2>&1; ck "fora de repo git = PENDENTE (3)" "exit" "$?" "3"

# ---------------------------------------------------------------- 1. a direção (erro fácil de inverter)
brinquedo "$T/ok"
ck "HEAD contém a ref = OK" "exit" "$(python3 "$K" --root "$T/ok" --ref origin/main >/dev/null 2>&1; echo $?)" "0"

brinquedo "$T/atras"
git -C "$T/atras" checkout -q --detach HEAD~2
out="$(python3 "$K" --root "$T/atras" --ref origin/main 2>&1)"; rc=$?
ck "branch ATRÁS de main = FALHA (exit 1)" "exit $rc" "$rc" "1"
case "$out" in
  *"perderia: arq3.txt"*) ok "aponta o arquivo que o PR apagaria" "arq3.txt" ;;
  *) bad "aponta o arquivo que o PR apagaria" "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')" ;;
esac
ck "conta os commits atrás" "2" "$(python3 "$K" --root "$T/atras" --ref origin/main --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["commits_atras"])')" "2"

# ---------------------------------------------------------------- 2. não dá para provar ≠ verde
ck "ref inexistente = PENDENTE (3)" "exit" "$(python3 "$K" --root "$T/ok" --ref origin/naoexiste >/dev/null 2>&1; echo $?)" "3"
if git clone -q --depth 1 "file://$T/ok" "$T/raso" 2>/dev/null; then
  out="$(python3 "$K" --root "$T/raso" --ref origin/main 2>&1)"; rc=$?
  ck "clone raso = PENDENTE (3), nunca verde" "exit $rc" "$rc" "3"
  case "$out" in *"clone raso"*) ok "clone raso diz por quê" "clone raso" ;; *) bad "clone raso diz por quê" "$out" ;; esac
else
  bad "clone raso = PENDENTE (3), nunca verde" "git clone --depth indisponível"
fi

# ---------------------------------------------------------------- 3. JSON
js="$(cd "$ROOT" && python3 "$K" --root . --json 2>/dev/null)"
case "$js" in *'"verdict": "OK"'*) ok "--json publica veredito" "OK" ;; *) bad "--json publica veredito" "${js:0:60}" ;; esac

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
