# Grafana Admin Platform

A **declarative, GitOps-driven platform** for managing Grafana Cloud resources — teams, folders, service accounts, datasources, LBAC rules, dashboards, and alert groups — via the [Grafana Operator](https://github.com/grafana/grafana-operator).

All resources are defined as YAML in this repository and reconciled automatically to your Grafana Cloud instance. No manual clicking in the Grafana UI required.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Quick Start (First-Time Setup)](#quick-start-first-time-setup)
- [GitOps Delivery Options](#gitops-delivery-options)
  - [Option A — Argo CD (Recommended)](#option-a--argo-cd-recommended)
  - [Option B — GitHub Actions (Argo CD Free)](#option-b--github-actions-argo-cd-free)
- [Operations Guide](#operations-guide)
  - [Add a Team](#add-a-team)
  - [Add a Folder](#add-a-folder)
  - [Add a Service Account](#add-a-service-account)
  - [Add a Loki LBAC Rule](#add-a-loki-lbac-rule)
  - [Add a Dashboard](#add-a-dashboard)
  - [Add Alert Rule Groups](#add-alert-rule-groups)
  - [Remove a Resource](#remove-a-resource)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Policy Guardrails](#policy-guardrails)
- [Known Limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
GitHub (source of truth)
     │
     │  push / PR
     ▼
┌─────────────────────┐
│  GitHub Actions CI  │  validate → policy → lint → template
└─────────┬───────────┘
          │ (choose one delivery path)
          │
    ┌─────┴──────┐
    │            │
    ▼            ▼
 Argo CD    GitHub Actions Sync
 (Option A)  (Option B, Argo CD Free)
    │            │
    └─────┬──────┘
          │  helm template | kubectl apply
          ▼
  Kubernetes Cluster
  (Grafana Operator)
          │
          │  Grafana Operator CRDs reconciled
          ▼
  Grafana Cloud (cosmicsatish.grafana.net)
  Teams / Folders / Datasources / Alerts / Dashboards
          │
          │  LBAC rules applied via REST API
          ▼
  Loki LBAC enforced per team
```

---

## Repository Layout

```
grafana-admin-platform/
├── chart/                        # Helm chart (source of truth for all CRs)
│   ├── Chart.yaml
│   ├── values.yaml               # Global config (Grafana URL, secret name)
│   ├── values/                   # Domain-split values files (edit these!)
│   │   ├── Team.yaml             # Team definitions (name, slug, roles, Azure AD groups)
│   │   ├── GrafanaFolder.yaml    # Folder hierarchy with team ACLs
│   │   ├── GrafanaServiceAccount.yaml  # Service accounts with fine-grained roles
│   │   ├── GrafanaDatasource.yaml      # Datasource definitions (e.g. LBAC Loki)
│   │   ├── TeamLBACRule.yaml     # Per-team Loki log stream selectors
│   │   └── ResourcePermission.yaml     # Datasource-level access assignments
│   ├── templates/                # Helm templates (do not edit for normal operations)
│   │   ├── _helpers.tpl          # Shared label/selector helpers
│   │   ├── Grafana.yaml          # Grafana CR (external cloud instance)
│   │   ├── GrafanaFolder.yaml    # Generates GrafanaFolder CRs from values/GrafanaFolder.yaml
│   │   ├── GrafanaServiceAccount.yaml  # Generates GrafanaServiceAccount CRs
│   │   ├── GrafanaDatasource.yaml      # Generates GrafanaDatasource CRs
│   │   ├── Team.yaml             # Generates GrafanaManifest/Team CRs
│   │   ├── TeamLBACRule.yaml     # Generates GrafanaManifest/TeamLBACRule CRs
│   │   ├── ResourcePermission.yaml     # Generates GrafanaManifest/ResourcePermission CRs
│   │   ├── GrafanaDashboard.yaml # Auto-discovers dashboards/**/*.json → GrafanaDashboard CRs
│   │   └── GrafanaAlertRuleGroup.yaml  # Auto-discovers alerts/**/*.yaml → GrafanaAlertRuleGroup CRs
│   ├── dashboards/               # (optional) Drop JSON dashboards here to auto-provision
│   │   └── <folder-name>/        # Must match a folder UID in GrafanaFolder.yaml
│   │       └── my-dashboard.json
│   └── alerts/                   # (optional) Drop alert rule groups here to auto-provision
│       └── <folder-name>/        # Must match a folder UID in GrafanaFolder.yaml
│           └── my-alerts.yaml
│
├── deploy/
│   ├── argocd/
│   │   └── application.yaml      # Argo CD Application CR (Option A)
│   ├── install.sh                # One-shot bootstrap script (local/CI)
│   └── operator-values.yaml      # Grafana Operator Helm values
│
├── .github/
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── workflows/
│       ├── validate.yaml         # PR/push: lint + policy + template validation
│       ├── onboard.yaml          # Manual: add/remove teams, folders, service accounts, LBAC rules
│       ├── sync.yaml             # Automatic: Argo CD-free GitOps sync on push to main
│       └── drift-detection.yaml  # Nightly: full chart integrity and policy check
│
├── policy/
│   └── security.rego             # Conftest/OPA guardrails (enforced in CI)
│
└── Makefile                      # Local developer commands
```

---

## How It Works

1. **All resources are values, not templates.** You add/edit resources by editing YAML files under `chart/values/`. The Helm templates in `chart/templates/` are generic and never need touching.

2. **Dashboards and alert groups are auto-discovered.** Drop a JSON file under `chart/dashboards/<folder-uid>/` or a YAML file under `chart/alerts/<folder-uid>/` and it will be provisioned automatically — zero template changes required.

3. **CI validates every change.** On every PR and push, GitHub Actions runs YAML linting, Helm lint + template rendering, and OPA/Conftest policy checks.

4. **Delivery is via Argo CD or GitHub Actions.** Choose one depending on your infrastructure.

5. **LBAC rules are applied via Grafana REST API.** The Grafana Operator's `GrafanaManifest/TeamLBACRule` path returns HTTP 500 from Grafana Cloud's `v0alpha1` API (a known upstream limitation). The sync workflow applies LBAC rules directly via `PUT /api/datasources/uid/{uid}/lbac/teams` instead.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| `kubectl` | ≥ 1.28 | Kubernetes cluster management |
| `helm` | ≥ 3.12 | Chart rendering and installation |
| `make` | any | Local developer shortcuts |
| Kubernetes cluster | any | Grafana Operator runtime |
| Grafana Cloud stack | any | Target Grafana instance |
| Grafana Service Account Token | `Admin` role | Operator authentication |

---

## Quick Start (First-Time Setup)

### 1. Create the Grafana API token secret

```bash
kubectl create namespace grafana-operator-configs
kubectl -n grafana-operator-configs create secret generic grafanacloud-credentials \
  --from-literal=GRAFANA_API_KEY="<your-service-account-token>"
```

> **Important:** The service account token must have `Admin` role in Grafana Cloud. Keep this secret managed outside of Git (use your secrets manager of choice).

### 2. Run the bootstrap installer

```bash
GRAFANA_URL="https://your-stack.grafana.net" \
GRAFANA_TOKEN="glsa_..." \
./deploy/install.sh
```

This installs the Grafana Operator and deploys the platform chart in one step.

### 3. Verify

```bash
kubectl get grafana,grafanafolder,grafanateam,grafanaserviceaccount,grafanadatasource \
  -n grafana-operator-configs
```

---

## GitOps Delivery Options

### Option A — Argo CD (Recommended)

Argo CD continuously watches the repository and reconciles changes automatically.

**Install the Application:**

```bash
kubectl apply -f deploy/argocd/application.yaml
```

**How it works:**
- `syncPolicy.automated` with `prune: true` and `selfHeal: true` means Argo CD syncs on every git push and removes resources no longer in Git.
- Uses `ServerSideApply=true` for clean conflict resolution.

**Required secrets in the cluster:**
- `grafana-operator-configs/grafanacloud-credentials` — Grafana API token.

> **LBAC Note:** After Argo CD syncs, LBAC rules still need to be applied via the Grafana REST API (the Kubernetes `TeamLBACRule` API path is not stable on Grafana Cloud). Run the `sync.yaml` workflow manually or add a post-sync hook.

---

### Option B — GitHub Actions (Argo CD Free)

No external CD tool required. The `sync.yaml` workflow renders the chart and applies manifests directly to your cluster via `kubectl`.

**Required GitHub Secrets / Variables:**

| Name | Type | Value |
|------|------|-------|
| `KUBECONFIG` | Secret | Base64-encoded kubeconfig with cluster access |
| `GRAFANA_API_KEY` | Secret | Grafana Cloud service account token (`Admin` role) |
| `GRAFANA_URL` | Variable | `https://your-stack.grafana.net` |

**Setup:**

1. Encode your kubeconfig: `base64 < ~/.kube/config | pbcopy`
2. Add `KUBECONFIG`, `GRAFANA_API_KEY` as repository secrets in GitHub.
3. Add `GRAFANA_URL` as a repository variable.
4. Create a GitHub Actions environment named `production` (optional, for approval gates).
5. Push a change to `chart/**` — the `sync.yaml` workflow fires automatically.

**What it does:**
1. Installs/upgrades the Grafana Operator via Helm.
2. Renders the chart with `helm template`.
3. Applies manifests with `kubectl apply --server-side`.
4. Prunes resources removed from Git.
5. Applies Loki LBAC rules via the Grafana REST API.

---

## Operations Guide

All routine changes are made by editing values files. After editing, commit and push — CI validates and the chosen delivery method deploys.

For common operations, you can also use the **Automated Resource Onboarding** GitHub Actions workflow (`onboard.yaml`) via the GitHub UI without touching YAML directly.

---

### Add a Team

**Edit `chart/values/Team.yaml`:**

```yaml
teams:
  - name: "Payments Team"           # Display name in Grafana
    slug: payments                   # Unique identifier (no spaces)
    owner: traiana                   # Label for ownership tracking
    roles:                           # Optional: fixed RBAC roles
      - fixed:dashboards:reader
      - fixed:datasources:explorer
    syncGroups:                      # Optional: Azure AD Group Object IDs
      - "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**Or use the GitHub Actions workflow:**
1. Go to **Actions → Automated Resource Onboarding → Run workflow**
2. Set `resource_type: team`, `name: Payments Team`, `slug: payments`
3. Optionally add `roles` and `sync_groups`

> If the team needs Loki log access, also add an LBAC rule (see below) and add the team to `ResourcePermission.yaml`.

---

### Add a Folder

**Edit `chart/values/GrafanaFolder.yaml`:**

```yaml
folders:
  - title: "Payments Dashboards"
    uid: "folder-payments"           # Stable, human-readable UID
    parentUid: "osttra"              # Parent folder (omit for top-level)
    owner: "payments"               # Which team manages it
    permissions:
      - role: "Viewer"
        permission: 1               # 1=View, 2=Edit, 4=Admin
      - team: "payments"
        permission: 4               # Owner team gets Admin
```

**Or use the GitHub Actions workflow:**
1. Go to **Actions → Automated Resource Onboarding → Run workflow**
2. Set `resource_type: folder`, `name: Payments Dashboards`, `slug: folder-payments`, `owner: payments`

---

### Add a Service Account

**Edit `chart/values/GrafanaServiceAccount.yaml`:**

```yaml
serviceAccounts:
  - name: "payments-dashboard-reader"
    role: "None"                      # Always None — use fixedRoles for permissions
    owner: "payments"
    fixedRoles:                       # Fine-grained RBAC roles
      - fixed:dashboards:reader
      - fixed:datasources:explorer
    secretName: "payments-sa-token"   # Kubernetes secret to store the generated token
```

**Or use the GitHub Actions workflow:**
1. Go to **Actions → Automated Resource Onboarding → Run workflow**
2. Set `resource_type: service_account`, `name: payments-dashboard-reader`, `slug: payments-sa`
3. Optionally add `roles: fixed:dashboards:reader,fixed:datasources:explorer`

---

### Add a Loki LBAC Rule

LBAC (Label-Based Access Control) restricts which Loki log streams a team can query.

**Step 1 — Edit `chart/values/TeamLBACRule.yaml`:**

```yaml
lbacRules:
  - name: payments                           # Must match team slug
    team: payments                           # Team slug
    datasource: grafanacloud-cosmicsatish-logs-lbac
    selector: '{ business_unit="payments" }' # LogQL stream selector
```

**Step 2 — Grant query permission in `chart/values/ResourcePermission.yaml`:**

```yaml
datasourcePermissions:
  - name: datasource-permissions-grafanacloud-logs-lbac
    assignments:
      # ...existing entries...
      - team: payments
        permission: Query
```

**Or use the GitHub Actions workflow:**
1. Go to **Actions → Automated Resource Onboarding → Run workflow**
2. Set `resource_type: team`, `name: Payments Team`, `slug: payments`
3. Set `selector: { business_unit="payments" }` — LBAC rule and permission are added automatically.

> **Note:** LBAC rules are applied via the Grafana REST API in the `sync.yaml` workflow step. They are not managed through the Kubernetes `TeamLBACRule` CR path (which has an upstream API limitation in Grafana Cloud).

---

### Add a Dashboard

1. Create a folder entry in `chart/values/GrafanaFolder.yaml` if it doesn't exist.
2. Export your dashboard JSON from Grafana UI (Share → Export → Save to file).
3. Place the JSON under `chart/dashboards/<folder-uid>/my-dashboard.json`.
4. Push. The `GrafanaDashboard.yaml` template auto-discovers it.

Example structure:
```
chart/dashboards/
└── folder-payments/              # Must match a folder UID
    └── payments-overview.json
```

The dashboard will be provisioned in the folder matching the directory name.

---

### Add Alert Rule Groups

1. Export your alert group YAML from Grafana UI or create one manually.
2. Set `folderUID` in the file to match a folder UID defined in `GrafanaFolder.yaml`.
3. Place the file under `chart/alerts/<folder-uid>/my-alerts.yaml`.
4. Push. The `GrafanaAlertRuleGroup.yaml` template auto-discovers it.

Example file format (`chart/alerts/folder-payments/critical.yaml`):
```yaml
folderUID: folder-payments
name: payments-critical
interval: 1m
rules:
  - uid: my-rule-uid
    title: PaymentServiceDown
    condition: threshold
    # ...
```

> Alert rules are provisioned with `editable: true` so they can be modified in the Grafana UI without provenance locks.

---

### Remove a Resource

**Via GitHub Actions workflow:**
1. Go to **Actions → Automated Resource Onboarding → Run workflow**
2. Set `action: remove`, type the appropriate `slug`/`name`
3. Type `DELETE` in the `confirm_delete` safety field

**Manually:** Delete the relevant entry from the values file, commit, and push. The delivery mechanism (Argo CD or GitHub Actions `sync.yaml` with `--prune`) will clean up the resource from the cluster and Grafana Cloud.

---

## GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `validate.yaml` | PR + push to `main` | YAML lint, credential scan, OPA policy, Helm lint + template |
| `onboard.yaml` | Manual (`workflow_dispatch`) | Add/remove teams, folders, service accounts, LBAC rules via form UI |
| `sync.yaml` | Push to `main` (chart changes) + manual | Argo CD-free: render chart, apply to cluster, apply LBAC via REST API |
| `drift-detection.yaml` | Nightly at 02:00 UTC + manual | Full chart render + policy check; opens a GitHub Issue on failure |

### Required Secrets (for `sync.yaml`)

Set these in **GitHub → Settings → Secrets and variables → Actions**:

| Name | Type | Description |
|------|------|-------------|
| `KUBECONFIG` | Secret | `base64 < ~/.kube/config` |
| `GRAFANA_API_KEY` | Secret | Grafana Cloud service account token |
| `GRAFANA_URL` | Variable | e.g. `https://cosmicsatish.grafana.net` |

---

## Policy Guardrails

Conftest with OPA policies (`policy/security.rego`) enforces:

| Rule | Description |
|------|-------------|
| No `Admin` base role on service accounts | Must use `role: None` + `fixedRoles` |
| No `Editor` base role on service accounts | Must use `role: None` + `fixedRoles` |
| Token expiry required | Service accounts must specify `tokenExpires` |
| Folder UID required | Every folder must have a stable `uid` field |
| Team slug required | Every team must have a `slug` identifier |

Violations block the PR from merging.

### Add a new policy

Edit `policy/security.rego`. Example — deny teams without an owner:

```rego
deny[msg] {
    team := input.teams[_]
    not team.owner
    msg := sprintf("Policy Violation: Team '%v' must have an owner field.", [team.name])
}
```

---

## Known Limitations

### LBAC via Kubernetes TeamLBACRule API returns HTTP 500

The `GrafanaManifest/TeamLBACRule` resource type posts to `iam.grafana.app/v0alpha1` Kubernetes-style API on Grafana Cloud. This endpoint returns `HTTP 500 Internal Server Error` for `GET` calls (the operator checks existence before creating), meaning LBAC rules cannot be applied through the operator's manifest controller path.

**Workaround (already implemented):** The `sync.yaml` GitHub Actions workflow applies LBAC rules directly via the stable Grafana REST API:
```
PUT /api/datasources/uid/{datasource-uid}/lbac/teams
```

**If using Argo CD only:** Run the `sync.yaml` workflow manually after each sync, or trigger it as a post-sync hook.

### GrafanaManifest/ResourcePermission also returns HTTP 500

Same upstream limitation as LBAC. Datasource-level team permissions (`ResourcePermission`) also fail through the manifest controller. These are managed through a combination of Grafana Cloud native team permissions and the REST API.

---

## Troubleshooting

### Check operator logs
```bash
kubectl logs -n grafana-operator deploy/grafana-operator --tail=100 -f
```

### Check CR sync status
```bash
# Folders
kubectl get grafanafolder -n grafana-operator-configs -o wide

# Service accounts
kubectl get grafanaserviceaccount -n grafana-operator-configs -o wide

# Manifests (teams, LBAC, permissions)
kubectl get grafanamanifest -n grafana-operator-configs -o wide

# Alert groups
kubectl get grafanaalertrulegroup -n grafana-operator-configs -o wide

# Datasources
kubectl get grafanadatasource -n grafana-operator-configs -o wide
```

### Check a specific resource status
```bash
kubectl describe grafanafolder <folder-name> -n grafana-operator-configs
```

### Validate chart locally
```bash
make validate
```

### Render chart to inspect manifests
```bash
make render
```

### Force a resync via Argo CD
```bash
kubectl -n argocd annotate application grafana-admin-platform \
  argocd.argoproj.io/refresh=hard --overwrite
```

### Force a resync via GitHub Actions
Run the **GitOps Sync (Argo CD Free)** workflow manually from the Actions tab.

### Secret not found error in operator
Ensure `grafanacloud-credentials` secret exists in the **same namespace as the Grafana CR**:
```bash
kubectl get secret grafanacloud-credentials -n grafana-operator-configs
```

If missing:
```bash
kubectl -n grafana-operator-configs create secret generic grafanacloud-credentials \
  --from-literal=GRAFANA_API_KEY="<your-token>"
```
