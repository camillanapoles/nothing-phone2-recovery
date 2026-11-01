# Validação em 12 testes binários, erros fatais, fluxo condicional e iteração pós-falha (seções VIII, X, XI e XIII)

> Extraído de `fabrica-de-agentes/SKILL.md` (v2.0, 77 KB) para respeitar o limite de 64 KB do contrato de runtime.
> Conteúdo verbatim, sem edição.

## VIII. VALIDAÇÃO DA SKILL GERADA — 12 TESTES BINÁRIOS (v2.0)

| #   | Teste                  | Critério de PASS                                                                                                         | Critério de FAIL                  | Se FAIL → Ação                                      |
| --- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------------------------- | --------------------------------------------------- |
| 1   | **Especificidade**     | Troque o nome do domínio. A skill ainda faz sentido? Se NÃO → PASS. Se SIM → FAIL.                                       | Skill serve para qualquer domínio | Refazer Fase 1 com mais especificidade              |
| 2   | **Operacionalidade**   | Dá pra executar a tarefa MAIS simples do domínio usando APENAS a skill, sem buscar info externa? SIM → PASS. NÃO → FAIL. | Precisa de info externa           | Adicionar detalhes na Fase 3                        |
| 3   | **Completude**         | Todos os 15 itens do checklist (Seção VI) estão presentes? SIM → PASS. NÃO → FAIL.                                       | Itens faltando                    | Completar antes de entregar                         |
| 4   | **Coerência**          | Existe alguma regra NUNCA que contradiz uma regra SEMPRE? NÃO → PASS. SIM → FAIL.                                        | Contradição interna               | Resolver conflito. Uma das regras deve ser removida |
| 5   | **Escalabilidade**     | A skill funciona para a tarefa mais simples E a mais complexa do domínio? SIM → PASS. NÃO → FAIL.                        | Só funciona em um nível           | Adicionar níveis de complexidade                    |
| 6   | **Anti-padrões reais** | Cada erro fatal tem exemplo concreto? SIM → PASS. NÃO → FAIL.                                                            | Erros abstratos                   | Adicionar exemplo para cada                         |
| 7   | **Testes mensuráveis** | Cada teste de validação tem critério binário explícito? SIM → PASS. NÃO → FAIL.                                          | Testes subjetivos                 | Reescrever com PASS/FAIL                            |
| 8   | **Identidade única**   | Leia 3 frases do agente. Dá pra identificar o domínio sem ver o título? SIM → PASS. NÃO → FAIL.                          | Agente genérico                   | Reforçar tom e vocabulário                          |
| 9   | **Modularidade**       | Remova 1 técnica. O resto ainda funciona? SIM → PASS. NÃO → FAIL.                                                        | Acoplamento excessivo             | Desacoplar                                          |
| 10  | **Multi-agente**       | Se decomposto em 2 agentes, cada um funciona sozinho? SIM → PASS. NÃO → FAIL.                                            | Dependência circular              | Redefinir fronteiras                                |
| 11  | **Stress test**        | A tarefa MAIS difícil do domínio (definida na Fase 0, campo 11) é coberta pela skill? SIM → PASS. NÃO → FAIL.            | Skill quebra no extremo           | Adicionar técnica ou regra para o caso extremo      |
| 12  | **Auto-suficiência**   | Um usuário que NUNCA viu o domínio consegue usar a skill sem tutorial externo? SIM → PASS. NÃO → FAIL.                   | Precisa de conhecimento prévio    | Adicionar contexto na Fase 1                        |

**Regra:** Se 3 ou mais testes FAIL → skill NÃO é entregue. Retorna ao Protocolo de Iteração (Seção XIII).

---

## X. ERROS FATAIS NA GERAÇÃO (v2.0 com exemplos)

