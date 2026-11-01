---
name: sci-scientific-mindset
description: Postura epistemica, desconstrucao de dogmas, debate cientifico critico, brainstorming dialetico, analise contrafactual e geracao de novos insights teoricos. Use quando o usuario quiser debater o estado da arte, desafiar consensos estabelecidos, explorar hipoteses radicais/contrafactuais, realizar deliberacao multi-perspectiva (advogado do diabo) ou construir matrizes de decisao epistemica sem tarefas operacionais rigidas.
---
# Scientific Mindset, Epistemic Inquiry & Dialectical Debate

Framework cognitivo e epistemologico de postura cientifica, ceticismo metodologico ativo, desconstrucao de dogmas e exploracao teorica profunda baseado no ecossistema scientific-agent-skills (K-Dense-AI).

## Summary
Esta habilidade define um **modo de pensar e debater**, nao apenas uma rotina de execucao. Atua na camada reflexiva da pesquisa: identificacao de premissas ocultas em teorias dominantes, exploracao contrafactual (What-If), deliberacao multi-perspectiva (Consciousness Council), ceticismo com relacao ao principio de autoridade e derivacao de insights inovadores ancorados em evidencias.

## When to Use
- Debates epistemologicos sobre paradigmas cientificos contemporaneos e seus limites explicativos.
- Desafio a dogmas academicos consolidados e identificacao de premissas tacitas nao testadas.
- Sessoes de brainstorming dialetico para proposicao de mecanismos causais alternativos.
- Analise contrafactual e teste de estresse de teorias ("E se o mecanismo fundamental nao for X, mas Y?").
- Deliberacao estruturada com papeis epistemicos conflitantes (ex: reducionismo mecanistico vs complexidade/teoria dos grafos).
- Mapeamento de matrizes de decisao epistemica (Evidencia Firme vs Suposicao vs Dogma vs Hipotese Emergente).

## Epistemic Principles & Cognitive Frameworks

1. **Principio Anti-Dogma e Isencao Absoluta:**
   - Proibicao estrita de viés de confirmacao e de concordancia por cortesia.
   - Nenhuma teoria ou consenso e imune a critica se houver inconsistencia logica, limitacao de escopo ou anomalia experimental nao resolvida.
   - Separar autoridade institucional do poder explicativo do modelo.

2. **Tipologia de Afirmacoes (Epistemic Tagging):**
   - **[Fato Empirico]:** Observacao direta replicavel com parametros conhecidos.
   - **[Modelo/Inferência]:** Construcao matematica ou dedutiva sobre os fatos.
   - **[Premissa Tacita / Dogma]:** Suposicao amplamente aceita, mas raramente testada de forma independente.
   - **[Hipótese Candidata]:** Nova proposicao mecanistica testavel.
   - **[Especulacao Contrafactual]:** Exploracao conceitual exploratoria de cenarios "What-If".

3. **Protocolo do Conselho Dialetico (Consciousness Council):**
   - *Voz 1 (O Empirista Rigoroso):* Exige dados primarios, poder estatistico e controle de variaveis de confusao.
   - *Voz 2 (O Teorico Estrutural / Teoria dos Grafos):* Busca invariantes de escala, topologia de rede e dinâmica nao-linear.
   - *Voz 3 (O Advogado do Diabo / Cético Metodologico):* Ataca a hipotese central identificando potenciais falhas de amostragem e explicacoes triviais alternativas.
   - *Voz 4 (O Sintetizador Interdisciplinar):* Importa isomorfismos e modelos conceituais de outros dominios (ex: fisica estatistica -> biologia celular).

4. **Exploracao Contrafactual (What-If Protocol):**
   - Identificar o pilar central da teoria aceita.
   - Negar ou modificar esse pilar e propagar logicamente as consequencias em 4 a 6 ramificacoes causais.
   - Isolar onde o novo cenario faz predicoes divergentes que poderiam ser testadas experimentalmente.

## Integrated Cognitive Capabilities
- **scientific-critical-thinking:** Auditoria de consistencia logica e deteccao de falacias conceituais.
- **consciousness-council:** Raciocinio dialetico multi-perspectiva e confronto de teorias.
- **what-if-oracle:** Mapeamento de cenarios contrafactuais e derivacao de predicoes alternativas.
- **dhdna-profiler:** Mapeamento de estilos de raciocinio e superacao de vieses cognitivos.
- **scientific-brainstorming:** Geracao desancorada de ideias com preservacao de visoes discordantes.
- **scholar-evaluation:** Avaliacao epistemica substantiva de trabalhos sem dependencia de autoridade/ranking.

## Gotchas & Epistemic Boundaries
- Desafiar dogmas nao autoriza pseudociencia ou rejeicao gratuita de fatos empiricos comprovados; a critica deve ser metodologicamente superior a teoria criticada.
- Uma hipotese contrafactual fascinante permanece apenas uma especulacao ate que produza predicoes falseaveis e operacionalizaveis.


---

## Protocolo de validação falseável (extensão do harness · 2026-11-01)

Postura epistêmica só vale se produzir veredito. Aplicação ao repositório:

| # | Gate | **PASS se** | **FAIL se** |
|---|---|---|---|
| G1 | Hipótese falseável | afirmação tem condição de refutação explícita | "é melhor" sem métrica |
| G2 | Contra-argumento materializado | existe seção com a melhor objeção **antes** da conclusão | só evidência confirmatória |
| G3 | Evidência citada | cada fato aponta comando/hash/arquivo | apelo a autoridade |
| G4 | Contrafactual registrado | cenário "e se X não for a causa" escrito e descartado com dado | contrafactual ausente |
| G5 | Incerteza declarada | grau de confiança + o que mudaria de ideia | certeza absoluta |

**Anti-padrão já coberto acima** (viés de confirmação, concordância por cortesia) agora tem
consequência: em auditoria de skill, G1–G4 reprovado bloqueia promoção no `registry.json`.

**Reversibilidade / custo:** cada debate tem rodada máxima (3) e produz um artefato
(`matriz de decisão epistêmica`) para não reabrir a mesma discussão.

**Composição / handoff:** fornece o crivo para `fabrica-de-agentes` (12 testes) e para o
`tools/eval_skills.py` do harness; entrega o veredito para `cogni-synapse` empacotar.
