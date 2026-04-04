# AKS Troubleshooting Guide

Use this skill when investigating AKS (Azure Kubernetes Service) or Kubernetes issues
including pod failures, node problems, networking, and deployment rollouts.

## Step 1 — Cluster Health Overview

Run the following to confirm cluster state and node readiness:

```bash
az aks show -g <RESOURCE_GROUP> -n <CLUSTER_NAME> --query "{state:provisioningState, power:powerState.code, k8s:kubernetesVersion}" -o table
az aks nodepool list -g <RESOURCE_GROUP> --cluster-name <CLUSTER_NAME> --query "[].{name:name, vmSize:vmSize, count:count, mode:mode, status:provisioningState}" -o table
```

If any node pool shows a non-Succeeded state, investigate that first.

## Step 2 — Pod Status

List pods that are **not** in Running/Succeeded state:

```bash
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide
```

For each unhealthy pod, get events:

```bash
kubectl describe pod <POD_NAME> -n <NAMESPACE>
kubectl logs <POD_NAME> -n <NAMESPACE> --tail=100
```

Common root causes:
- **CrashLoopBackOff**: App crashes on startup — check logs for stack traces, config errors, or missing env vars.
- **ImagePullBackOff**: Wrong image tag, private registry auth, or network policy blocking pull.
- **Pending**: Insufficient resources — check node capacity (cpu/memory requests vs allocatable).
- **OOMKilled**: Container exceeded memory limit — increase `resources.limits.memory` or fix a memory leak.

## Step 3 — Recent Deployments

Check if a recent rollout introduced the issue:

```bash
kubectl rollout history deployment/<DEPLOYMENT_NAME> -n <NAMESPACE>
kubectl rollout status deployment/<DEPLOYMENT_NAME> -n <NAMESPACE>
```

If the latest revision correlates with the incident, consider rolling back:

```bash
kubectl rollout undo deployment/<DEPLOYMENT_NAME> -n <NAMESPACE>
```

## Step 4 — Networking

If pods are running but requests fail:

```bash
kubectl get svc -n <NAMESPACE>
kubectl get ingress -n <NAMESPACE>
kubectl get networkpolicy -n <NAMESPACE>
```

Test in-cluster connectivity:

```bash
kubectl run test-curl --rm -it --image=curlimages/curl -- curl -s http://<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local
```

## Step 5 — Resource Pressure

Check if the cluster is under resource pressure:

```bash
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu | head -20
```

Query Azure Monitor for node-level metrics:

```
az monitor metrics list --resource <AKS_RESOURCE_ID> --metric "node_cpu_usage_percentage" --interval PT5M --start-time <1h ago>
```

## Step 6 — Escalation

If the issue remains unresolved after these steps:
1. Collect a support bundle: `az aks collectlogs -g <RG> -n <CLUSTER>`
2. Check Azure Service Health for platform-level incidents.
3. Escalate to the on-call infrastructure team with findings from Steps 1-5.
