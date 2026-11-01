# Geração de Skills — 9 fases + catálogo de componentes (seções IV e V)

> Extraído de `fabrica-de-agentes/SKILL.md` (v2.0, 77 KB) para respeitar o limite de 64 KB do contrato de runtime.
> Conteúdo verbatim, sem edição.

## IV. PROCESSO DE GERAÇÃO — 9 FASES

---

### FASE 1 — RECONHECIMENTO DO DOMÍNIO (用間)

**Objetivo:** Mapear o território de expertise ANTES de construir.

**MÉTODO (v2.0 — como fazer):**

Use a técnica **5W2H do Domínio**:

| Pergunta     | Aplicação                                             | Output                 |
| ------------ | ----------------------------------------------------- | ---------------------- |
| **WHAT**     | O que é a atividade? Quais os conceitos fundamentais? | Glossário (5-8 termos) |
| **WHY**      | Por que existe? Qual problema resolve?                | Propósito              |
| **WHEN**     | Quando se aplica? Timing, sazonalidade?               | Contexto temporal      |
| **WHERE**    | Onde se executa? Ambiente, plataforma?                | Restrições ambientais  |
| **WHO**      | Quem faz? Quem recebe?                                | Personas               |
| **HOW**      | Como se faz? Pipeline natural?                        | Fases operacionais     |
| **HOW MUCH** | Quanto custa em tempo/recurso/esforço?                | Orçamento operacional  |

**Ações complementares:**

| #   | Ação                                                  | Output           |
| --- | ----------------------------------------------------- | ---------------- |
| 1   | Identificar os 5 conceitos fundamentais               | Glossário base   |
| 2   | Mapear as 3-5 fases típicas da atividade              | Pipeline natural |
| 3   | Identificar os 5 erros mais comuns                    | Anti-padrões     |
| 4   | Mapear ferramentas/recursos                           | Arsenal          |
| 5   | Identificar o gap entre amador e expert               | Diferencial      |
| 6   | Definir vocabulário técnico                           | Dicionário       |
| 7   | **Identificar o "ponto de não-retorno" da atividade** | Momento crítico  |

**Output obrigatório:**

```
DOCUMENTO DE RECONHECIMENTO DO DOMÍNIO
───────────────────────────────────────
DOMÍNIO: _______________
SUB-DOMÍNIO: _______________

5W2H:
WHAT:
WHY:
WHEN:
WHERE:
WHO:
HOW:
HOW MUCH:

CONCEITOS FUNDAMENTAIS:
1.
2.
3.
4.
5.

PIPELINE NATURAL:
Fase A → Fase B → Fase C → Fase D → Fase E

PONTO DE NÃO-RETORNO:
→ [Momento em que um erro se torna irreversível]

ERROS COMUNS:
1.
2.
3.
4.
5.

FERRAMENTAS/RECURSOS:
-

VOCABULÁRIO TÉCNICO:
-

GAP AMADOR → EXPERT:
→
```

---

### FASE 2 — DEFINIÇÃO DE IDENTIDADE (道)

**Objetivo:** Dar alma ao agente. Definir QUEM ele é E QUEM ELE NÃO É.

**MÉTODO para extrair a filosofia (v2.0):**

> Pergunte: _"Se esta atividade fosse uma pessoa, o que ela diria sobre si mesma em uma frase?"_
> Depois: _"O que ela NUNCA diria?"_
> A filosofia nasce da tensão entre as duas respostas.

**Template:**

```
IDENTIDADE DO AGENTE
────────────────────
NOME/CÓDIGO: _______________
DOMÍNIO: _______________
MISSÃO (1 frase): _______________

FILOSOFIA OPERACIONAL:
→ [Frase que ancora o agente. Extraída pelo método acima.]

TOM: _______________
PERSONALIDADE: _______________

ANTI-IDENTIDADE (v2.0):
→ O agente NUNCA soa como: _______________
→ O agente NUNCA usa: _______________
→ O agente NUNCA se comporta como: _______________

CRENÇAS OPERACIONAIS:
1.
2.
3.

O QUE O AGENTE NUNCA FAZ:
1.
2.
3.

O QUE O AGENTE SEMPRE FAZ:
1.
2.
3.
```

---

### FASE 3 — ARQUITETURA OPERACIONAL (法)

**Objetivo:** Definir COMO o agente processa e entrega.

**Estrutura obrigatória:**

```
ARQUITETURA DE PROCESSAMENTO
─────────────────────────────

┌─────────────────────────────────────────────┐
│ BLOCO 1: RECEPÇÃO                           │
│ → Como recebe a demanda                     │
│ → Como interpreta/contextualiza             │
│ → O que pergunta antes de agir              │
├─────────────────────────────────────────────┤
│ BLOCO 2: ANÁLISE/PLANEJAMENTO               │
│ → Como decompõe o problema                  │
│ → Critérios de decisão                      │
│ → Ferramentas que consulta                  │
│ → Antecipação de erros (mínimo 3)           │
├─────────────────────────────────────────────┤
│ BLOCO 3: EXECUÇÃO                           │
│ → Passo-a-passo operacional                 │
│ → Técnicas específicas aplicadas            │
│ → Checkpoints de verificação                │
│ → Pontos de não-retorno marcados            │
├─────────────────────────────────────────────┤
│ BLOCO 4: REFINAMENTO                        │
│ → Como revisa o próprio output              │
│ → Critérios de qualidade                    │
│ → Iterações permitidas (máx 3)              │
├─────────────────────────────────────────────┤
│ BLOCO 5: ENTREGA                            │
│ → Formato final                             │
│ → Como apresenta ao usuário                 │
│ → O que acompanha a entrega                 │
│ → Próximo passo sugerido                    │
├─────────────────────────────────────────────┤
│ BLOCO 6: FEEDBACK/ITERAÇÃO                  │
│ → Como recebe correções                     │
│ → Como ajusta sem recomeçar                 │
│ → Quando encerra o ciclo                    │
│ → Degradação graciosa se não souber         │
└─────────────────────────────────────────────┘
```

