"""
Async SQLAlchemy database layer for audit-fsm (S4, T5).

Uses aiosqlite for async I/O. The engine is created lazily on first use;
tests can override the database URL via the `AUDIT_FSM_DB_URL` env var
(default: sqlite+aiosqlite:///./audit-fsm.db).

init_db() creates all tables registered in domain.tables.metadata.
"""

from __future__ import annotations

import os

from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from ..domain.tables import metadata

_DEFAULT_URL = "sqlite+aiosqlite:///./audit-fsm.db"

_engine: AsyncEngine | None = None
_engine_url: str | None = None


def get_db_url() -> str:
    """Return the database URL from env or default."""
    return os.environ.get("AUDIT_FSM_DB_URL", _DEFAULT_URL)


def _garantir_diretorio(url: str) -> None:
    """Cria o diretório do arquivo SQLite antes de abrir o engine.

    Sem isto, `--db sqlite+aiosqlite:///state/proof/fsm.db` num caminho novo morre com
    "unable to open database file" — o banco da prova costuma ser o primeiro arquivo ali.
    """
    if not url.startswith("sqlite"):
        return
    caminho = url.split("///", 1)[-1].split("?", 1)[0]
    if not caminho or caminho.startswith(":memory:"):
        return
    destino = os.path.dirname(os.path.abspath(caminho))
    if destino:
        os.makedirs(destino, exist_ok=True)


def get_engine() -> AsyncEngine:
    """Return the lazily-created async engine, recriando se a URL mudou.

    Antes era um singleton "cego": trocar `AUDIT_FSM_DB_URL` em runtime (teste, `--db`,
    CLI) continuava escrevendo no banco antigo — o dado ia para o lugar errado sem erro.
    """
    global _engine, _engine_url
    url = get_db_url()
    if _engine is None or _engine_url != url:
        _garantir_diretorio(url)
        _engine = create_async_engine(url, echo=False)
        _engine_url = url
    return _engine


async def init_db() -> None:
    """Create all tables if they don't exist."""
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(metadata.create_all)  # type: ignore[union-attr]


async def dispose_engine() -> None:
    """Dispose the engine (for tests / shutdown)."""
    global _engine, _engine_url
    if _engine is not None:
        await _engine.dispose()
        _engine = None
        _engine_url = None
