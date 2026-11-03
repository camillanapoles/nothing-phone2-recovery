# Changelog — audit-fsm

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) · versão em `audit_fsm.__version__`.

## [0.2.0] — 2026-11-02

### Integração com main (PR #18) — colisão de ids de mutante

O #18 foi mergeado em main depois do #16 e registrou `M198`/`M199` para o gate RC11
(`scripts/refactor_gate.py`). Esta feature já tinha usado `M198`–`M203`: o merge era "limpo"
e deixava **ids duplicados** no catálogo. Resolvido mantendo os ids de main (publicados) e
renumerando os seis da camada de prova para **`M200`–`M205`**.

Também no merge: o banco da prova **não** pode morar em `workspace/` — o #18 classificou
`workspace/audit` como *ephemeral* (RC11) e `workspace/` é limpo a cada sessão. Passou para
`state/proof/fsm.db` (`state/` é gitignored e o `state_reset` não o apaga): cobertura durável
sem violar a política de artefatos.


### Integração com main (PR #19) — mutante órfão e relatório datado

O #19 entrou em main depois do #18 e trouxe `CLAIMS-AUDIT.md` e `EXECUTION-SEQUENCE.md`, dois
**relatórios datados** com números medidos em `7df226e` (179/179, até M199, refactor 10/10).
O gate reprovou — corretamente — e nada foi reescrito: quem tem data ganha o marcador
`contagens: histórico` (o mecanismo que o próprio repo define), no arquivo para o relatório
inteiro e na linha para a premissa do plano, que segue vivo.

O CT3 foi corrigido na mesma auditoria: antes ele aplicava a **primeira** família que casasse na
linha, então numa linha "mutação 179/179 · refactor 11/11" o `11/11` era cobrado contra mutação.
Agora a associação é por **proximidade** (janela de 60 caracteres) e `refactor` entrou no gatilho
da família de refatoração — cada par é julgado contra a sua.

A reescrita do CT3 revelou a falha mais séria desta integração: o `find` do `M206` apontava para
uma indentação que a reescrita removeu. O mutante passou a `invalid` — e um mutante inválido
**prova o contrário do que se espera**: ele não acha o trecho e o teste nunca é exercitado. Na
árvore local isso passou; no CI, o shard 1 reprovou. Correções:
`mutation_check.py --verify` agora checa que o `find` de **cada** mutante existe **exatamente uma
vez** no código (`padroes_orfaos`), e `make -s prove` roda `mutacao-verifica` — ~1 s contra os
~15 min da execução completa, então refatoração que deixa mutante órfão reprova na hora e não no
fim. Três casos novos no harness e `M207` cobrindo a própria checagem.

### Adicionado — S9, ledger de prova durável

A cobertura de mutação deixa de ser um JSON da máquina que rodou e passa a ser **tabela do FSM**,
auditável por `run_id`.

- `proof_run` / `proof_item` no domínio (`_kind_` + `_fields_`), registrados pelo metaclass —
  nenhum `register()` manual; rotas e CLI são geradas como para qualquer outro kind.
- Tabelas `proof_runs` / `proof_items` + entradas em `TABLE_REGISTRY`; `run_id` indexado reusa
  `list_by_run`.
- `repository.upsert_one`: insert-or-update idempotente (reimportar a mesma origem não duplica).
- Comandos: `proof-start` (inicial) · `proof-import --run-id` (shards em paralelo) ·
  `proof-finalize` (final) · `proof-verify` (auditoria) · `proof-show` / `proof-runs`.
- Exit codes: `0` completa e coerente · `3` incompleta · `1` divergência (run declara mais do que
  as linhas sustentam).
- Ids determinísticos (`uuid5`) + `source_hash` (sha256 do ledger canônico): origem editada muda a
  identidade da execução; o mesmo ledger nunca duplica linhas.
- `normalizar()` aceita o ledger consolidado (`entries`) **e** o relatório cru de slot (`results`).
- `python -m audit_fsm` (novo `__main__`) além do console script.

### Corrigido

- `--db sqlite+aiosqlite:///novo/dir/fsm.db` morria com "unable to open database file": o diretório
  do arquivo agora é criado antes do engine (o banco da prova é o primeiro arquivo desse caminho).

- `api/db.get_engine()` era um singleton cego: trocar `AUDIT_FSM_DB_URL` em runtime (teste, `--db`,
  CLI) continuava escrevendo no banco antigo, sem erro. Agora recria o engine quando a URL muda.
- `.gitignore` ignorava o diretório inteiro `audit-fsm/`, o que faria arquivos-fonte novos
  (inclusive testes) sumirem do git sem aviso; agora só os bancos `*.db` são ignorados.
- Versão duplicada (`pyproject.toml` + `app.py`) → fonte única em `audit_fsm.__version__`,
  com teste que reprova divergência.

### Testes

- `tests/unit/test_proof_ledger.py` — determinismo de ids, formato de slot, `1` só para `killed`,
  divergência por adulteração, catálogo parcial × crescido.
- `tests/integration/test_cli_proof.py` — ciclo real por CLI, com os exit codes `0`/`3`/`1` e dois
  shards convergindo para a mesma execução.
- `tests/integration/test_proof_api.py` — import → banco → API → auditoria; leitura revalida.
- `tests/unit/test_metaclass_contract.py` — os quatro casos (a/b/c/d) também para os dois kinds novos.
- `tests/test_proof_layer.sh` — wrapper que o catálogo de mutação usa (mutantes só morrem se ESTES
  testes falharem; a base tem de estar verde antes).
