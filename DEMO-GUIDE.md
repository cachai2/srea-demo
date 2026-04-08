# Azure SRE Agent — LevelUp Demo Spec

**Session:** Azure SRE Agent GA Features LevelUp  
**Date:** April 7, 2026  
**Runtime:** ~32 min (fits 45-min slot with 13 min buffer for delays + Q&A)  
**Audience:** SREs, platform engineers, IT decision-makers (Microsoft field + engineering)

---

## One-Line Pitch

> **Short (opening):** "Azure SRE Agent gets smarter as you invest in it — from catching errors to following your runbooks to acting autonomously with guardrails."
>
> **Full (closing):** "Watch the same agent go from 'I found a 500' to 'I matched your known pattern, followed your runbook, scaled your pods within policy, and found a cert nobody knew was expiring.' All you added was one trigger, one skill, one hook, one task."

---

## The Story

Instead of showing three independent triggers finding three independent bugs, we show **one agent getting smarter as you invest in it**. Each layer is ~5 minutes of config with a visible payoff. The audience sees compounding value — and it mirrors real customer adoption.

| Layer | What you add | What improves | Mirrors adoption |
|-------|-------------|---------------|------------------|
| 0. Bare agent | Connect resources | Knows your infra | Phase 1 |
| 1. + Trigger | HTTP Trigger from CI/CD | Catches 500s, generic investigation | Phase 2 |
| 2. + Skill | order-api-runbook | Same bug → known pattern, runbook, right team paged | Phase 3 |
| 3. + Hook | Scaling guardrail | Incident trigger scales pods, hook enforces max 10 | Phase 4 |
| 4. + Scheduled Task | Daily security scan | Finds cert expiry + injection probes — no alerts needed | Phase 4 |

**Why this structure works:**
- **ROI at each step** — each layer is an incremental investment with a visible payoff
- **The skill toggle is THE demo** — Layer 1 → Layer 2 is the single most impactful transition
- **Mirrors real adoption** — nobody deploys all features day 1
- **Natural escalation of trust** — bare → read-only → knowledge → write access with guardrails → autonomous

---

## GA Features Covered

| Feature | Layer | Where it appears | How it's shown |
|---------|-------|-----------------|----------------|
| HTTP Triggers | 1 | Act 2 (core) | Live: pipeline fires post-deploy subagent |
| Skills | 2 | Act 3 (core) | Live: add skill on stage → before/after response contrast |
| Incident Triggers | 3 | Act 4 (core) | Pre-run: walk through completed overnight investigation |
| Hooks | 3 | Act 4 (guardrail) | Show: audit log + rejection message from scaling hook |
| Scheduled Tasks | 4 | Act 5 (core) | Pre-run: walk through morning scan results |
| Workspace Mode | 2 | Act 3 (mentioned) | Talk-through: enables skills, sandbox, file ops |
| Subagent Builder | 1 | Act 2 (YAML shown) | Show once, reference in Acts 4/5 |
| Review vs Autonomous | 3 | Act 4 (mentioned) | Talk-through: trust dial |

---

## Demo Structure

### Act 1: "Meet Your Agent" — Layer 0 (1 min)

| Aspect | Detail |
|--------|--------|
| **Goal** | Orient the audience to the portal and agent |
| **Live or pre-run?** | Pre-created agent, 30-second portal tour |
| **Key moment** | Show the agent is monitoring Container App, App Insights, Key Vault, Log Analytics |
| **Features** | Agent creation (mentioned, not shown) |
| **Risk** | None — just showing a working agent |

### Act 2: "It Catches Errors" — Layer 1: + Trigger (5 min)

| Aspect | Detail |
|--------|--------|
| **Goal** | Show post-deploy validation — generic investigation without skill |
| **Live or pre-run?** | **LIVE** — this runs on stage |
| **Business impact** | Pipeline caught a bug that would have been a customer-facing 500 within minutes of deploy |
| **Key moment** | App Insights exception → `get_order` function in `app.py` (telemetry-to-code) |
| **The gap** | Response is generic — "'NoneType' object has no attribute 'get' in `get_order`, consider null check." No known pattern, no escalation, no team paged. Audience should feel what’s missing. |
| **Features** | HTTP Trigger, Subagent YAML |
| **Bug** | Null deref on `/orders/999` → 500 |
| **Subagent** | `PostDeployValidator` (Reader access) |
| **Risk** | Medium — live agent behavior is probabilistic |
| **Fallback** | Invoke subagent in Playground. If agent fails, narrate + screenshot. |

