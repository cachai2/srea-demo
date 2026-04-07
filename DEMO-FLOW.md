# Demo Run-of-Show — Principal PM Perspective

**Session:** Azure SRE Agent GA Features LevelUp  
**Total runtime:** ~32 min (fits 45-min slot with 13 min buffer for delays + Q&A)  
**Audience:** SREs, platform engineers, IT decision-makers  

---

## Narrative Arc

**One sentence**: "Watch the same agent go from 'I found a 500' to 'I matched your known pattern, followed your runbook, scaled your pods within policy, and found a cert nobody knew was expiring.' All you added was one trigger, one skill, one hook, one task."

**The story**: Instead of showing three independent triggers finding three independent bugs, we show **one agent getting smarter as you invest in it**. Each layer is ~5 minutes of config with a visible payoff. The audience sees compounding value — and it mirrors real customer adoption.

| Layer | What you add | What improves | Time |
|-------|-------------|---------------|------|
| 0. Bare agent | Pre-created, resources connected | Knows your infra | 1 min |
| 1. + Trigger | HTTP Trigger from CI/CD | Catches the 500, generic investigation | 5 min |
| 2. + Skill | order-api-runbook | Same bug → known pattern, runbook, right team paged | 5 min |
| 3. + Hook | Scaling guardrail | Incident trigger scales pods, hook enforces max 10 | 10 min |
| 4. + Scheduled Task | Daily security scan | Finds cert expiry + injection probes — things with no errors | 8 min |

**Why this works:**
1. **ROI at each step** — each layer is an incremental investment with a visible payoff
2. **The skill toggle is THE demo** — Layer 1 → Layer 2 is the single most impactful transition
3. **Mirrors real adoption** — Phase 1: create agent. Phase 2: add trigger. Phase 3: write skill. Phase 4: add hooks + scheduled tasks. Go at your own pace.
4. **Natural escalation of trust** — bare → read-only triggers → knowledge → write access with guardrails → autonomous scanning

---

## Pre-Show Checklist (Day-of)

