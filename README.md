# Grafana Administration Platform

Production-oriented, 100% declarative GitOps platform managing **Teams**, **Azure AD (Entra ID) Group Sync**, **Parent/Child Folders & Permissions**, **Fine-Grained Fixed RBAC Roles**, **Loki Log-Based Access Control (LBAC)**, **Service Accounts**, and **Governance Guardrails** via **Argo CD**, **Helm**, and the **Grafana Operator** (with zero custom scripts).

---

## 1. Core Platform Architecture

All resources are modeled in modular value files, validated via policy-as-code guardrails, and rendered into official Kubernetes Custom Resources:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MODULAR DECLARATIVE VALUES                         │
│   chart/values/Team.yaml                  chart/values/GrafanaFolder.yaml   │
│   chart/values/TeamLBACRule.yaml          chart/values/GrafanaServiceAccount│
│   chart/values/ResourcePermission.yaml    chart/values.yaml                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (PR Policy Guardrails / Conftest)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AUTOMATED GOVERNANCE & CHECKS                         │
│   - Conftest / OPA Security Rules (policy/security.rego)                    │
│   - Dependabot Operator Upgrade Watch (.github/dependabot.yml)              │
│   - Nightly Drift Detection Workflow (.github/workflows/drift-detection)   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Git Commit & Push)
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB GITOPS REPOSITORY                           │
│              https://github.com/cosmicsatish/grafana-admin-platform         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Argo CD Automated Sync)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ARGO CD / KUBERNETES CLUSTER                          │
│          Applies Native Custom Resources via Grafana Operator v5.24.0       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Grafana Instance API)
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GRAFANA CLOUD INSTANCE                              │
│                    https://cosmicsatish.grafana.net                         │
│   - Osttra Root Folder with 41 Nested Child Folders                         │
│   - Dedicated Team Ownership (Permission: 4 / Admin)                        │
│   - Teams Synchronized with Azure AD Group Object IDs                       │
│   - Fine-Grained Fixed RBAC Roles Assigned to Teams & Service Accounts      │
│   - Official Operator Observability Dashboard (ID: 22785)                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Platform Capabilities & Guardrails

### 2.1 Policy-as-Code Guardrails (`policy/security.rego`)
Automated PR checks using Conftest / OPA prevent accidental misconfigurations:
- **Zero Global Admin SAs**: Auto-blocks service accounts with broad `role: Admin` or `role: Editor` (enforces `role: None` + fine-grained `fixedRoles`).
- **Token Expiry Enforcement**: Ensures all service account tokens have valid expiration dates.
- **Identifier Validation**: Enforces mandatory UIDs for folders and slugs for teams.

### 2.2 Official Grafana Operator Dashboard (`chart/templates/GrafanaDashboard.yaml`)
- Imports the official Grafana Operator dashboard (**ID: `22785`**) via native `GrafanaDashboard` CRD.
- Placed directly inside the root `Osttra` folder to monitor reconciliation queues, sync status, and controller latency.

### 2.3 Operator Upgrade Watch (`.github/dependabot.yml`)
- Automated weekly watch on the upstream Grafana Operator Helm repository (`https://grafana.github.io/helm-charts`).
- Alerts the platform team when new operator versions (`v5.25.x+`) introduce new CRDs (e.g. `GrafanaTeam`), keeping the platform 100% aligned with upstream.

### 2.4 Nightly Drift & Integrity Detection (`.github/workflows/drift-detection.yaml`)
- Scheduled nightly workflow validating rendering integrity and policy compliance.
- Automatically opens a GitHub Issue if drift or policy violations are detected.

---

## 3. Directory Layout

```text
.
├── chart/                              # Pure declarative Helm Chart (0 custom scripts)
│   ├── Chart.yaml                      # Chart metadata
│   ├── values.yaml                     # Global instance connection settings
│   ├── values/                         # Modular values named by official Kind
│   │   ├── Team.yaml                   # 39+ teams, Azure AD Object IDs, and roles
│   │   ├── GrafanaFolder.yaml          # Osttra root + 41 nested folders with team ownership
│   │   ├── TeamLBACRule.yaml           # 26+ Loki LBAC log stream selectors
│   │   ├── GrafanaServiceAccount.yaml  # Service accounts with role None & fixedRoles
│   │   └── ResourcePermission.yaml     # Scoped loki-lbac permissions
│   └── templates/                      # Pure native templates
│       ├── _helpers.tpl
│       ├── Grafana.yaml                # External Grafana instance CR
│       ├── GrafanaDashboard.yaml       # Official Operator Dashboard CR (ID: 22785)
│       ├── GrafanaFolder.yaml          # GrafanaFolder CRs (with parentFolderUID)
│       ├── GrafanaServiceAccount.yaml  # GrafanaServiceAccount CRs
│       ├── Team.yaml                   # GrafanaManifest Team CRs
│       ├── TeamLBACRule.yaml           # GrafanaManifest TeamLBACRule CRs
│       └── ResourcePermission.yaml     # GrafanaManifest ResourcePermission CRs
├── policy/
│   └── security.rego                   # Conftest / OPA security & compliance guardrails
├── deploy/
│   ├── install.sh                      # One-click local bootstrap script (Kind + Argo CD)
│   ├── operator-values.yaml            # Grafana Operator Helm configuration
│   └── argocd/
│       └── application.yaml            # Argo CD Application manifest
├── .github/
│   ├── dependabot.yml                  # Operator & GitHub Actions upgrade watch
│   └── workflows/
│       ├── validate.yaml               # PR lint, Conftest policy, and template dry-run
│       ├── deploy.yaml                 # GitOps deployment pipeline
│       └── drift-detection.yaml        # Nightly drift & integrity check
├── Makefile                            # make validate, make render, make install
└── README.md                           # Master platform documentation
```

---

## 4. Local Commands

```bash
# Validate YAML syntax and lint Helm chart against all values files:
make validate

# Render final Kubernetes manifests to stdout:
make render
```