### Act 3: "Now It Knows Your App" — Layer 2: + Skill (5 min)

| Aspect | Detail |
|--------|--------|
| **Goal** | Add skill live → re-run same trigger → show before/after contrast |
| **Live or pre-run?** | **LIVE** — add skill + re-run on stage |
| **Business impact** | Same bug, but now the right team is paged in minutes — not hours of triage |
| **Key moment** | Same bug, but now: known pattern matched, runbook followed, right team paged |
| **This is THE demo** | The single most impactful transition. Let it breathe. |
| **Features** | Skills (live toggle), Workspace Mode |
| **Skill** | `order-api-runbook` — known patterns, remediation, escalation policy |
| **Risk** | Medium — skill might not load on first try |
| **Fallback** | Mention skill by name in prompt. If still fails, show screenshot of skilled response. |
| **Hot-reload** | After adding skill, ask *"What skills do you have?"* to verify it loaded (~10s async refresh). Don't re-run immediately. |
| **Dependency** | Act 2 must produce the generic response first for contrast. If Act 2 fails live, show screenshot of generic response then proceed to Act 3 live. |

### Act 4: "It Acts, With Guardrails" — Layer 3: + Hook (10 min)

| Aspect | Detail |
|--------|--------|
| **Goal** | Show autonomous overnight mitigation AND hook guardrails |
| **Live or pre-run?** | **PRE-RUN** — walk through completed investigation |
| **Business impact** | No pager, no war room at 2 AM — agent mitigated, $0 in downtime cost |
| **Key moment #1** | Agent detected elevated latency, identified slow endpoint, scaled pods from 1→5 to absorb load |
| **Key moment #2** | Hook audit log shows "within policy" + rejection message for over-limit |
| **Key one-liner** | *"Skills teach it what to do. Hooks enforce what it can't."* |
| **Features** | Incident Trigger, Hooks (command hook — deterministic, not LLM-evaluated), Review vs Autonomous |
| **Bug** | Sequential per-row processing on `/slow` → 5s p95 latency under EU load |
| **Subagent** | `LatencyIncidentHandler` (Contributor on Container App resource only — not the resource group) |
| **Hook** | `sre-config/scaling-guardrail.py` — max 10 replicas |
| **Risk** | Medium — depends on incident trigger having fired overnight |
| **Fallback** | Invoke subagent in Playground. Show YAML + narrate. Screenshot of prior run. |

### Act 5: "It Finds What You're Not Looking For" — Layer 4: + Scheduled Task (8 min)

| Aspect | Detail |
|--------|--------|
| **Goal** | Show proactive security scanning for issues with no runtime symptoms |
| **Live or pre-run?** | **PRE-RUN** — walk through morning scan results (or Run Now) |
| **Business impact** | Cert expiry would have been a full outage in ~30 days. Agent caught it proactively. |
| **Layer-added moment** | Briefly say: *"I set this up yesterday — one cron schedule, one subagent, same pattern you've seen. That's Layer 4."* |
| **Key moment** | Agent finds cert expiring in ~30 days (primary) + SQL injection attempts in logs (bonus — depends on log data), creates GitHub issues for both |
| **Features** | Scheduled Tasks |
| **Bugs** | Key Vault cert expiring in ~30 days (primary), SQL injection probes in App Insights logs (secondary) |
| **Subagent** | `DailySecurityScan` (Reader access) |
| **Risk** | Medium — depends on agent actually finding both issues |
| **Fallback** | Click Run Now. If too slow or wrong results, show screenshot of prior run. |

### Closing (3 min)

| Aspect | Detail |
|--------|--------|
| **Goal** | Recap the four layers + clear adoption path |
| **Key line** | *"All you added was one trigger, one skill, one hook, one task."* |
| **CTA** | sre.azure.com — Phase 1: create agent. Phase 2: add trigger. Phase 3: write skill. Phase 4: add hook + scheduled scan. Go at your own pace. |
| **QR code** | Link to getting-started guide or samples repo |