- **T-12 hours** — Run `.\scripts\generate-errors.ps1` → generates 500s, `/slow` latency data, and SQL injection probe traffic. Telemetry ingests in 2-5 min, but the 12-hour lead time is needed for the Azure Monitor alert to fire and the incident trigger to complete its full investigation overnight. Also ensure container image is tagged `1.2.0` (not `latest`) so the agent can correlate "v1.2.0 deployed at 4:03 PM" with the error spike.
- **T-1 hour** — Verify: incident trigger completed (check Activities tab — agent should have scaled pods and created GitHub issue), scheduled task ran at 8 AM
- **T-1 hour** — Verify App Insights has 500 exceptions on `/orders/999`: run `az monitor app-insights query --app <app> --analytics-query "exceptions | where timestamp > ago(12h) | count"` — if zero, re-run `generate-errors.ps1` and wait 5 min for ingestion. **Act 2 is dead without these.**
- **T-30 min** — Verify: HTTP trigger subagent is configured and ready for live demo. Verify workspace mode is **ON** for skills. Verify cert `order-api-tls` expiry is 5-10 days out (`az keyvault certificate show --vault-name <vault> -n order-api-tls --query attributes.expires -o tsv`). If not, recreate it.
- **T-15 min** — Open [sre.azure.com](https://sre.azure.com), log in, have agent ready → confirm agent responds to "hello"
- **T-10 min** — Open a second browser tab with Builder → Subagent Builder (show configured subagents)
- **T-10 min** — Verify GitHub connection: ask the agent *"Search my repos for order-api"* — if OAuth token expired, re-authorize now
- **T-5 min** — **⚠️ CRITICAL:** Verify order-api-runbook skill is **NOT** yet added. If someone pre-configured it, DELETE it now. The entire Act 3 before/after contrast depends on adding it live.
- **T-5 min** — Verify scaling guardrail hook IS applied (for Act 4).
- **T-2 min** — Clear agent chat history so interactive demo starts clean
- **Backup** — Have screenshots of each act's happy path accessible offline

---

## Act 1: "Meet Your Agent" — Layer 0 (1 min)

### The "So What"
> "You deploy this alongside your app and it's ready in 2 minutes."

### Flow

**0:00** — Show the pre-created agent in [sre.azure.com](https://sre.azure.com)  
*"Here's our SRE agent. It's monitoring a Python order-api running on Azure Container Apps — Container App, App Insights, Key Vault, Log Analytics. Setting this up took 2 minutes — pick a subscription, pick a resource group, pick permissions, deploy."*

**0:30** — Brief portal orientation  
*"Over here: Subagent Builder for automation, Skills for team expertise, Hooks for guardrails. We'll add each of these — one at a time — over the next 30 minutes. And you'll see the agent get smarter with each layer."*

### Transition line
> *"Right now, it knows what we have. It can answer questions about our resources. But it's passive — it waits for you to ask. Let's make it proactive."*

---

## Act 2 + 3: "It Catches Errors" → "Now It Knows Your App" — Layers 1-2 (10 min combined)

### The "So What"
> "One webhook URL in your pipeline, and every deploy gets validated automatically. Add a skill, and it follows YOUR runbook — not generic best practices."

### Setup (done before the session)
- Subagent `PostDeployValidator` configured — runs post-deploy health checks, queries App Insights for errors, traces to source code
- HTTP trigger URL added as a post-deploy step in CI/CD pipeline
- `generate-errors.ps1` ran earlier → 500 errors on `/orders/999` are in App Insights
- **Skill NOT yet added** — that's the next layer
- **Two browser tabs ready** — one for Thread 1 (no skill), one for Thread 2 (with skill)

### Flow (interleaved — eliminates dead air)

#### Phase 1: Kick off the generic run

**0:00** — Set the scene  
*"We just deployed v1.2 of our order-api. In our CI/CD pipeline, the last step calls the SRE Agent's HTTP trigger — a webhook URL that says 'hey, we just deployed, check if anything broke.'"*

**0:30** — **Invoke PostDeployValidator in Thread 1** (no skill)  
*"The subagent kicks off automatically. No human involved. This is Layer 1 — we added a trigger."*

#### Phase 2: While it runs — show the skill (Act 3 setup)

**1:00** — Transition: *"While that runs, let me show you what we're about to add."*

**1:15** — Go to Builder → Skills → Create  
*"I'm creating a Skill. It's a Markdown doc — our order-api runbook — with known issue patterns, remediation steps, and escalation policy."*

**1:45** — Upload `order-api-runbook/SKILL.md`, attach tools  
*"This is our team's operational experience — 4 known patterns, severity thresholds, who to page. Any SRE on your team could write this."*

**2:15** — Briefly mention workspace mode  
*"Skills require workspace mode — file read/write, terminal, code execution in a sandbox. Already enabled."*

**2:30** — Verify skill loaded (hot-reload)  
Ask in chat: *"What skills do you have?"* Wait for the agent to confirm `order-api-runbook`. ~10 seconds.

*(*If audience seems skeptical about the bug:*) "Unit tests passed. Integration tests passed. But no test hit `/orders/999` because that order doesn't exist in the test database. Edge cases in production data are exactly what post-deploy validation is for."*

#### Phase 3: Come back to the generic run

**3:00** — Transition: *"Let's go back — the first run is done. No skill, generic response."*

**3:15** — Switch to Thread 1 → walk through the results  
*"It found 500 errors right after the deploy. Traced to the `get_order` function in `app.py`. Created a GitHub issue."*

**3:45** — Let the audience feel the gap  
*"This is good. It found the bug, it found the function. But look at the response — generic. 'NoneType in get_order, consider adding a null check.' It doesn't know this is our most common bug. It doesn't know our escalation policy. It doesn't know who to page."*

**4:15** — Narrate the KQL  
*"Look at the query it wrote — that's real KQL against your App Insights. You can copy this and run it yourself. Every step is auditable."*

**4:30** — Talk about speed  
*"This just did in 90 seconds what takes your on-call engineer 30-45 minutes — query App Insights, find the exception, search the codebase, trace to the exact function, propose a fix, and file a bug. And it's 2 AM. Nobody woke up."*

#### Phase 4: Kick off the skilled run + continue talking

**5:00** — **Open Thread 2. Re-invoke PostDeployValidator** (skill now loaded)  
Transition: *"Now let's kick off the same investigation with the skill loaded. While that runs, let me show you what happened overnight."*

**5:30** — **Begin previewing Act 4** while Act 3 runs  
*"While the agent re-investigates with our runbook, let me show you Layer 3 — what happened while we were sleeping..."*  
Navigate to Activities tab, start pointing at the LatencyIncidentHandler thread title.  
*"The agent detected a latency spike overnight, scaled the container app, and filed a bug. We'll dig into this in a minute."*

**6:00** — Glance at Thread 2 — if done, switch back. If not, continue Act 4 preview.

#### Phase 5: The contrast (THE demo moment)

**6:30** — Transition: *"And we're back — same bug, but look at the difference."*

**6:45** — Switch to Thread 2 → walk through the skilled response  
*"It didn't just find the bug — it matched it to Pattern 1: Null Order ID from our runbook."*

**7:00** — Show the runbook-driven actions  
*"Per the runbook: GitHub issue with label 'input-validation', proposed fix with null check, and — since error rate is above 5% — page @contoso-sre per escalation policy."*

**7:30** — **PAUSE. Let this land.**  
*"Same bug. Same agent. But instead of just 'NoneType in get_order,' we got: known pattern identified, runbook followed, issue created with the right labels, and the right team paged. All we added was a Markdown file."*

**8:00** — The payoff line  
*"That's the difference between AI and YOUR AI."*

**If either run finishes early while you're mid-explanation:** Just pause and say *"Oh, it's done already — let's look."* That's a good moment — it shows the agent is fast.

### Key talking points (weave in during dead time)
- "Setting this up took about 10 minutes — create the agent, connect the resource group, paste the YAML, done"
- "How many of you have been paged at 2 AM for a 500 error? This is doing that whole triage workflow."
- "Skills are Markdown — not code. Any SRE can write one. Put tribal knowledge in a file instead of a wiki nobody reads."
- "Platform team sets hooks. Service teams write skills. That's the separation of concerns."
- "The agent has no memory between runs. Each investigation starts clean."

### Transition line
> *"Layer 1: it catches errors. Layer 2: it follows your playbook. But what happens when the agent needs to take action — not just investigate? And how do you keep it safe?"*

---

## Act 4: "It Acts, With Guardrails" — Layer 3: + Hook (10 min)

### The "So What"
> "The agent scales pods at 2 AM to save your customers. The hook makes sure it can't scale to 100 and blow your budget. Skills teach it what to do. Hooks enforce what it can't."

**Two moments:** (1) the agent *took action* while you slept, and (2) the hook *constrained* that action to policy. Both land hard.

### Setup (done before the session)
- Subagent `LatencyIncidentHandler` configured — investigates latency spikes, can scale Container Apps (Contributor on Container App resource only — not the resource group), creates GitHub issues
- Incident trigger created: fires on p95 latency threshold, processing mode = **Autonomous**
- **Scaling guardrail hook already applied** — `posttooluse-scaling-guardrail.yaml`, max 10 replicas
- `generate-errors.ps1` generated `/slow` endpoint traffic → 5s response times → alert fired → subagent investigated, hook validated the scaling action, and mitigated

### Flow

#### Part A — The overnight incident

**0:00** — Set the scene  
*"It's 2 AM in Redmond. But it's 10 AM in Frankfurt, and our European customers just started their workday. They're hitting the order listing endpoint — and it processes each row sequentially, taking 5 seconds per request."*

**0:30** — *"With one user, it's slow. With 50 European users hitting it simultaneously, p95 latency spikes. Azure Monitor alerts. Normally, that's your pager at 2 AM."*

**1:00** — *"But we set up an incident trigger — that's Layer 3. Let me show you what happened while I was asleep."*

**1:30** — Navigate to SRE Agent → **Activities** tab  
*"A thread was created automatically at 2 AM — triggered by the latency alert, not by a human."*

**2:00** — Open the completed investigation thread  
*"Let me walk through what the subagent did."*

**2:30** — Scroll through: App Insights latency query, p95 spike identified  
*"It queried App Insights, found p95 response times on `/slow` jumped to 5+ seconds. Correlated this with the v1.2 deployment from yesterday."*

**3:00** — Show: source search → `app.py`, the `slow_endpoint` function with the sequential loop  
*"It found a for loop processing orders one at a time with a blocking call per row — that's the slow path."*

**3:30** — Show: **mitigation action** — agent scaled Container App  
**PAUSE.** *"The important thing here: the agent detected elevated latency, identified which endpoint was slow, and scaled from 1 to 5 replicas to absorb the load. That's the pattern — temporary autonomous mitigation at 2 AM, permanent fix by the dev team during business hours. The platform team's scaling budget is 10 replicas. The agent worked within that budget."*

**4:00** — Show: GitHub issue + email  
*"Bug filed, email sent. When I woke up: no pager, just a GitHub issue with a fix ready for review."*

#### Part B — The guardrail (hooks)

**4:30** — *"Now — you might be thinking: 'What if the agent decides to scale to 100 replicas?' Fair question. That's a real cost risk."*

**5:00** — *"That's where hooks come in."*  
Navigate to **Hooks** → show the scaling guardrail hook  
*"This is a PostToolUse hook. It intercepts every CLI write command and checks: if it's a scaling action, is the replica count above 10? The platform team sets the ceiling — the agent works within that budget."*

**5:30** — Show the hook script  
*"This is a command hook — Python code, not a prompt. It regex-matches --min-replicas and --max-replicas in the CLI command. If the count exceeds 10, it blocks. Deterministic — the LLM can't talk its way around it."*

**6:00** — Show the audit log from the overnight run  
*"Look — when the agent scaled to 5 last night, the hook ran and logged: 'Command within policy (max 10 replicas).' The scaling went through because 5 is under the ceiling."*

**6:30** — Show what a rejection looks like  
*"If the agent had tried --min-replicas 15, this is what it would have seen:"*  
Show the hook's block response on screen (pre-captured or from the YAML): `POLICY VIOLATION: min-replicas=15 exceeds scaling ceiling of 10. Reduce to 10 or fewer and retry.`  
*"The agent gets a rejection message, not a silent failure. It knows what went wrong and can adjust — but it can never exceed the limit."*

**7:00** — The key distinction  
*"You could put 'max 10 replicas' in the skill instructions. And 95% of the time, the LLM would follow it. But production SRE isn't about 95%. The hook is the seatbelt — it doesn't matter what the LLM thinks, the code enforces the limit."*

**7:30** — **The one-liner:**  
*"Skills teach the agent what to do. Hooks enforce what it can't do. Together: expertise with guardrails. The agent mitigates at 2 AM within the budget you set. Your team fixes the root cause at 10 AM. Nobody got paged."*

**8:00** — Mention Review mode + hook levels  
*"Hooks apply at the platform level — the platform team sets the floor. Individual service teams write their own skills. And you can combine hooks with Review mode for an extra layer of human approval."

### Key talking points
- "Layer 3 adds write access — but with guardrails"
- "The agent mitigated — scaling is safe and reversible"
- "Hooks are deterministic — Python code, not LLM judgment"
- "Platform team sets hooks (guardrails), service teams write skills (playbooks)"
- "Autonomous vs Review mode gives you the trust dial"

### Transition line
> *"Layer 1: catches errors. Layer 2: follows your playbook. Layer 3: takes action with guardrails. But what about issues with no errors, no alerts, no symptoms at all?"*

---

## Act 5: "It Finds What You're Not Looking For" — Layer 4: + Scheduled Task (8 min)

### The "So What"
> "SQL injection probes and expiring certs don't throw 500s. They don't spike latency. No alert fires. But a daily scan finds them — every day, consistently."

### Setup (done before the session)
- Subagent `DailySecurityScan` configured — checks Key Vault certs for expiry, scans App Insights logs for security anti-patterns
- Scheduled task created: runs daily at 8 AM
- Task ran this morning → found cert expiry + SQL injection probes in logs → created GitHub issues
- `generate-errors.ps1` already seeded injection probe traffic (`shipped' OR 1=1--`) in App Insights

### Flow

**0:00** — *"The pipeline caught the crash. The incident trigger caught the slowness. But there are two more problems in our environment that neither would ever find."*

**0:30** — *"First — and this one is deterministic: we have a TLS certificate in Key Vault that expires in 7 days. No alert is configured for that. Second: someone has been probing our API with SQL injection payloads — the requests returned 200, so no error-based monitoring caught it. But the query strings are sitting in our App Insights logs."*

**1:00** — Navigate to **Scheduled Tasks** tab  
*"That's Layer 4. I set this up yesterday — one cron schedule, one subagent, same YAML pattern you've seen. A daily security scan that runs every morning at 8 AM. No trigger needed — just time."*

**1:30** — Show task configuration  
*"Connected to the DailySecurityScan subagent, daily frequency, new thread per run. Same YAML-driven subagent pattern we saw earlier."*

**2:00** — Click into today's completed run  
*"Let's see what it found this morning."*

**2:30** — Walk through **primary finding** — certificate expiry  
*"First: the order-api-tls certificate in Key Vault expires in 7 days."*

**3:00** — Let the finding sink in  
*"This one is deterministic — the cert either expires or it doesn't. No monitoring tool fires an alert for this by default. In 7 days, your customers get a certificate error and your app is effectively down. The agent checks every Key Vault cert, every morning, and flags anything within 30 days of expiry."*

**3:15** — Show GitHub issue for cert  
*"It already created a GitHub issue: cert name, vault name, expiry date, recommended action. Ready for the team to pick up."*

**3:30** — Walk through **bonus finding** — SQL injection in logs  
*"But the agent found something else too. SQL injection patterns in App Insights logs — requests to `/orders` with payloads like `shipped' OR 1=1--`. These all returned 200 — your error monitoring saw nothing wrong."*

**4:00** — Emphasize the impact  
*"Someone is probing your API. The requests succeeded. No alert fired. But the agent scanned 24 hours of logs and flagged the pattern. Second GitHub issue created — with timestamps and sample payloads."*

**4:30** — Show email notification  
*"The agent sent this to the team: two findings — cert expiry with severity P1, injection attempts with timestamps. Severity ratings and recommended actions."*

**5:30** — The comparison  
*"Compare this to your current process: maybe someone checks certs quarterly. Maybe a pen test catches the injection probes. The agent checks every day, creates actionable work items, and only emails when something's wrong."*

**5:30** — Pause  
*"Four layers. The agent started knowing nothing. Now it catches errors, follows your runbook, mitigates with guardrails, and finds issues nobody was looking for."*

### Transition line
> *"Let's recap what four layers got us."*

---

## Closing (3 min)

> *"Let's recap the four layers:*
> - *Layer 1: We added one webhook to our pipeline. The agent caught a 500 error — generic investigation, stack trace, line number. Good, but generic.*
> - *Layer 2: We uploaded a Markdown file — our team's runbook. Same bug, but now: known pattern matched, runbook followed, right team paged. Five minutes of config, and the agent went from AI to YOUR AI.*
> - *Layer 3: An incident fired at 2 AM. The agent scaled pods to absorb the load — and the hook made sure it couldn't scale past 10. Expertise with guardrails.*
> - *Layer 4: A daily scan found a cert expiring in 7 days and SQL injection probes in the logs. No alert fires for either. The agent checks every day.*
>
> *You just watched the same agent go from 'I found a 500' to 'I matched your known pattern, followed your runbook, scaled your pods within policy, and found a cert nobody knew was expiring.' All you added was one trigger, one skill, one hook, one task."*

**1:00** — Call to action  
*"This is generally available today. Here's how to start your own layers:"*

- Show link: **sre.azure.com**
- *"Phase 1: create your agent — takes 2 minutes, like you saw. Start with Reader. Connect your GitHub repo."*
- *"Phase 2: add one trigger to your pipeline."*
- *"Phase 3: write one skill for your most common incident."*
- *"Phase 4: add a hook. Set up a scheduled scan. You'll have a working AI teammate before your next on-call rotation."*

**1:30** — (If available) Show QR code for getting-started guide or samples repo  
*"Scan this for the step-by-step guide and the sample code we used today — including the subagent YAMLs, the hook, and the skill."*

**2:00** — Final line  
*"Thank you. Happy to take questions."*

---

## Fallback Plans

- **Agent creation wizard hangs** → Jump to pre-created agent: *"Let me skip ahead to one I prepared."*
- **HTTP trigger doesn't fire live** → Invoke the post-deploy subagent manually in Playground: *"Let me trigger it directly."* Same investigation, same result.
- **Skill doesn't load after adding** → Mention it by name in the prompt: *"Check order-api using the order-api-runbook skill."* If still fails, show screenshot of skillful response.
- **Incident trigger didn't fire overnight** → Show the subagent YAML and narrate: *"Here's what would have run."* Invoke in Playground if time allows. Show screenshot of a previous successful run.
- **Hook audit log not visible** → Explain the hook conceptually with the YAML on screen: *"Here's what the code does — regex match on replica count, block if above 10."*
- **Scheduled task didn't run** → Click **Run task Now** live and narrate while it executes. If too slow, show screenshot of a previous run.
- **GitHub OAuth prompt hangs** → Skip the issue creation step: *"OAuth can be finicky on conference WiFi — in practice this takes 10 seconds."*
- **Agent gives wrong/weak answer** → Rephrase and try again. If still off: *"AI is probabilistic — that's exactly why we have hooks as deterministic guardrails."*
- **Network/WiFi goes down** → Switch to pre-recorded video backup.

---

## Audience Questions You'll Get

**"What LLM does it use?"**  
*"It uses Azure OpenAI under the hood. The model selection is managed by the platform — you don't need to configure it."*

**"Can it make changes?"**  
*"By default it's read-only (Reader role). You can grant Contributor to specific subagents — scoped to a single resource, like just the Container App in Act 4. The interactive agent stays read-only. And hooks enforce what even Contributor agents can do."*

**"How is this different from Copilot?"**  
*"Copilot helps you write code. SRE Agent helps you operate what's running. It's connected to your Azure telemetry, not your IDE."*

**"What about compliance/data residency?"**  
*"Everything stays in your Azure subscription. The agent runs as a managed resource with Azure RBAC."*

**"Can I use this with Terraform/Pulumi?"**  
*"The agent monitors Azure resources regardless of how they were deployed. IaC choice doesn't matter."*

**"How is an HTTP trigger different from an incident trigger?"**  
*"HTTP triggers are for planned events — post-deploy checks, on-demand investigations. Incident triggers are for unplanned events — alerts from Azure Monitor, PagerDuty, ServiceNow. Scheduled tasks are for recurring proactive checks."*

**"What's the difference between skills and hooks?"**  
*"Skills teach the agent what to do — they're LLM-interpreted, like a runbook. Hooks enforce what it can't do — they're deterministic code, like a policy. Skills are expertise, hooks are guardrails. Platform team sets hooks, service teams write skills."*

**"Can subagents call each other?"**  
*"The orchestrator routes to the right subagent based on handoff descriptions. You can chain them for complex workflows."*

**"What incident platforms are supported?"**  
*"PagerDuty, ServiceNow, and Azure Monitor alerts today. HTTP triggers integrate with any webhook-capable system."*

**"Can the agent roll back a deployment?"**  
*"With Contributor access, yes — but we recommend starting with safer actions like scaling. Rollbacks can be gated with Review mode so a human approves first. And hooks can enforce which rollback actions are allowed."*

**"What is workspace mode?"**  
*"Workspace mode gives the agent a sandboxed environment with file operations, terminal access, and code execution. It's required for skills. There are three sandbox options: local, sidecar, and Azure Developer Container for full isolation."*

**"How is this different from PagerDuty/Datadog AI?"**  
*"Those tools alert. This agent investigates, acts, and learns your runbooks. PagerDuty tells you something's wrong. SRE Agent tells you why, files the bug, and scales your pods — all before you wake up."*

**"Why didn't your tests catch the null deref?"**  
*"Unit tests passed. Integration tests passed. But no test hit /orders/999 because that order doesn't exist in the test database. Edge cases from production data — stale bookmarks, deleted records, old API consumers — are exactly what post-deploy validation catches."*

**"Pricing?"**  
*"Check the SRE Agent pricing page for current details."*
