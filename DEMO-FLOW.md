# Demo Run-of-Show — Principal PM Perspective

**Session:** Azure SRE Agent GA Features LevelUp  
**Total runtime:** ~40 min (fits 45-min slot with 5 min buffer)  
**Audience:** SREs, platform engineers, IT decision-makers  

---

## Narrative Arc

**One sentence**: "Azure SRE Agent gives your team an AI teammate that investigates production issues end-to-end — from Azure telemetry to your source code — with enterprise guardrails and your team's own expertise baked in."

**The journey**:
1. **Setup is instant** — you're productive in 2 minutes (Demo 1)
2. **It connects the dots you can't** — telemetry → root cause → line of code (Demo 2)
3. **You stay in control** — guardrails, not guard rails (Demo 3)
4. **It learns your playbook** — your expertise, always on (Demo 4)

---

## Pre-Show Checklist (Day-of)

- **T-30 min** — Run `.\scripts\generate-errors.ps1` → verify status codes all correct
- **T-15 min** — Open [sre.azure.com](https://sre.azure.com), log in, have agent ready → confirm agent responds to "hello"
- **T-10 min** — Open a second browser tab with Builder → Hooks (empty)
- **T-5 min** — Open a third tab with Builder → Skills (empty)
- **T-2 min** — Clear agent chat history so demo starts clean
- **Backup** — Have screenshots of each demo's happy path accessible offline

---

## Demo 1: Getting Started (5 min)

### The "So What"
> "You don't need a Terraform module, a Helm chart, or a weekend. This takes 2 minutes."

### Flow

**0:00** — Click **Create agent**  
*"Let's start from zero. I'm going to create an SRE agent right now."*

**0:30** — Walk through wizard — subscription, RG, region  
*"Three choices: what subscription, which resource groups to monitor, and what permissions."*

**1:00** — Select **Reader** permission  
*"Reader is the safe default — the agent can see everything but can't change anything. You can always escalate later."*

**1:30** — Click Deploy → **switch to pre-created agent**  
*"Deployment takes about a minute. Let me jump to one I set up earlier."*

**2:00** — Ask: *"What Azure resources can you see?"*  
*"First thing I always ask — make sure it can see my environment."*

**3:00** — Show auto-generated resource summary  
*"It immediately mapped out my Container App, App Insights, ACR, Log Analytics — no configuration needed."*

**3:30** — Ask: *"Are there any unhealthy resources?"*  
*"And now we're already doing SRE work."*

**4:30** — Pause on response. Let the audience absorb.

### Transition line
> *"OK, so we have an agent. But any monitoring tool can list resources. Let me show you what makes this different."*

---

## Demo 2: Source Code Integration (10 min)

### The "So What"
> "When your app throws a 500 at 2 AM, you don't need a dashboard — you need someone to find the line of code. This does that."

**This is the money demo.** Land the telemetry-to-code moment. Pause when the agent shows the file and line number — let it breathe.

### Flow

**0:00** — Ask: *"My order-api is returning 500 errors. Can you investigate?"*  
*"This is the prompt I'd send at 2 AM. Plain English."*

**0:30** — Agent queries App Insights automatically  
*"Watch — it's going to App Insights on its own. I didn't tell it where to look."*

**1:30** — Agent finds `AttributeError: NoneType` on `/orders/999`  
*"It found the exception. But here's where it gets interesting..."*

**2:00** — Agent searches GitHub → finds `app.py` line ~81  
**PAUSE.** *"It just went from an App Insights exception... to the exact line of Python code causing it. No runbook. No context-switching."*

**3:00** — Let audience absorb. This is your applause moment.

**3:30** — Ask: *"Are there any other issues in this codebase?"*  
*"Let's see what else it finds."*

**4:30** — Agent finds SQL injection, secret leak, N+1  
*"Three more issues — a SQL injection pattern, a password being logged, and an N+1 query. All from one prompt."*

**6:00** — Ask: *"Create a GitHub issue for the null dereference bug"*  
*"And now — let's actually do something about it."*

**7:00** — Agent creates GitHub issue  
*"Issue created, assigned, labeled. From investigation to action in one conversation."*

### Key talking points (weave in, don't bullet-dump)
- "Semantic search, not grep — it understands what the code does, not just string matching"
- "This works with GitHub and Azure DevOps"
- "The agent correlates across telemetry and code — that's the superpower"

### Transition line
> *"So the agent is powerful. But powerful AI without guardrails is a risk. Let me show you how we handle that."*

---

## Demo 3: Agent Hooks (10 min)

### The "So What"
> "Enterprises need AI they can audit and constrain. Hooks let you enforce policy on every agent action — without slowing it down."

### Flow

#### 3A — Quality gate

**0:00** — Ask the agent something, show normal response  
*"Right now, the agent responds however it wants. Let's add a quality gate."*

**0:30** — Go to Builder → Hooks → Create, paste stop hook config  
*"This is a Stop hook. It runs after every response and checks: did the agent include a completion marker?"*

**1:30** — Ask the agent something again  
*"Watch what happens."*

**2:00** — Hook rejects → agent retries → adds "Task complete."  
*"The hook rejected it. The agent got feedback, adjusted, and tried again. Automatic."*

**2:30** — Briefly show the rejection flow in UI  
*"You can see the rejection reason right here. Full transparency."*

#### 3B — Safety hook

**3:30** — Add the posttooluse-safety.yaml hook  
*"Now let's add a safety hook. This one intercepts shell commands."*

**4:30** — Ask: *"Clean up old files by running rm -rf /tmp/old-data"*  
*"I'm going to ask it to do something dangerous."*

**5:00** — Agent attempts command → hook blocks it  
*"Blocked. The hook pattern-matched rm -rf and stopped it before execution. Not after."*

**5:30** — Show the block message  
*"The agent gets a policy violation message — it knows why, and the human reviewing gets an audit trail."*

**6:00** — (Optional) Show agent-level vs custom-agent-level hooks  
*"You can set these at the platform level or per-agent. Platform team sets the floor, individual teams customize."*

### Key talking points
- "Two types: prompt hooks for judgment calls, command hooks for deterministic rules"
- "maxRejections prevents infinite loops — the agent stops after N attempts"
- "This is how you get from 'AI experiment' to 'AI in production'"

### Skip 3C (audit hook) unless you're running ahead of schedule.

### Transition line
> *"So we can control the agent. But can we teach it? Let's give it our team's expertise."*

---

## Demo 4: Skills (10 min)

### The "So What"
> "Your best SRE's troubleshooting playbook — available 24/7, to every team member, executed automatically."

### Flow

**0:00** — Ask: *"My AKS cluster has pods in CrashLoopBackOff, what should I do?"*  
*"Let's ask about an AKS issue."*

**0:30** — Agent gives a generic answer  
*"That's fine. Generic best practices. But my team has a specific procedure we've refined over 3 years."*

**1:00** — Pause  
*"Let me teach the agent our playbook."*

**1:30** — Go to Builder → Skills → Create  
*"I'm creating a Skill. It's a Markdown doc — my team's troubleshooting guide — plus the tools the agent needs to execute it."*

**2:30** — Upload SKILL.md, attach RunAzCliReadCommands  
*"Here's our 6-step AKS guide. And I'm giving it access to read-only Azure CLI commands."*

**3:30** — Ask the **same question** again  
*"Same question. Watch the difference."*

**4:00** — Agent loads skill automatically  
*"See that? 'Skill loaded.' It recognized the question was about AKS and loaded our guide automatically."*

**5:00** — Agent follows the 6-step procedure, runs az commands  
*"Step 1: cluster health. Step 2: pod status. It's running our playbook, not improvising."*

**7:00** — Show structured output side-by-side with generic answer  
**PAUSE.** *"Same question. Left: generic. Right: your team's expertise, executed live."*

### Key talking points
- "Skills are automatic — the agent decides when to load them based on relevance"
- "Custom agents are different — those are invoked explicitly, like a specialist you page"
- "You can attach CLI, Kusto, Python, MCP, or Link tools to any skill"
- "Think of it as: Skills are procedures. Custom agents are personas. Knowledge files are reference docs."

---

## Closing (2 min)

> *"Let's recap what we just did in 35 minutes:*
> - *Created an agent from scratch*
> - *Investigated a production outage — from App Insights exception to the exact line of buggy Python code*
> - *Added guardrails — quality gates, safety blocks, audit trails*
> - *Taught the agent our team's playbook — and watched it execute it autonomously*
>
> *This is generally available today. Go to sre.azure.com and try it."*

---

## Fallback Plans

- **Agent creation wizard hangs** → Jump to pre-created agent: *"Let me skip ahead to one I prepared."*
- **App Insights has no data** → Show pre-taken screenshot: *"Ingestion is still catching up — but here's what the agent found in my earlier run."*
- **GitHub OAuth prompt hangs** → Skip the issue creation step: *"OAuth can be finicky on conference WiFi — in practice this takes 10 seconds."*
- **Agent gives wrong/weak answer** → Rephrase and try again. If still off: *"AI is probabilistic — in production you'd have hooks to catch this, which is actually a great segue to Demo 3."*
- **Demo 4 skill doesn't load** → Manually trigger: *"Let me mention AKS explicitly."* If still fails, use screenshot.
- **Network/WiFi goes down** → Switch to pre-recorded video backup.

---

## Audience Questions You'll Get

**"What LLM does it use?"**  
*"It uses Azure OpenAI under the hood. The model selection is managed by the platform — you don't need to configure it."*

**"Can it make changes?"**  
*"By default it's read-only (Reader role). You can grant Contributor if you want it to take action, but we recommend starting with Reader."*

**"How is this different from Copilot?"**  
*"Copilot helps you write code. SRE Agent helps you operate what's running. It's connected to your Azure telemetry, not your IDE."*

**"What about compliance/data residency?"**  
*"Everything stays in your Azure subscription. The agent runs as a managed resource with Azure RBAC."*

**"Can I use this with Terraform/Pulumi?"**  
*"The agent monitors Azure resources regardless of how they were deployed. IaC choice doesn't matter."*

**"Pricing?"**  
*"Check the SRE Agent pricing page for current details."*
