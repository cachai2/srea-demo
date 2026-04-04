# Azure SRE Agent — LevelUp Demo (4/7)

> Demo materials for the SREA GA features LevelUp session.

## Project Structure

```
srea-levelup-demo/
├── buggy-app/              # Demo 2: Sample app with planted bugs
│   ├── app.py              #   Flask API with 4 intentional bugs + OpenTelemetry
│   ├── requirements.txt
│   └── Dockerfile
├── hooks/                  # Demo 3: Agent hook configurations
│   ├── stop-quality-gate.yaml      #   Stop hook — response quality gate
│   ├── posttooluse-safety.yaml     #   PostToolUse hook — block dangerous cmds
│   └── posttooluse-audit.yaml      #   PostToolUse hook — audit all tool calls
├── skills/                 # Demo 4: Custom skill
│   └── aks-troubleshooting/
│       ├── SKILL.md        #   Step-by-step AKS troubleshooting guide
│       └── skill.yaml      #   Skill definition (name, description, tools)
├── infra/                  # Supporting infra
│   └── main.bicep          #   ACR + Managed Identity + Container App + App Insights + Log Analytics
├── scripts/
│   └── generate-errors.sh  #   Hit buggy endpoints in a loop to populate App Insights
└── README.md               # ← You are here
```

---

## Pre-Demo Setup

### 1. Prerequisites

| Requirement | Details |
|---|---|
| Azure subscription | Owner or User Access Administrator role |
| Region | Sweden Central, East US 2, or Australia East |
| Resource provider | `az provider register --namespace "Microsoft.App"` |
| Resource provider | `az provider register --namespace "Microsoft.ContainerRegistry"` |
| GitHub repo | Push this project to a GitHub repo for source code integration |

### 2. Deploy the Buggy App

```bash
# Create resource group
az group create -n rg-srea-demo -l eastus2

# Step 1 — Deploy infra with a placeholder image (ACR has no image yet)
az deployment group create \
  -g rg-srea-demo \
  -f infra/main.bicep

# Step 2 — Get ACR name from deployment output
ACR_NAME=$(az deployment group show -g rg-srea-demo -n main \
  --query properties.outputs.acrName.value -o tsv)

# Step 3 — Build & push the buggy-app image into the provisioned ACR
az acr build -r $ACR_NAME -g rg-srea-demo -t order-api-demo:v1 ./buggy-app

# Step 4 — Redeploy, now pointing to the real image
az deployment group create \
  -g rg-srea-demo \
  -f infra/main.bicep \
  -p useAcrImage=true

# Step 5 — Smoke test
APP_URL=$(az deployment group show -g rg-srea-demo -n main \
  --query properties.outputs.appUrl.value -o tsv)
curl -sf "$APP_URL/" | jq .
# Expected: {"service": "order-api", "version": "1.2.0"}
```

### 3. Generate Errors for Demo 2

> **Important:** App Insights ingestion takes 3-5 minutes. Run this script
> **at least 10 minutes before** your live demo so telemetry is queryable.

```bash
# Run the automated error-generation script (10 rounds, ~2 min)
# PowerShell (Windows):
.\scripts\generate-errors.ps1 -ResourceGroup rg-srea-demo

# Bash (Linux/macOS/WSL):
bash scripts/generate-errors.sh rg-srea-demo
```

Or manually hit individual endpoints:

```bash
APP_URL=$(az deployment group show -g rg-srea-demo -n main \
  --query properties.outputs.appUrl.value -o tsv)

curl "$APP_URL/orders/999"                             # Bug 1: 500 null deref
curl "$APP_URL/orders?status=shipped'%20OR%201=1--"     # Bug 2: SQL injection
curl "$APP_URL/health"                                  # Bug 3: Secret in logs
curl "$APP_URL/slow"                                    # Bug 4: N+1 latency
```

### 4. Create the SRE Agent

