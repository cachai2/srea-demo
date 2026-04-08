# Azure SRE Agent Demo

> Deploy a sample app, connect an SRE Agent, and watch it catch errors, follow your runbook, scale with guardrails, and find security risks — all autonomously.

## Narrative

**One agent, four layers.** Each layer is ~5 minutes of config with a visible payoff:

| Layer | What you add | What improves |
|-------|-------------|---------------|
| 0. Bare agent | Connect resources | Knows your infra |
| 1. + Trigger | HTTP Trigger from CI/CD | Catches 500s, generic investigation |
| 2. + Skill | order-api-runbook | Same bug → known pattern, runbook, right team paged |
| 3. + Hook | Scaling guardrail | Incident trigger scales pods, hook enforces max 10 |
| 4. + Scheduled Task | Daily security scan | Finds cert expiry + injection probes |

## Project Structure

```
srea-levelup-demo/
├── sample-app/              # Sample order-api service
│   ├── app.py              #   Flask API with intentional bugs + OpenTelemetry
│   ├── requirements.txt
│   └── Dockerfile
├── sre-config/             # SRE Agent portal configuration
│   ├── incident-error-handler.yaml    # PostDeployValidator subagent (Acts 2-3)
│   ├── latency-incident-handler.yaml  # LatencyIncidentHandler subagent (Act 4)
│   ├── scheduled-health-check.yaml    # DailySecurityScan subagent (Act 5)
│   ├── scaling-guardrail.py            # Scaling hook Python script (Act 4)
│   └── order-api-runbook/             # Skill (added live in Act 3)
│       ├── SKILL.md
│       └── skill.yaml
├── infra/
│   └── main.bicep          #   ACR + Container App + App Insights + Key Vault + Alerts
├── scripts/
│   ├── generate-errors.ps1 #   Seed telemetry (Windows) — 500s, /slow latency, SQLi probes
│   └── generate-errors.sh  #   Seed telemetry (Linux/macOS)
├── demoSpec.md             # Full demo spec (source of truth)
├── DEMO-FLOW.md            # Scripted run-of-show with timestamps
└── README.md               # ← You are here
```

---

## Pre-Demo Setup

> **Tip:** The fastest way to set up is to clone this repo, open it in VS Code, and use GitHub Copilot (Agent mode) to run through the steps below. It will execute the CLI commands, deploy the infrastructure, and tell you which manual portal steps remain. Just say: *"Follow the README to set up the SRE Agent demo."*

### 1. Prerequisites

| Requirement | Details |
|---|---|
| Azure subscription | Owner or User Access Administrator role |
| Region | Sweden Central, East US 2, or Australia East |
| Resource provider | `az provider register --namespace "Microsoft.App"` |
| Resource provider | `az provider register --namespace "Microsoft.ContainerRegistry"` |
| GitHub repo | Push this project to a GitHub repo for source code integration |

### 2. Deploy Infrastructure + App

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

# Step 3 — Build & push the sample app image (tag MUST be 1.2.0)
az acr build -r $ACR_NAME -g rg-srea-demo -t order-api-demo:1.2.0 ./sample-app

# Step 4 — Redeploy, now pointing to the real image
az deployment group create \
  -g rg-srea-demo \
  -f infra/main.bicep \
  -p useAcrImage=true

# Step 5 — Smoke test
APP_URL=$(az deployment group show -g rg-srea-demo -n main \
  --query properties.outputs.appUrl.value -o tsv)
curl -sf "$APP_URL/" | jq .
# Expected: {"service": "order-api", "version": "1.2.0", "deployed_at": "2026-04-06T...Z"}
```

### 3. Seed Telemetry (T-12 hours before demo)

```bash
# PowerShell (Windows):
.\scripts\generate-errors.ps1 -ResourceGroup rg-srea-demo

