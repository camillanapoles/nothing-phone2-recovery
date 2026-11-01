# Modo multi-agente, handoff real e template preenchido (seções VII, IX e XII)

> Extraído de `fabrica-de-agentes/SKILL.md` (v2.0, 77 KB) para respeitar o limite de 64 KB do contrato de runtime.
> Conteúdo verbatim, sem edição.

## VII. MODO MULTI-AGENTE (ORQUESTRAÇÃO + HANDOFF REAL)

### Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                    AGENTE ROUTER                         │
│         (Recebe, interpreta, distribui)                 │
└─────────────┬───────────────┬───────────────┬───────────┘
              │               │               │
              ▼               ▼               ▼
     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
     │  AGENTE A    │ │  AGENTE B    │ │  AGENTE C    │
     │  (Criador)   │ │  (Executor)  │ │  (Validador) │
     └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
            │               │               │
            ▼               ▼               ▼
     ┌─────────────────────────────────────────────────┐
     │              AGENTE INTEGRADOR                   │
     │     (Combina outputs, resolve conflitos)        │
     └─────────────────────────────────────────────────┘
```

### Protocolo de Handoff — EXEMPLO REAL (v2.0)

**Cenário:** Sistema de 2 agentes para criação de conteúdo. Agente A (Estrategista) → Agente B (Redator).

```
═══════════════════════════════════════════════════════
HANDOFF: AGENTE A → AGENTE B
═══════════════════════════════════════════════════════

DE: Agente A (Estrategista)
PARA: Agente B (Redator)
TIMESTAMP: [automático]

─── CONTEXTO TRANSFERIDO ───
Tarefa original do usuário: "Criar post para Instagram sobre lançamento de produto X"
Público-alvo identificado: Mulheres 25-35, interesse em sustentabilidade
Tom definido: Inspirador, não-vendedor
Ângulo escolhido: Bastidores do processo de criação

─── OUTPUT PARCIAL DO AGENTE A ───
Estrutura aprovada:
  1. Hook: pergunta provocativa
  2. Corpo: história do processo (3 parágrafos)
  3. CTA: convite suave
Palavras-chave obrigatórias: "feito à mão", "processo", "imperfeito"
Palavras PROIBIDAS: "compre agora", "imperdível", "promoção"

─── RESTRIÇÕES PARA AGENTE B ───
Máximo: 280 palavras
Formato: Legenda de Instagram
Hashtags: 3-5, no final
Emojis: máximo 3

─── CRITÉRIO DE ACEITAÇÃO ───
Agente B deve entregar texto que:
[ ] Contém as 3 palavras-chave
[ ] Não contém palavras proibidas
[ ] Tem entre 250-280 palavras
[ ] Segue estrutura Hook → Corpo → CTA
[ ] Tom inspirador (não vendedor)

─── SE AGENTE B REJEITAR ───
Motivo deve ser especificado.
Agente A revisa em máximo 1 ciclo.
Se 2ª rejeição → escalar ao usuário.

═══════════════════════════════════════════════════════
```

### Protocolo de Comunicação

| Elemento  | Especificação                                                     |
| --------- | ----------------------------------------------------------------- |
| Handoff   | Contexto + output parcial + restrições + critério de aceitação    |
| Conflito  | Router decide com base nos princípios da skill-mãe                |
| Rejeição  | Agente validador especifica MOTIVO. Devolve com correção sugerida |
| Iteração  | Máximo 3 ciclos entre agentes antes de escalar ao usuário         |
| Formato   | Todo handoff segue o template acima                               |
| Escalação | Se 3 ciclos falham → usuário decide                               |

### Template Multi-Agente

```
═══════════════════════════════════════════════════════
SISTEMA MULTI-AGENTE
═══════════════════════════════════════════════════════

NOME DO SISTEMA: _______________
DOMÍNIO: _______________
QUANTIDADE DE AGENTES: ___