1. Go to [sre.azure.com](https://sre.azure.com) → **Create agent**
2. Select your subscription, `rg-srea-demo`, region
3. Permission level: **Reader** (recommended for demo)
4. After creation, verify: ask *"What Azure resources can you see?"*

### 5. Connect GitHub (for Demo 2)

1. Builder → Connectors → **GitHub (OAuth)**
2. Authorize with your GitHub account
3. Verify: ask *"Search my repos for 'order-api'"*

---

## Demo Walkthroughs

### Demo 1: New Getting Started Experience (5 min)

**Story**: Show how fast you can go from zero to a working SRE agent.

1. Open [sre.azure.com](https://sre.azure.com), click **Create agent**
2. Walk through the wizard (Basics → Resource Groups → Permissions → Deploy)
3. Once deployed, ask: *"What Azure resources can you see?"*
4. Show the auto-generated resource summary and suggested prompts
5. Ask a follow-up: *"Are there any unhealthy resources?"*

> **Tip**: Pre-create one agent so you can show the wizard AND jump to a working agent without waiting.

---

### Demo 2: Source Code Integration & Bug Identification (10 min)

**Story**: An app is throwing 500s. SREA finds the bug in your code.

1. Ask: *"My order-api is returning 500 errors. Can you investigate?"*
2. Agent queries App Insights → finds the NullReference exception on `/orders/999`
3. Agent searches GitHub → finds `app.py`, line ~81: `order.get("item")` on `None`
4. Ask: *"Are there any other issues in this codebase?"*
5. Agent finds:
   - SQL injection risk (string formatting on line ~72)
   - Secret leak in health endpoint (line ~65)
   - N+1 query pattern on `/slow` (line ~87)
6. Ask: *"Create a GitHub issue for the null dereference bug"*

**Key talking points**:
- Semantic code search — natural language, not grep
- Error-to-code correlation — App Insights exceptions → file + line number
- Actionable: can create issues, comment on PRs, trigger workflows

---

### Demo 3: Agent Hooks (10 min)

**Story**: Autonomy is great, but you need guardrails.

#### 3A — Stop Hook (quality gate)
1. Show the agent responding normally
2. Go to Builder → Hooks → Create → paste `stop-quality-gate.yaml` config
3. Ask the agent something; it responds → hook rejects → agent adds "Task complete."
4. Show the rejection/retry flow in the UI

#### 3B — Safety Hook (block dangerous commands)
1. Add the `posttooluse-safety.yaml` hook
2. Ask: *"Clean up old files by running rm -rf /tmp/old-data"*
3. Agent attempts the command → hook blocks it with a policy violation message
4. Show: two hook levels (agent-level vs custom-agent-level), prompt vs command types

#### 3C — Audit Hook (optional, time permitting)
1. Add `posttooluse-audit.yaml` (matcher: `*`)
2. Run any investigation → every tool call gets an `[AUDIT]` trail injected

**Key talking points**:
- Hooks complement run modes (modes = what; hooks = how well)
- Prompt hooks for subjective validation, command hooks for deterministic checks
- `maxRejections` prevents infinite loops

---

### Demo 4: Building and Using Skills (10 min)

**Story**: Capture your team's expertise so it's available 24/7.

1. Ask: *"My AKS cluster has pods in CrashLoopBackOff, what should I do?"*
   - Agent gives a **generic** answer
2. Go to Builder → Skills → **Create**
   - Name: `aks-troubleshooting-guide`
   - Description: *"Use when investigating AKS or Kubernetes issues"*
   - Upload `SKILL.md` from `skills/aks-troubleshooting/`
   - Attach tool: `RunAzCliReadCommands`
3. Ask the **same question** again
   - Agent loads the skill automatically, follows your 6-step procedure, runs az CLI commands
4. Show the difference: skill loaded indicator, structured output following your guide

**Key talking points**:
- Skills are **automatic** — agent loads when relevant (no `/skill` command)
- Custom agents are **explicit** — invoked with `/agent`
- Max 5 concurrent skills, oldest auto-unloaded, re-readable
- Can attach Azure CLI, Kusto, Python, MCP, and Link tools
- Compare: Skill (procedure + execution) vs Custom Agent (domain specialist) vs Knowledge File (reference docs)

---

## Cleanup

```bash
az group delete -n rg-srea-demo --yes --no-wait
```

Delete the SRE Agent from [sre.azure.com](https://sre.azure.com) → agent settings.