# Bash (Linux/macOS/WSL):
bash scripts/generate-errors.sh rg-srea-demo
```

> **Why 12 hours?** Telemetry ingests in 2-5 min, but the Azure Monitor alert needs to fire
> and the incident trigger's subagent investigation needs to complete overnight. Run this the
> evening before a morning demo.

### 4. Create the SRE Agent (Act 1)

1. Go to [sre.azure.com](https://sre.azure.com) → **Create agent**
2. Select your subscription, `rg-srea-demo`, region
3. Permission level: **Reader** (recommended for demo)
4. After creation, verify: ask *"What Azure resources can you see?"*

### 5. Connect GitHub

1. Builder → Connectors → **GitHub (OAuth)**
2. Authorize with your GitHub account
3. Resource Mapping → connect your Container App to the GitHub repo
4. Verify: ask *"Search my repos for 'order-api'"*

### 6. Configure PostDeployValidator — HTTP Trigger (Acts 2-3)

1. Go to **Subagent Builder** → **+ New Subagent**
2. Name: `PostDeployValidator`
3. Click **Edit** → **YAML** tab → paste contents of `sre-config/incident-error-handler.yaml`
4. Update the email recipient in the YAML to your email address
5. Click **Save**
6. Set up the **HTTP Trigger**:
   - Trigger name: `PostDeployValidator`
   - Response subagent: `PostDeployValidator`
   - Trigger details: `Validate the order-api Container App deployment in rg-srea-demo. Check for errors, anomalies, or regressions. If errors found, trace to source code and create a GitHub issue. Check for any relevant skills and use them to match findings against known patterns.`
   - Agent autonomy: **Autonomous**
   - Message grouping: **New chat thread for each run**
7. Copy the webhook URL for CI/CD integration

> **Note:** Filename is legacy (`incident-error-handler.yaml`); the subagent name in the portal is `PostDeployValidator`.

### 7. Configure LatencyIncidentHandler — Incident Trigger (Act 4)

1. Go to **Subagent Builder** → **+ New Subagent**
2. Name: `LatencyIncidentHandler`
3. Click **Edit** → **YAML** tab → paste contents of `sre-config/latency-incident-handler.yaml`
4. Update the email recipient in the YAML to your email address
5. Click **Save**
6. Go to **Incident Triggers** → **+ New Incident Trigger**
   - Name: `Order API Latency Spike`
   - Incident platform: **Azure Monitor**
   - Title contains: `order-api-demo-high-latency`
   - Response Subagent: `LatencyIncidentHandler`
   - Processing Mode: **Autonomous**
7. Click **Create**

> **Note:** This subagent needs **Contributor** access scoped to the Container App resource
> (not the resource group) for the scaling mitigation action.

### 8. Configure DailySecurityScan — Scheduled Task (Act 5)

1. Go to **Subagent Builder** → **+ New Subagent**
2. Name: `DailySecurityScan`
3. Click **Edit** → **YAML** tab → paste contents of `sre-config/scheduled-health-check.yaml`
4. Update the email recipient in the YAML to your email address
5. Click **Save**
6. Go to **Scheduled Tasks** → **+ New Scheduled Task**
   - Task Name: `Daily Security & Code Quality Scan`
   - Response Subagent: `DailySecurityScan`
   - Task Details: `Scan the order-api environment for security risks - check Key Vault certificates for upcoming expiry and App Insights logs for attack patterns or leaked secrets.`
   - Frequency: **Daily**
   - Time: **8:00 AM**
   - Message Grouping: **New thread for each run**
7. Click **Save**

### 9. Connect Outlook (optional)

1. Builder → Connectors → **Outlook**
2. Login with your Microsoft 365 email
3. Select **System Assigned Managed Identity** for auth
4. Click **Save**

### 10. Apply Scaling Guardrail Hook (Act 4)

1. Go to **Hooks** → **Create hook**
2. Settings: Event type: **PostToolUse**, Hook type: **Command**, Language: **Python**, Activation: **Always**, Fail mode: **Block**, Timeout: **30**
3. Paste the Python script from `sre-config/scaling-guardrail.py`
4. Apply at **agent level** (applies to all subagents)
5. Click **Save**

### 11. Enable Workspace Mode (required for Act 3 skills)

1. Go to agent **Settings** → enable **Workspace Mode**
2. This gives the agent file operations, terminal, code execution in a sandbox
3. Required for the skill toggle in Act 3

### 11b. Grant Key Vault Reader to Agent (required for Act 5)

The DailySecurityScan needs to read Key Vault certificates. Grant the agent's managed identity Key Vault Reader:

```bash
# Get the agent's managed identity principal ID
AGENT_MI=$(az identity show --name <agent-managed-identity-name> -g rg-srea-demo --query principalId -o tsv)