─── AGENTE 1: _______________ ───
FUNÇÃO:
ESPECIALIDADE:
INPUT QUE RECEBE:
OUTPUT QUE PRODUZ:
REGRAS ESPECÍFICAS:
CRITÉRIO DE HANDOFF PARA PRÓXIMO:

─── AGENTE 2: _______________ ───
FUNÇÃO:
ESPECIALIDADE:
INPUT QUE RECEBE:
OUTPUT QUE PRODUZ:
REGRAS ESPECÍFICAS:
CRITÉRIO DE REJEIÇÃO:

─── PROTOCOLO DE ORQUESTRAÇÃO ───
ORDEM DE EXECUÇÃO:
CRITÉRIO DE HANDOFF:
CRITÉRIO DE REJEIÇÃO:
MÁXIMO ITERAÇÕES: 3
RESOLUÇÃO DE CONFLITO:
ESCALAÇÃO:

═══════════════════════════════════════════════════════
```

---

## IX. TEMPLATE OPERACIONAL DE SAÍDA (PREENCHIDO — v2.0)

### Template vazio + Exemplo preenchido

**EXEMPLO PREENCHIDO** (Agente Padeiro — domínio: Panificação):

```
═══════════════════════════════════════════════════════════
FICHA DE EXECUÇÃO — AGENTE: FORNO & MÃO
═══════════════════════════════════════════════════════════

DATA: 2025-01-15
USUÁRIO: Iniciante, forno doméstico, sem balança

─── ENTRADA ───
DEMANDA: "Quero fazer pão doce recheado com goiabada"
RESTRIÇÕES: Forno doméstico. Sem balança. 3 horas disponíveis.
NÍVEL: Iniciante absoluto.

─── PROCESSAMENTO ───
RECEITA SELECIONADA: Pão doce básico com recheio
TÉCNICAS APLICADAS: T01 (Janela), T02 (Dedo), T03 (Forno), T04 (Modelagem), T05 (Conversão)
ERROS ANTECIPADOS: Água quente / Sova insuficiente / Recheio vazando
PONTOS DE NÃO-RETORNO: Entrada no forno / Fermentação excessiva

─── SAÍDA ───
FORMATO: Passo-a-passo com checkpoints sensoriais
ACOMPANHA: Tabela de conversão + Checklist pré-forno + Troubleshooting
PRÓXIMO PASSO SUGERIDO: "Na próxima, tente baunilha na massa"

─── VALIDAÇÃO ───
[✓] Receita executável com forno doméstico
[✓] Tempos em faixas (não exatos)
[✓] Checkpoint sensorial em cada fase crítica
[✓] 3 erros antecipados
[✓] Alternativa sem balança
[✓] PORQUÊ explicado em cada etapa
[✓] Técnica anti-vazamento incluída
[✓] Pré-aquecimento explícito

─── AVALIAÇÃO PÓS-EXECUÇÃO ───
USUÁRIO CONSEGUIU EXECUTAR? [ ] Sim [ ] Não
ONDE TRAVOU? _______________
AJUSTE PARA PRÓXIMA: _______________

═══════════════════════════════════════════════════════════
```

---

## XII. EXEMPLOS DE APLICAÇÃO

| Solicitação                               | Agente Gerado                                           | Modo      |
| ----------------------------------------- | ------------------------------------------------------- | --------- |
| "Agente dev Android via Termux"           | Skill com CLI, pacotes, compilação em ambiente limitado | Único     |
| "Agente padeiro de pão doce"              | Skill com fermentação, proporções, troubleshooting      | Único     |
| "Agente marketeiro de redes sociais"      | Skill com copy, calendário, métricas, A/B               | Único     |
| "Agente roteirista + Agente revisor"      | Multi-agente com handoff e critério de rejeição         | Multi (2) |
| "Sistema de criação de conteúdo completo" | Router + Estrategista + Redator + Designer + Validador  | Multi (5) |
| "Agente que cria agentes"                 | Meta-Skill aplicada a si mesma (recursão)               | Router    |

---

