#!/usr/bin/env python3
"""
APEX TALENT BROKER — Opportunity Harvester & Scoring Daemon (CLI)
Executa varredura de Bounties (GitHub/Algora), feeds remotos e avalia
oportunidades segundo a Matriz Multidimensional (Hard + Soft + Liquidez + Flywheel).
"""

import argparse
import json
import urllib.request
import urllib.parse
from dataclasses import dataclass, asdict
from typing import List, Dict

# Grafo de Competencias Hibridas da Usuaria (Pesos de Assimetria)
SKILL_WEIGHTS: Dict[str, float] = {
    # Hard Skills (Engenharia de Software, IA & Hardware)
    "fastapi": 1.5,
    "multi-agent": 2.0,
    "mcp": 2.0,
    "context engineering": 2.0,
    "langgraph": 1.8,
    "pydantic": 1.4,
    "python": 1.2,
    "rag": 1.5,
    "computer vision": 1.6,
    "neural networks": 1.5,
    "linux": 1.2,
    "nix": 1.4,
    "mechanical": 1.5,
    "cfd": 1.6,
    # Soft & Executive Skills (Gestao, Politicas Publicas & Inovacao)
    "design thinking": 1.8,
    "unesco": 2.2,
    "grant": 1.9,
    "r&d": 1.7,
    "healthtech": 1.9,
    "dental": 2.0,
    "clinical": 1.7,
    "strategy": 1.5,
    "architecture": 1.7,
    "cto": 1.8,
    "audit": 1.6,
}

FLYWHEEL_TRIGGERS = ["urgent", "quick", "bug", "fix", "hotfix", "audit", "review", "bounty", "immediate"]


@dataclass
class Opportunity:
    title: str
    url: str
    source: str
    reward_usd: float
    est_hours_with_ai: float
    prob_close: float
    ehv_usd_hr: float = 0.0
    flywheel_bonus: float = 0.0
    hybrid_bonus: float = 0.0
    total_score: float = 0.0
    horizon: str = "H2"
    recommended_action: str = ""


def score_opportunity(opp: Opportunity, description: str = "") -> Opportunity:
    text = f"{opp.title} {description}".lower()

    # 1. Expected Hourly Value (EHV)
    opp.ehv_usd_hr = round((opp.reward_usd * opp.prob_close) / max(opp.est_hours_with_ai, 0.5), 2)

    # 2. Reputation Flywheel Bonus (Micro-projetos < 2.5h para ganhar 5 estrelas rapido)
    trigger_hits = sum(1 for t in FLYWHEEL_TRIGGERS if t in text)
    if opp.est_hours_with_ai <= 2.5 and opp.reward_usd >= 50:
        opp.flywheel_bonus = min(25.0, 10.0 + (trigger_hits * 5.0))

    # 3. Hybrid Skill Monopoly Bonus
    matched_weights = [w for kw, w in SKILL_WEIGHTS.items() if kw in text]
    opp.hybrid_bonus = round(min(30.0, sum(matched_weights) * 4.5), 1)

    # 4. Score Final Normalizado (0 - 100)
    ehv_Points = min(45.0, (opp.ehv_usd_hr / 100.0) * 45.0)
    opp.total_score = round(min(100.0, ehv_Points + opp.flywheel_bonus + opp.hybrid_bonus), 1)

    # Classificacao de Horizonte e Acao
    if opp.est_hours_with_ai <= 2.5 and opp.flywheel_bonus >= 15.0:
        opp.horizon = "H1/H2 (Flywheel 5* + Caixa Rapido)"
        opp.recommended_action = "T03 (Sprint Reputacao) + T04 (Enviar patch/diagnostico na abordagem)"
    elif opp.reward_usd >= 800:
        opp.horizon = "H3 (Alto Ticket / Arquitetura)"
        opp.recommended_action = "T04 (Blueprint Mermaid) + T05 (Fractional/Milestone 50-50)"
    else:
        opp.horizon = "H2 (Engajamento Tatico)"
        opp.recommended_action = "Avaliar se cliente tem historico >50% hire rate antes de aplicar"

    return opp