# Get the Key Vault name
KV_NAME=$(az deployment group show -g rg-srea-demo -n main --query properties.outputs.keyVaultName.value -o tsv)

# Grant Key Vault Reader
az role assignment create --assignee $AGENT_MI --role "Key Vault Reader" \
  --scope "/subscriptions/<sub-id>/resourceGroups/rg-srea-demo/providers/Microsoft.KeyVault/vaults/$KV_NAME"
```

> **Finding the managed identity name:** Go to sre.azure.com → your agent → Settings → look for "Managed identity" link. The name is shown there (e.g., `srea-demo-agent-xxxxx`). You can also run `az identity list -g rg-srea-demo --query "[].name" -o tsv`.

### 12. Cert Expiry Setup (Act 5)

The Bicep template creates a self-signed cert with 1-month validity. For the demo, the cert
needs to be within 30 days of expiry (the DailySecurityScan flags anything within 30 days). The Bicep
creates a 1-month cert, so it will be flagged immediately after deployment. Either:

- Deploy ~23 days before the demo, or
- Manually recreate the cert closer to demo day:

```bash
KV_NAME=$(az deployment group show -g rg-srea-demo -n main \
  --query properties.outputs.keyVaultName.value -o tsv)

# Create (or recreate) the self-signed cert
az keyvault certificate create --vault-name $KV_NAME -n order-api-tls \
  --policy '{"issuerParameters":{"name":"Self"},"x509CertificateProperties":{"subject":"CN=order-api-demo.contoso.com","validityInMonths":1}}'
```

Verify:
```bash
KV_NAME=$(az deployment group show -g rg-srea-demo -n main \
  --query properties.outputs.keyVaultName.value -o tsv)
az keyvault certificate show --vault-name $KV_NAME -n order-api-tls \
  --query 'attributes.expires' -o tsv
