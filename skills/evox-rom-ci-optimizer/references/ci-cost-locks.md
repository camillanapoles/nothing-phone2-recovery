# Trava de Custo Zero — GitHub Actions & Codespaces

> Sem estas quatro travas o pipeline **não roda**. Um bootloop na AVD ou um Codespace
> esquecido consome minutos tarifados sem produzir evidência.

## 1. As quatro travas

| # | Trava | Onde | Valor canônico | Efeito |
|---|---|---|---|---|
| 1 | `concurrency` + `cancel-in-progress: true` | topo do workflow | grupo `${{ github.workflow }}-${{ github.ref }}` | mata run duplicada/superposta |
| 2 | `timeout-minutes` no job | cada job | `25` | teto de custo por job |
| 3 | `timeout-minutes` no step do emulador | step de emulador | `12` | AVD não fica pendurada |
| 4 | auto-poweroff do Codespace | `.devcontainer/devcontainer.json` | `sleep 1800 && sudo poweroff` | limite de 30 min ocioso |

## 2. Checabilidade (gate 1 do `SKILL.md`)

```bash
# falha se qualquer trava estiver ausente
grep -q "cancel-in-progress: true"  references/evox-ci-validator.yml
grep -q "timeout-minutes: 25"       references/evox-ci-validator.yml
grep -q "timeout-minutes: 10"       references/evox-ci-validator.yml
python3 -m json.tool references/devcontainer.json >/dev/null
```

## 3. Regras adicionais

- `paths-ignore` para docs: commit de markdown não deve acordar o emulador.
- Cache de ferramentas (`payload-dumper-go`, SDK, `.gradle`) com `actions/cache` — evita
  rebaixar ~6 GB de ROM por run.
- `runtime_module_tester.sh` usa `timeout 180` no `adb` — emulador que não chega a
  `sys.boot_completed=1` falha rápido em vez de queimar minutos.
- Nunca usar `workflow_run` encadeado sem `if` de caminho: um pipeline que se auto-dispara é
  a forma mais rápida de gastar cota.