---

### FASE 4 — CATÁLOGO DE TÉCNICAS (T01-Tn)

**Objetivo:** Criar o arsenal específico do agente.

**Formato obrigatório de cada técnica (v2.0 com exemplo concreto):**

```
┌─────────────────────────────────────────────────────┐
│ T[XX] — [NOME DA TÉCNICA]                          │
├─────────────────────────────────────────────────────┤
│ Definição:    [O que é em 1 frase]                 │
│ Quando usar:  [Contexto de aplicação]              │
│ Como usar:    [Passo-a-passo numerado]             │
│                                                     │
│ EXEMPLO CONCRETO (v2.0 OBRIGATÓRIO):               │
│   INPUT:  [Situação real de entrada]               │
│   AÇÃO:   [O que o agente faz]                     │
│   OUTPUT: [Resultado concreto]                     │
│                                                     │
│ Validação:    [Critério binário: PASS se ___]      │
│ Risco:        [O que pode dar errado]              │
│ Correção:     [Como corrigir se falhar]            │
└─────────────────────────────────────────────────────┘
```

**Regras:**

- Mínimo 5 técnicas. Máximo 12.
- Cada uma autocontida.
- **Cada uma DEVE ter exemplo concreto com input/output reais.**
- Se não houver exemplo concreto, a técnica está INCOMPLETA.

---

### FASE 5 — REGRAS DE COMPORTAMENTO (将)

**Formato:**

| #   | Regra              | Tipo      | Se violar = |
| --- | ------------------ | --------- | ----------- |
| 1   | O agente NUNCA...  | Proibição |             |
| 2   | O agente SEMPRE... | Obrigação |             |
| 3   | O agente NUNCA...  | Proibição |             |
| 4   | O agente SEMPRE... | Obrigação |             |
| ... |                    |           |             |

**Mínimo:** 8 regras. **Máximo:** 15.
**v2.0:** Mínimo 4 NUNCA + 4 SEMPRE.

---

### FASE 6 — VALIDAÇÃO EMBUTIDA (廟算)

**Formato v2.0 — BINÁRIO:**

| #   | Teste | Critério de PASS      | Critério de FAIL  | Se FAIL → Ação        |
| --- | ----- | --------------------- | ----------------- | --------------------- |
| 1   |       | [Condição mensurável] | [Condição oposta] | [Correção específica] |
| 2   |       |                       |                   |                       |
| ... |       |                       |                   |                       |

**Mínimo:** 8 testes. **Máximo:** 20.
**v2.0:** Cada teste TEM que ter critério binário explícito.

---

### FASE 7 — ANTI-PADRÕES (ERROS FATAIS)

| #   | Erro | Por quê é fatal | Exemplo concreto do erro | Correção |
| --- | ---- | --------------- | ------------------------ | -------- |
| 1   |      |                 |                          |          |
| 2   |      |                 |                          |          |
| ... |      |                 |                          |          |

**Mínimo:** 7 erros. **Máximo:** 15.
**v2.0:** Cada erro tem exemplo concreto.

---

### FASE 8 — TEMPLATE OPERACIONAL DE SAÍDA

Deve conter:

- Campos de entrada
- Campos de processamento
- Campos de saída
- Checklist de validação
- Campo de avaliação pós-execução
- **Exemplo preenchido (v2.0 OBRIGATÓRIO)**

---

### FASE 9 — EMPACOTAMENTO E ENTREGA

**Ordem obrigatória de montagem:**

```
1.  TÍTULO + SUBTÍTULO
2.  ÍNDICE
3.  FUNDAMENTOS FILOSÓFICOS (do domínio)
4.  PRINCÍPIOS OPERACIONAIS
5.  ARQUITETURA DE PROCESSAMENTO
6.  CATÁLOGO DE TÉCNICAS (com exemplos concretos)
7.  REGRAS DE COMPORTAMENTO
8.  VALIDAÇÃO (TESTES BINÁRIOS)
9.  ANTI-PADRÕES (ERROS FATAIS com exemplos)
10. TEMPLATE OPERACIONAL (com exemplo preenchido)
11. FLUXO CONDICIONAL
12. FRASES-SÍNTESE
13. APLICAÇÃO POR CONTEXTO (variações)
14. DEGRADAÇÃO GRACIOSA
15. KPIs DO DOMÍNIO
```

---

## V. CATÁLOGO DE COMPONENTES REUTILIZÁVEIS

| Componente                    | Função                    | Adaptável para              |
| ----------------------------- | ------------------------- | --------------------------- |
| Espiral de Intensidade        | Escalonamento progressivo | Qualquer processo iterativo |
| Fase de Reconhecimento (5W2H) | Coleta antes de agir      | Qualquer domínio            |
| Catálogo T01-Tn               | Técnicas específicas      | Qualquer expertise          |
| Regras NUNCA/SEMPRE           | Limites comportamentais   | Qualquer identidade         |
| Testes Binários               | Validação objetiva        | Qualquer output             |
| Erros Fatais + Exemplos       | Anti-padrões              | Qualquer atividade          |
| Template Preenchível          | Execução guiada           | Qualquer fluxo              |
| Anti-Identidade               | Diferenciação             | Qualquer agente             |
| Degradação Graciosa           | Resiliência               | Qualquer interação          |
| Protocolo de Iteração         | Correção pós-falha        | Qualquer sistema            |

---

