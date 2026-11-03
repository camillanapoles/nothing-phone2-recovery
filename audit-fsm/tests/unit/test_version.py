"""A versão tem UMA fonte: `audit_fsm.__version__`.

Antes, `pyproject.toml` e `api/app.py` carregavam "0.1.0" cada um — duas cópias que podiam
divergir em silêncio (o wheel dizia uma coisa, a API dizia outra). Este teste lê os três
lugares e exige igualdade, sem literal de versão no código.
"""

from __future__ import annotations

import tomllib
from pathlib import Path

from audit_fsm import __version__
from audit_fsm.api.app import app

RAIZ = Path(__file__).resolve().parents[2]  # audit-fsm/


def _versao_do_pyproject() -> str:
    with open(RAIZ / "pyproject.toml", "rb") as fh:
        return tomllib.load(fh)["project"]["version"]


def test_pyproject_e_pacote_concordam():
    assert _versao_do_pyproject() == __version__


def test_api_anuncia_a_versao_do_pacote():
    assert app.version == __version__
