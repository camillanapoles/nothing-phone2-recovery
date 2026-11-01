---
name: act-github-pat
description: Criar, configurar, validar e gerenciar GitHub Personal Access Tokens (PAT - Classic e Fine-Grained) para nektos/act na execucao local de GitHub Actions. Use quando o usuario precisar rodar workflows localmente com act, contornar rate limits da API GitHub (403 API rate limit exceeded), acessar repositorios ou actions privadas, configurar .secrets, ~/.actrc, variaveis de ambiente ou integrar com gh auth token.
---
# act-github-pat

Habilidade para criacao, configuracao, injecao e ciclo de vida de Personal Access Tokens (PAT) do GitHub para uso com o runner local `act` (nektos/act).

## Contexto e Escopos

O `act` executa workflows do GitHub Actions localmente dentro de containers Docker. Sem autenticacao, requisicoes para download de actions no GitHub Marketplace sofrem com o limite estrito da API publica (60 req/h por IP), disparando erro HTTP 403. Alem disso, workflows dependentes de repositorios privados ou pacotes requerem autenticacao explicita.

### Matriz de Escopos por Caso de Uso

1. **Apenas contornar Rate Limit (Repositorios e Actions publicas):**

   - Fine-Grained PAT: Nenhuma permissao de repositorio necessaria (apenas conta publica).
   - Classic PAT: Criar sem nenhum escopo marcado (concede 5.000 req/h para endpoints publicos com superficie de ataque zero).

2. **Actions ou Submodulos em Repositorios Privados:**

   - Fine-Grained PAT: Acesso ao repositorio alvo com permissao `Contents: Read`.
   - Classic PAT: Escopo `repo`.

3. **Publicacao de Pacotes / Containers (GHCR):**

   - Fine-Grained PAT: `Packages: Read and Write`.
   - Classic PAT: Escopos `write:packages`, `read:packages`.

## Metodos de Criacao do Token

### Opcao A: Extracao Dinamica via GitHub CLI (Recomendado - Zero Hardcoding)

Se o usuario ja utiliza a ferramenta `gh` autenticada:

```bash
gh auth token
```

Para verificar se os escopos atuais sao suficientes:

```bash
gh auth status
```

Se for necessario expandir escopos:

```bash
gh auth refresh -s repo,workflow
```

### Opcao B: Geracao Manual via Web UI

- **Fine-Grained PAT (Mais seguro):** Acessar `https://github.com/settings/tokens?type=beta`
  - Definir nome descritivo (ex: `act-local-runner`).
  - Definir expiracao (recomendado: 30 a 90 dias).
  - Selecionar repositorios especificos.
- **Classic PAT:** Acessar `https://github.com/settings/tokens/new`
  - Para rate limit simples: nao marcar nenhuma caixa de escopo.
  - Para repositorios privados: marcar `repo`.

## Configuracao e Injecao no act

### 1. Injecao Dinamica inline (Sessao Unica)

Passagem direta do token ativo da CLI `gh` sem salvar em disco:

```bash
act -s GITHUB_TOKEN="$(gh auth token)"
```

Para entrada segura interativa (oculta o token no terminal):

```bash
act -s GITHUB_TOKEN
```

### 2. Arquivo Local .secrets (Por Repositorio)

Criar o arquivo `.secrets` na raiz do repositorio:

```env
GITHUB_TOKEN=ghp_seuTokenAqui
```

Execucao:

```bash
act --secret-file .secrets
```

Regra de seguranca obrigatoria: o arquivo `.secrets` deve constar no `.gitignore`:

```bash
echo ".secrets" >> .gitignore
```

### 3. Configuracao Global Persistente (~/.actrc)

Para evitar passar flags em toda execucao, configurar o arquivo `~/.actrc`:

```text
-s GITHUB_TOKEN=ghp_seuTokenAqui
```

Ou apontar para um arquivo central de segredos protegido:

```text
--secret-file ~/.config/act/.secrets
```

Ajustar permissoes do arquivo de segredos global:

```bash
chmod 600 ~/.config/act/.secrets
```

### 4. Variavel de Ambiente

Exportar no ambiente da shell:

```bash
export GITHUB_TOKEN="ghp_seuTokenAqui"
act -s GITHUB_TOKEN
```

## Validacao e Diagnostico

### Testar Conectividade e Rate Limit

Verificar validade do token e cota restante:

```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit | grep -E "limit|remaining|reset"
```

Via GitHub CLI:

```bash
gh api rate_limit
```

### Validar Execucao no act

Listar jobs do workflow com autenticacao injetada:

```bash
act -l -s GITHUB_TOKEN="$(gh auth token)"
```

Executar job especifico com log verboso para inspecionar eventuais falhas de autenticacao:

```bash
act -j <job_id> -s GITHUB_TOKEN="$(gh auth token)" --verbose
```

## Gotchas e Seguranca

- **Token Vazio vs Rate Limit:** Se o `act` apresentar `403 API rate limit exceeded`, o token nao foi injetado corretamente ou nao esta sendo lido pelo container do job.
- **GITHUB_TOKEN local vs CI:** No runner do GitHub Actions em nuvem, o `secrets.GITHUB_TOKEN` e gerado dinamicamente para o job. No `act`, ele precisa ser explicitamente fornecido via `-s GITHUB_TOKEN=...`.
- **Exposicao de Segredos:** Nunca comitar arquivos `.secrets` ou `.actrc` contendo tokens literais em repositorios git.
- **Rotacao e Revogacao:** Em caso de comprometimento acidental, revogar o token imediatamente em `https://github.com/settings/tokens`.


---

## Gates binários, reversibilidade e composição (extensão do harness · 2026-11-01)

> Seção adicionada pela auditoria de qualidade (lacuna E2/E5/E7). Não substitui o texto acima:
> formaliza o que já era prática em critérios verificáveis.

| # | Gate | **PASS se** | **FAIL se** | Evidência exigida |
|---|---|---|---|---|
| G1 | Escopo mínimo de token | escopo bate com a matriz de uso (rate-limit sem escopo; privado `repo`/`Contents: Read`) | escopo amplo "por garantia" | saída de `gh auth status` anexada |
| G2 | Zero segredo em disco versionado | `.secrets` está no `.gitignore` e `git check-ignore .secrets` retorna caminho | `.secrets` rastreável | `git check-ignore -v .secrets` |
| G3 | Expiração definida | PAT com expiração ≤ 90 dias registrada | token sem expiração | data no nome/descrição do token |
| G4 | Injeção sem hardcode | `-s GITHUB_TOKEN="$(gh auth token)"` ou input interativo | token colado em comando versionado | histórico do shell/ARQUIVO |

**Reversibilidade:** todo token criado tem revogação explícita (`gh auth logout`, delete do PAT)
e o comando de revogação é informado junto da criação. Não existe "token temporário" sem data
de morte.

**Custo:** respeitar o orçamento de 5.000 req/h do PAT e não deixar `act` em loop — cada
`act` consome minutos locais e baixa actions; usar `--reuse` e cache de container.

**Composição / handoff:** esta skill é chamada por `evox-rom-ci-optimizer` (alvo `make run-act`)
e depende de `github` para operações autenticadas de leitura. Ao terminar, o handoff devolve
"token válido? escopo? expira quando?" antes de qualquer pipeline rodar.