```

### 13. Pre-Stage for Demo Day

1. **DO NOT** add the `order-api-runbook` skill yet — you add it live in Act 3
2. Verify all three subagents are configured and saved
3. Verify the scaling guardrail hook is applied
4. Verify workspace mode is ON
5. Clear chat history

---

## Pre-Show Checklist

| When | Check | Command |
|------|-------|---------|
| T-12h | Run `generate-errors.ps1` | `.\scripts\generate-errors.ps1` |
| T-1h | Exceptions exist (expect ≥10) | `az monitor app-insights query --app <app> --analytics-query "exceptions \| where timestamp > ago(12h) \| count"` |
| T-1h | SQLi probes in logs (expect ≥10) | `az monitor app-insights query --app <app> --analytics-query "requests \| where timestamp > ago(12h) and url contains 'status=' and url contains 'OR' \| count"` |
| T-1h | 500-errors alert fired | Check Alerts blade in Azure Portal |
| T-1h | Incident trigger completed | Activities tab in sre.azure.com |
| T-1h | Scheduled task ran at 8 AM | Scheduled Tasks tab in sre.azure.com |
| T-30m | Cert expiry within 30 days | `az keyvault certificate show --vault-name <kv> -n order-api-tls --query 'attributes.expires'` |
| T-5m | Skill NOT added | Delete `order-api-runbook` if present |
| T-5m | Hook IS applied | Verify scaling guardrail in Hooks tab |
| T-2m | Chat history cleared | Clear in sre.azure.com |

---

## Demo Acts

| Act | Title | Time | Layer | Live? |
|-----|-------|------|-------|-------|
| 1 | "Meet Your Agent" | 1 min | Bare agent | Pre-created |
| 2 | "It Catches Errors" | 5 min | + HTTP Trigger | **Live** |
| 3 | "Now It Knows Your App" | 5 min | + Skill | **Live** |
| 4 | "It Acts, With Guardrails" | 10 min | + Hook | Pre-run |
| 5 | "It Finds What You're Not Looking For" | 8 min | + Scheduled Task | Pre-run |
| — | Closing | 3 min | — | — |

See [DEMO-FLOW.md](DEMO-FLOW.md) for the full scripted walkthrough with timestamps and speaker notes.

---

## Cleanup

```bash
az group delete -n rg-srea-demo --yes --no-wait
```

Delete the SRE Agent from [sre.azure.com](https://sre.azure.com) → agent settings.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure SRE Agent                          │
│                   (sre.azure.com)                           │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │ PostDeployValid.  │  │ LatencyIncident  │                 │
│  │ (HTTP Trigger)    │  │ Handler          │                 │
│  │ Reader            │  │ (Incident Trig.) │                 │
│  │                   │  │ Contributor*     │                 │
│  └────────┬─────────┘  └────────┬─────────┘                 │
│           │                     │                            │
│  ┌────────┴─────────┐  ┌───────┴──────────┐                 │
│  │ DailySecurityScan│  │ Scaling Guardrail│                 │
│  │ (Scheduled Task) │  │ (PostToolUse     │                 │
│  │ Reader           │  │  Hook, max 10)   │                 │
│  └──────────────────┘  └──────────────────┘                 │
│                                                             │
│  Skills: order-api-runbook (added live in Act 3)            │
│  * Contributor scoped to Container App resource only        │
└──────────────┬──────────────────────────────────────────────┘
               │ Monitors
               ▼
┌──────────────────────────────────────────────────────────────┐
│                    rg-srea-demo                              │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Container App│  │ App Insights │  │  Key Vault   │       │
│  │ order-api-   │  │ order-api-   │  │ kv-*         │       │
│  │ demo         │  │ demo-ai      │  │              │       │
│  │              │  │              │  │ order-api-tls│       │
│  │ Flask/Python │  │ Exceptions   │  │ (cert, ~30d) │       │
│  │ v1.2.0       │  │ Requests     │  │              │       │
│  │ 4 bugs       │  │ Traces       │  └──────────────┘       │
│  └──────┬───────┘  └──────────────┘                          │
│         │                                                    │
│  ┌──────┴───────┐  ┌──────────────┐  ┌──────────────┐       │
│  │     ACR      │  │ Log Analytics│  │ Alert Rules  │       │
│  │ order-api-   │  │ order-api-   │  │ 500-errors   │       │
│  │ demo:1.2.0   │  │ demo-logs    │  │ high-latency │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  GitHub: <your-org>/srea-levelup-demo                           │
│  - Source code search (QuerySourceBySemanticSearch)          │
│  - Issue creation (CreateGithubIssue)                        │
└──────────────────────────────────────────────────────────────┘
```

---

## Resources

| Resource | Link |
|----------|------|
| SRE Agent Portal | [sre.azure.com](https://sre.azure.com) |
| Documentation | [sre.azure.com/docs](https://sre.azure.com/docs) |
| Starter Lab | [github.com/microsoft/sre-agent/labs/starter-lab](https://github.com/microsoft/sre-agent/tree/main/labs/starter-lab) |
| Blog | [aka.ms/sreagent/blog](https://aka.ms/sreagent/blog) |
| Pricing | [aka.ms/sreagent/pricing](https://aka.ms/sreagent/pricing) |
| Support | [aka.ms/sreagent/github](https://aka.ms/sreagent/github) |
