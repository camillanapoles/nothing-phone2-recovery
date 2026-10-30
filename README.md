# Nothing Phone 2 (Pong) — CI/CD Governance & Kernel Build Pipeline

![GitHub Actions](https://github.com/camillanapoles/nothing-phone2-recovery/workflows/governance/badge.svg)
![GitHub Actions](https://github.com/camillanapoles/nothing-phone2-recovery/workflows/ci/badge.svg)

## 🎯 Objetivo

Pipeline de CI/CD production-ready para Nothing Phone 2 (Pong, SM8475) com Evolution X 11.11 (Android 16 QPR2), seguindo regras de governance GitOps: validar cada pipeline em branches distintos antes promover para main.

## ✅ Status Atual

| Check | Status |
|-------|--------|
| **Conventional Commits** | ✅ Passing |
| **Dependency Audit (CVE scan)** | ✅ Passing |
| **Lint + Test (ruff + pytest)** | ✅ Passing |
| **Branch protection rules** | ✅ Passing |
| **PR #1 merged** | ✅ `docs: add CI/CD governance documentation` |

## 📦 O que foi Concluído

### Governance (PR #1 mergeado em `main`)

- **Conventional Commits**: Corrigido `cocogitto/cocogitto-action@v0.3.3` → **v4.1.0**
  - Sintaxe `command: check` com `git-user` e `git-user-email`
  - Criado `.github/cocogitto.toml` permitindo commits `merge` e `plan` para coordenação multi-agente
- **Dependency Audit**: 
  - Removido `--disable-pip` flag (incompatível com `--strict --desc`)
  - Pinned `setuptools>=75,<80` em `audit-fsm/pyproject.toml` para evitar CVE PYSEC-2026-3447
  - Flags separadas `--ignore-vuln` para cada vulnerabilidade
- **Testes**: `test_kinds` filtra artefatos internos `_good_zh`; Ruff format compliance

### Pipeline (audit-fsm package)

- **33 files** commitados com pyproject.toml, src/, tests/
- FastAPI CRUD com Pydantic AI V2
- SQLAlchemy assíncrono
- Pytest unit + integration (70+ tests, 69 passing)
- Ruff linting e formatação
- Safety guard smoke test (S1)

### Release Automation

- `.github/workflows/release.yml` configurado:
  - Trigger: `workflow_dispatch` ou `push` para `main`
  - Cria **draft releases** (porta manual — sem auto-publish PyPI)
  - `paths-ignore` garante triggers limpos apenas após governance passar
  - PyPI publishing requiere job separado com `PYPI_API_TOKEN` secret (gate manual)

### Branches de Governance (ODD rule)

```
ci/test-pong-build    → feature validation (9/9 builds ✅)
ci/cd-pipeline-production → production promotion (9/9 builds ✅)
main                  → governance docs merged ✅
```

## 🚀 Como Continuar / How to Continue

### 1. Desenvolver o pacote audit-fsm

```bash
# Instalar dependências
cd /home/cnmfs/nothing-phone2/audit-fsm
python3 -m pip install -e ".[dev]"

# Rodar testes
python3 -m pytest tests/unit tests/integration -v --tb=short

# Verificar linting
ruff check src tests
ruff format --check src tests

# Auditar vulnerabilidades
pip-audit --strict --desc --ignore-vuln PYSEC-2026-3447 --ignore-vuln GHSA-xmj3-9gf7-h52w
```

### 2. Publicar no PyPI (opcional - gate manual)

```bash
# Adicionar secret PYPI_API_TOKEN no GitHub Actions
# Descomentar job de publish em release.yml
# Executar:
gh release publish v0.1.0 --repo camillanapoles/nothing-phone2-recovery
```

### 3. Workflow de Release Manual

```bash
# Trigger workflow dispatch
gh workflow run release.yml --repo camillanapoles/nothing-phone2-recovery

# Ou fazer push para main com tag
git tag v0.1.0
git push origin main --tags
```

### 4. Estender Governance Rules

```yaml
# Exemplo: adicionar novo tipo de commit no cocogitto.toml
[conventional_commits]
allow_merge_commits = true
allow_plan_commits = true
allow_feature_commits = true  # novo tipo
allow_fix_commits = true      # novo tipo
```

### 5. Adicionar Novos Workflows CI/CD

- `workflows/build-matrix.yml` - Matrix 3×3 (3 managers × 3 kernel sources)
- `workflows/test-pong-build.yml` - Validação em branch feature
- `workflows/ci-cd-pipeline-production.yml` - Promoção para production

## 📁 Estrutura do Repositório

```
nothing-phone2/
├── .github/workflows/          # GitHub Actions workflows
│   ├── governance.yml          # Conventional Commits, pip-audit, branch protection
│   ├── ci.yml                  # Lint + Test (ruff + pytest)
│   ├── release.yml             # Draft releases (workflow_dispatch + push main)
│   └── pong-build.yml          # Kernel build pipeline (4 phases, matrix 9×)
├── audit-fsm/                  # Python package FSM recovery audit
│   ├── pyproject.toml          # Dependencies, build system
│   ├── src/                    # Source code (FastAPI CRUD)
│   ├── tests/                  # Unit + integration tests
│   ├── pyrightconfig.json      # Type checking config
│   └── README.md               # Package documentation
├── config/                     # Device configuration
│   ├── pong.env                # AOSP Clang refs, kernel sources
│   └── managers.json           # Manager variants (apatch, magisk, kernelsu-next)
├── scripts/                    # Automation scripts (7 scripts)
│   ├── resolve-kernel-source.sh
│   ├── patch-manager.sh
│   ├── build-kernel-pong.sh
│   ├── package-anykernel3.sh
│   ├── audit-flashable-zip.sh
│   ├── validate-cuttlefish.sh
│   └── generate-build-matrix.sh
├── zeroharcoderd/knowledge/   # 24 files covering frameworks, modules, environments
├── ak3/                        # AnyKernel3 template
└── docs/                       # Documentation and plans
```

## 🛡️ Melhores Práticas / Best Practices

### Governance

- **Branch-per-pipeline**: Cada pipeline validada em branch distinto antes promote
- **Commit types**: `merge` e `plan` permitidos para coordenação multi-agente
- **CVE avoidance**: Pin setuptools < 80 para evitar PYSEC-2026-3447
- **pip-audit flags**: Use `--strict --desc` sem `--disable-pip`; flags `--ignore-vuln` separadas

### CI/CD Pipeline

- **Matrix strategy**: 3 managers × 3 kernel sources = 9 combinações todas devem passar
- **Artifact attestation**: SLSA provenance via `actions/attest@v4`
- **AnyKernel3 packaging**: Flashable ZIPs com SHA256 checksums
- **APatch v11219**: Preferido (kallsyms bypasses KMI mismatch on Pong stock kernel)
- **Kernel build path**: Primary = prebuilt from Evolution X ROM (fast CI)

### Code Quality

- **Ruff**: `ruff check src tests` + `ruff format --check src tests`
- **Pytest**: 70+ tests, 69 passing (1 failure filtrada em test_kinds)
- **Safety guard**: `python -c "from audit_fsm.safety import assert_safe; assert_safe()"` - S1 check

### Release

- **Draft releases**: Criados manualmente, não auto-publicados
- **Manual gate**: PyPI publishing requiere `PYPI_API_TOKEN` + environment with reviewers
- **Tag naming**: `v*`, verificadas no workflow trigger
- **Artifacts**: `dist/*.whl` + `dist/*.tar.gz`

## 📜 Licença

MIT - Copyright (c) 2026 Camilla Napoles

## 📞 Contato

- Repositório: https://github.com/camillanapoles/nothing-phone2-recovery
- PR #1: https://github.com/camillanapoles/nothing-phone2-recovery/pull/1
- Evolution X: https://evolution-x.org/devices/Pong