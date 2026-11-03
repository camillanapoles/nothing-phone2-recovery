#!/usr/bin/env bash
# Prova da camada de ledger (S9) — roda só o que ela promete, a partir da cópia mutante.
#
# Usado pelo catálogo de mutação (`make mutation`): cada mutante em `proof/ledger.py`,
# `proof/__init__.py` ou no CLI tem de fazer ESTE comando sair != 0. Se um mutante sobrevive,
# é porque o teste não prova o que diz provar.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2   # audit-fsm/

PYTHONPATH=src python3 -m pytest \
  tests/unit/test_proof_ledger.py \
  tests/integration/test_cli_proof.py \
  tests/integration/test_proof_api.py \
  -q --no-header -p no:cacheprovider