def fetch_github_bounties(query: str = "label:bounty state:open language:python", limit: int = 10) -> List[Opportunity]:
    """Busca issues abertas com label de recompensa/bounty via API publica do GitHub."""
    encoded_q = urllib.parse.quote(query)
    url = f"https://api.github.com/search/issues?q={encoded_q}&sort=created&order=desc&per_page={limit}"
    req = urllib.request.Request(url, headers={"User-Agent": "ApexTalentBroker/2.0"})
    opportunities: List[Opportunity] = []

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for item in data.get("items", []):
                title = item.get("title", "")
                html_url = item.get("html_url", "")
                body = item.get("body") or ""
                # Estimativa conservadora padrao para triagem de bounty
                opp = Opportunity(
                    title=title,
                    url=html_url,
                    source="GitHub Bounty",
                    reward_usd=150.0,
                    est_hours_with_ai=2.0,
                    prob_close=0.65,
                )
                opportunities.append(score_opportunity(opp, body))
    except Exception as exc:
        print(f"[WARN] Falha na coleta GitHub API ({exc}). Use 'gh search issues' localmente.")

    return sorted(opportunities, key=lambda x: x.total_score, reverse=True)


def generate_boolean_dorks() -> Dict[str, str]:
    """Retorna queries cirurgicas para execucao imediata em plataformas."""
    return {
        "Upwork_Flywheel_Fast_5Star": (
            '("FastAPI" OR "LangGraph" OR "Multi-agent" OR "MCP" OR "Pydantic" OR "RAG") '
            'AND ("bug" OR "urgent" OR "fix" OR "audit" OR "architecture")'
        ),
        "Upwork_HighTicket_Advisory": (
            '("AI Architect" OR "Context Engineering" OR "Grant" OR "R&D" OR "HealthTech" OR "Design Thinking") '
            'AND ("consultant" OR "strategy" OR "blueprint" OR "MVP")'
        ),
        "GitHub_CLI_Bounties": (
            'gh search issues --state=open --label="bounty" "python OR fastapi OR agent OR llm" --limit 20'
        ),
        "LinkedIn_Direct_DecisionMakers": (
            'site:linkedin.com/posts ("buscando consultor" OR "looking for AI architect" OR "edital FINEP" OR "subvenção" OR "multi-agent")'
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Apex Talent Broker CLI")
    parser.add_argument("--scan-github", action="store_true", help="Varre bounties abertos no GitHub")
    parser.add_argument("--dorks", action="store_true", help="Exibe queries booleanas de alta conversao")
    parser.add_argument("--eval", type=str, help="Avalia um projeto JSON: '{\"title\":..., \"reward\":200, \"hours\":1.5}'")
    args = parser.parse_args()

    if args.dorks:
        print("=== QUERIES BOOLEANAS DE ALTA ASSIMETRIA ===")
        for k, v in generate_boolean_dorks().items():
            print(f"\n[{k}]\n  {v}")

    if args.eval:
        payload = json.loads(args.eval)
        opp = Opportunity(
            title=payload.get("title", "Custom Opportunity"),
            url=payload.get("url", "N/A"),
            source=payload.get("source", "Manual"),
            reward_usd=float(payload.get("reward", 100)),
            est_hours_with_ai=float(payload.get("hours", 2.0)),
            prob_close=float(payload.get("prob", 0.7)),
        )
        scored = score_opportunity(opp, payload.get("desc", ""))
        print(json.dumps(asdict(scored), indent=2, ensure_ascii=False))

    if args.scan_github:
        print("=== VARREDURA DE BOUNTIES TECNICAS (GITHUB) ===")
        results = fetch_github_bounties()
        for r in results[:5]:
            print(f"[{r.total_score}/100] {r.title} | EHV: US${r.ehv_usd_hr}/h | {r.horizon}\n  -> {r.url}\n  -> Acao: {r.recommended_action}\n")


if __name__ == "__main__":
    main()