---

## The App

**Name:** order-api  
**Stack:** Python/Flask + OpenTelemetry  
**Hosting:** Azure Container Apps  
**Monitoring:** Application Insights + Log Analytics  
**Repo:** GitHub (connected via SRE Agent resource mapping)

### Planted bugs

| # | Endpoint | Bug | Exception / Status | Why it's planted |
|---|----------|-----|--------------------|------------------|
| 1 | `/orders/999` | Null dereference — `order.get("item")` on `None` | `AttributeError: 'NoneType' object has no attribute 'get'` (500) | Act 2: pipeline catches errors |
| 2 | `/slow` | Sequential processing — `for` loop with `time.sleep(0.5)` per row | 200 (slow) | Act 4: latency under EU load — agent detects + mitigates (not deep dependency tracing; `time.sleep` doesn't produce DB dependency telemetry) |
| 3 | `/orders?status=x` | SQL injection — f-string interpolation of user input into query | 200 | Act 5: agent finds injection probes in App Insights request logs |
| 4 | `/health` | Secret leak — connection string with password logged at INFO | 200 | (Bug still exists but not demoed — caught by CI/CD SAST tools) |
| 5 | Key Vault cert | `order-api-tls` self-signed cert expires in ~30 days | N/A | Act 5: agent checks Key Vault cert expiry |

### Key app detail

The `/` endpoint returns `{"service": "order-api", "version": "1.2.0", "deployed_at": "<UTC timestamp>"}`. The `deployed_at` is captured at container startup, giving the agent a deployment timestamp to correlate with error spikes. **Ensure container image tag is `1.2.0` (not `latest`)** so the agent can say "new deployment of v1.2.0 at 4:03 PM" and the Container Apps revision name includes the version.

---

## Artifacts

| File | Purpose | Used in |
|------|---------|---------|
| `sample-app/app.py` | Flask API with 4 planted bugs | All acts |
| `sre-config/incident-error-handler.yaml` | PostDeployValidator subagent (Reader) | Acts 2-3 |
| `sre-config/latency-incident-handler.yaml` | LatencyIncidentHandler subagent (Contributor) | Act 4 |
| `sre-config/scheduled-health-check.yaml` | DailySecurityScan subagent (Reader) | Act 5 |
| `sre-config/scaling-guardrail.py` | Max 10 replicas guardrail (paste into portal hook editor) | Act 4 |
| `sre-config/order-api-runbook/SKILL.md` | Known patterns, remediation, escalation | Act 3 |
| `sre-config/order-api-runbook/skill.yaml` | Skill definition | Act 3 |
| `infra/main.bicep` | ACR + Container App + App Insights + Key Vault + Alert Rules | Setup |
| `scripts/generate-errors.ps1` | Generate telemetry: 500s, `/slow` latency, SQL injection probes | Setup |
| `scripts/generate-errors.sh` | Generate telemetry (Linux/macOS) | Setup |

---

## Permissions Architecture

| Component | Access level | Why |
|-----------|-------------|-----|
| Interactive agent | **Reader** | Safe default — investigate, don't change |
| PostDeployValidator | **Reader** | Find bugs, file issues — don't roll back |
| LatencyIncidentHandler | **Contributor** (Container App resource only) | Needs to scale Container App replicas |
| DailySecurityScan | **Reader** | Source search + log analysis only |
| Scaling guardrail hook | — | Enforces max 10 replicas regardless of access |

**Narrative:** *"Contributor access scoped to the automation that needs it. The agent you chat with is still read-only. And hooks enforce what even Contributor agents can do."*

---

## Key Talking Points (weave in, don't bullet-dump)

- *"Each layer is 5 minutes of config with a visible payoff."*
- *"Skills teach it what to do. Hooks enforce what it can't."*
- *"Platform team sets hooks. Service teams write skills."*
- *"Same bug, same agent — but now it follows our runbook, not generic best practices."*
- *"That's the difference between AI and YOUR AI."*
- *"A cert expires in 30 days. No alert fires. In 30 days, your app is down."*
- *"Someone is probing your API with SQL injection. Every request returned 200. Only a log scan catches this."*
- *"All you added was one trigger, one skill, one hook, one task."*

---

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Act 2→3 dependency — Act 2 fails, Act 3 loses contrast | Medium | Critical | Show screenshot of generic response, proceed to Act 3 live |
| HTTP trigger doesn't fire live | Medium | High | Invoke subagent manually in Playground |
| Skill doesn't load after adding | Medium | High | Mention skill by name in prompt; screenshot fallback |
| Incident trigger didn't run overnight | Medium | High | Show YAML + narrate; invoke in Playground |
| Scheduled task didn't find both bugs | Medium | Medium | Click Run Now; screenshot fallback |
| Agent gives weak/wrong answer | Medium | Medium | Rephrase; *"that's why we have hooks"* |
| Hook audit log not visible in UI | Low | Medium | Show hook code + explain conceptually |
| GitHub OAuth hangs | Low | Low | Skip issue creation step |
| Network/WiFi down | Low | High | Pre-recorded video backup |
| App Insights has no data | Low | High | Screenshots of prior run |

---

## Pre-Show Checklist

| When | Task | Verified? |
|------|------|-----------|
| T-12 hours | Run `generate-errors.ps1` → seeds 500s, `/slow` latency, and injection probe traffic. Telemetry ingests in 2-5 min; the 12-hour lead time is for the Azure Monitor alert to fire and the incident trigger to complete its investigation. | ☐ |
| T-1 hour | Incident trigger completed (Activities tab) | ☐ |
| T-1 hour | Scheduled task ran at 8 AM | ☐ |
| T-1 hour | App Insights has 500s on `/orders/999` — run `az monitor app-insights query --app <app> --analytics-query "exceptions \| where timestamp > ago(12h) \| count"`. Expect ≥10. If zero, re-run `generate-errors.ps1`, wait 5 min. **Act 2 is dead without these.** | ☐ |
| T-1 hour | App Insights has SQLi probes — run `az monitor app-insights query --app <app> --analytics-query "requests \| where timestamp > ago(12h) and url contains 'status=' and url contains 'OR' \| count"`. Expect ≥10. **Act 5 needs these.** | ☐ |
| T-1 hour | Azure Monitor alert `order-api-demo-high-latency` has fired — check Alerts blade or Scheduled Query Rules. If not fired, the incident trigger won't have run. **Act 4 depends on this.** | ☐ |
| T-30 min | Workspace mode is ON | ☐ |
| T-30 min | Cert `order-api-tls` expiry is ~30 days out (created with 1-month validity). Note the exact date for narration. | ☐ |
| T-30 min | HTTP trigger subagent configured | ☐ |
| T-15 min | Logged into sre.azure.com, agent responds | ☐ |
| T-10 min | Subagent Builder tab open | ☐ |
| T-10 min | GitHub connection working (ask agent to search repo) | ☐ |
| T-5 min | **⚠️ order-api-runbook skill NOT added — DELETE if present** | ☐ |
| T-5 min | Scaling guardrail hook IS applied | ☐ |
| T-2 min | Chat history cleared | ☐ |
| T-2 min | Screenshots of happy path accessible offline | ☐ |

**⚠️ CRITICAL — Act 2 → Act 3 dependency:** Act 3's entire impact depends on Act 2 producing the generic (no-skill) response first. If Act 2 fails live, show a screenshot of the generic response and say *"here's what it said without the skill"* — then proceed to Act 3 live with the skill.

---

## Out of Scope

These capabilities exist but are deliberately not shown. If asked, deflect confidently:

- **Deployment rollbacks** — "Supported with Contributor + Review mode. We focused on safer actions today."
- **Multi-service correlation** — "The agent can monitor multiple services. We used one to keep the story clear."
- **Custom dashboards / reporting** — "The agent creates GitHub issues and can send email notifications. For dashboards, the data is in App Insights and Log Analytics — use your existing Workbooks or Grafana."
- **Non-Azure workloads** — "Today it monitors Azure resources. Multi-cloud is not in scope."
- **Competitive (PagerDuty/Datadog AI)** — "Those tools alert. This agent investigates, acts, and learns your runbooks."

---

## Post-Demo

- Share the samples repo with attendees
- Link to DEMO-SCRIPT.md for the full scripted walkthrough
- Collect feedback: which demo moment resonated most?
