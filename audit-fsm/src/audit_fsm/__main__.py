"""`python -m audit_fsm` — o CLI do FSM sem depender do console script instalado.

Existe para o Makefile/CI rodarem a prova a partir do checkout, sem `pip install`.
"""

from .cli import main

if __name__ == "__main__":
    main()