| #   | Erro                           | Por quê é fatal                        | Exemplo concreto                                                              | Correção                                      |
| --- | ------------------------------ | -------------------------------------- | ----------------------------------------------------------------------------- | --------------------------------------------- |
| 1   | Gerar sem coleta               | Skill genérica                         | Criar skill de "marketing" sem saber se é digital, de conteúdo, ou de produto | Sempre Fase 0                                 |
| 2   | Técnica sem exemplo            | Abstração inútil                       | "Use a técnica de ancoragem" sem mostrar como                                 | Todo T tem INPUT/AÇÃO/OUTPUT                  |
| 3   | Testes subjetivos              | Não dá pra validar                     | "O tom está bom?" → bom pra quem?                                             | "O tom contém 0 palavras irônicas? PASS/FAIL" |
| 4   | Sem anti-padrões               | Erros evitáveis                        | Agente de código que não menciona "nunca commitar senha"                      | Mínimo 7 erros fatais                         |
| 5   | Multi-agente sem handoff       | Agentes se contradizem                 | Agente A diz "tom formal", Agente B escreve gírias                            | Template de handoff obrigatório               |
| 6   | Identidade genérica            | Indistinguível                         | "Sou um assistente prestativo"                                                | Filosofia + anti-identidade                   |
| 7   | Sem ponto de não-retorno       | Usuário não sabe quando é tarde demais | Padeiro que não avisa "depois que entra no forno, não dá pra tirar"           | Marcar explicitamente                         |
| 8   | Sem degradação graciosa        | Agente trava                           | Usuário pergunta algo fora do escopo e agente não responde                    | "Não é meu domínio, mas posso sugerir..."     |
| 9   | Skill longa sem fluxo resumido | Usuário se perde                       | 50 seções sem resumo                                                          | Sempre incluir fluxo 1-linha                  |
| 10  | Sem iteração pós-falha         | Beco sem saída                         | Skill falha no teste e não há o que fazer                                     | Protocolo de 3 ciclos                         |

---

## XI. FLUXO CONDICIONAL DETALHADO (v2.0)

```
INÍCIO
│
├─→ Usuário forneceu 11 campos?
│   ├─ SIM → Ir para FASE 1
│   ├─ PARCIAL (6-10) → Perguntar máx 3 → FASE 1
│   ├─ MÍNIMO (1-5) → Defaults + [MARCAR SUPOSIÇÕES] → FASE 1
│   └─ NENHUM → Modo Entrevista (5 perguntas) → FASE 1
│
├─→ FASE 1: Reconhecimento
│   ├─→ Domínio conhecido? → Prosseguir
│   └─→ Domínio desconhecido? → Degradação Graciosa (Seção XIV)
│
├─→ FASE 2-8: Construção
│   └─→ Cada fase gera output → próxima fase consome
│
├─→ FASE 9: Validação (12 testes)
│   ├─→ 0-2 FAIL → Corrigir pontualmente → Entregar
│   ├─→ 3-5 FAIL → Protocolo de Iteração (Seção XIII)
│   └─→ 6+ FAIL → REFAZER do zero (Fase 1)
│
├─→ Multi-agente?
│   ├─ SIM → Gerar cada agente + protocolo de handoff + validar integração
│   └─ NÃO → Agente único
│
├─→ Stress test passou?
│   ├─ SIM → Entregar
│   └─ NÃO → Adicionar técnica/regra para caso extremo → Revalidar
│
└─→ ENTREGA FINAL
    ├─→ Skill completa
    ├─→ Exemplo de execução
    ├─→ Template preenchido
    └─→ Instrução de uso
```

---

## XIII. PROTOCOLO DE ITERAÇÃO PÓS-FALHA (v2.0 NOVO)

### Quando a skill gerada FALHA na validação:

```
╔═══════════════════════════════════════════════════╗
║           PROTOCOLO DE ITERAÇÃO                  ║
╠═══════════════════════════════════════════════════╣
║                                                 ║
║  CICLO 1: CORREÇÃO PONTUAL                      ║
║  → Identificar quais testes falharam            ║
║  → Corrigir APENAS os itens falhos              ║
║  → Revalidar                                    ║
║  → Se PASS → Entregar                           ║
║  → Se FAIL → Ciclo 2                            ║
║                                                 ║
║  CICLO 2: REESTRUTURAÇÃO PARCIAL                ║
║  → Reescrever a fase que originou o erro        ║
║  → Verificar impacto nas fases seguintes        ║
║  → Revalidar                                    ║
║  → Se PASS → Entregar                           ║
║  → Se FAIL → Ciclo 3                            ║
║                                                 ║
║  CICLO 3: RECONSTRUÇÃO                          ║
║  → Voltar à Fase 1                              ║
║  → Reconsiderar premissas                       ║
║  → Reconstruir com abordagem diferente          ║
║  → Revalidar                                    ║
║  → Se PASS → Entregar                           ║
║  → Se FAIL → ESCALAR AO USUÁRIO                ║
║    "A skill não atinge o critério.             ║
║     Motivo: ___. Sugestão: ___."                ║
║                                                 ║
║  MÁXIMO: 3 ciclos. Nunca mais.                  ║
║                                                 ║
╚═══════════════════════════════════════════════════╝
```

---

