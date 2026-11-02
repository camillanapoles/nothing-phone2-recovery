#!/usr/bin/env bash
# .github/workflows/prove.yml — as travas do fluxo em nuvem (12 casos)
# Sem pyyaml: o alvo é YAML simples e as invariantes são textuais (mesma escolha de ci_workflow_lint.py).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$(cd "$HERE/../../.." && pwd)/.github/workflows/prove.yml"
P=0; F=0
ok(){ printf 'PASS  %-50s %s\n' "$1" "$2"; P=$((P+1)); }
bad(){ printf 'FAIL  %-50s %s\n' "$1" "$2"; F=$((F+1)); }
ck(){ if [ "$3" = "$4" ]; then ok "$1" "$2"; else bad "$1" "$2 (esperado '$4', obtido '$3')"; fi; }

ck "workflow existe" "sim" "$([ -f "$W" ] && echo sim || echo nao)" "sim"

ck "concurrency com cancel-in-progress (R1)" "1" "$(grep -c '^  cancel-in-progress: true' "$W")" "1"
ck "permissions somente leitura (R6)" "0" "$(grep -c 'write-all\|contents: write' "$W")" "0"
ck "checkout + setup-python pinados" "sim" \
  "$(grep -q 'actions/checkout@v4' "$W" && grep -q 'actions/setup-python@v5' "$W" && echo sim || echo nao)" "sim"

# todo timeout-minutes declarado tem de ser <= 30 (R2)
TMAX="$(grep -o 'timeout-minutes: [0-9]*' "$W" | awk '{print $2}' | sort -n | tail -1)"
ck "nenhum timeout acima de 30 min (R2)" "<=30" "$([ "${TMAX:-0}" -le 30 ] && echo '<=30' || echo ">30 ($TMAX)")" "<=30"
ck "os 3 jobs declaram timeout (3)" "3" "$(grep -c '^    timeout-minutes:' "$W")" "3"

ck "retenção de artefato <= 7 dias (R5)" "0" \
  "$(grep -o 'retention-days: [0-9]*' "$W" | awk '$2 > 7' | wc -l | tr -d ' ')" "0"
ck "nenhum fastboot no CI (AG13)" "0" "$(grep -c 'run:.*fastboot' "$W")" "0"
ck "nenhum segredo literal (R11)" "0" \
  "$(grep -cE 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY' "$W")" "0"

# a partição: 4 shards, cada um chamando --shard K/4
ck "matrix de 4 shards" "1" "$(grep -c 'shard: \[1, 2, 3, 4\]' "$W")" "1"
ck "mutação roda por shard" "1" "$(grep -c -- '--shard "\${{ matrix.shard }}/4"' "$W")" "1"

# as 12 suítes do prove aparecem no job static
faltando=""
for s in state wrappers arch validate core-check scanner preflight rom gates ci guard eval; do
  grep -q "run_\(cases\|gate\)  *$s " "$W" || faltando="$faltando $s"
done
ck "as 12 suítes estão no static" "nenhuma" "$([ -z "$faltando" ] && echo nenhuma || echo "faltando:$faltando")" "nenhuma"

# o agregador: depende dos dois jobs, roda sempre e valida item a item
ck "aggregate depende de static e mutation, sempre" "sim" \
  "$(grep -q 'needs: \[static, mutation\]' "$W" && grep -q 'if: always()' "$W" && echo sim || echo nao)" "sim"
ck "static e aggregate validam com --validate (2)" "2" \
  "$(grep -c -- '--validate workspace/proof/\*.json' "$W")" "2"
ck "shard ausente reprova explicitamente" "1" "$(grep -c '::error::shard \$n não retornou' "$W")" "1"
ck "união dos shards comparada ao catálogo" "1" "$(grep -c 'mutation-catalog.json' "$W")" "1"

echo "-----------------------------------------------------------------------"
echo "TOTAL: $P PASS / $F FAIL"; [ "$F" -eq 0 ] || exit 1
