# Grafana Administration Platform

Production-oriented, 100% declarative GitOps platform managing **Teams**, **Azure AD (Entra ID) Group Sync**, **Parent/Child Folders & Permissions**, **Fine-Grained Fixed RBAC Roles**, **Loki Log-Based Access Control (LBAC)**, **Service Accounts**, and **Automated Self-Service Resource Onboarding** via **Argo CD**, **Helm**, and the **Grafana Operator** (with zero custom scripts).

---

## 1. Core Platform Architecture

All resources are modeled in modular value files, validated via policy-as-code guardrails, and rendered into official Kubernetes Custom Resources:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SELF-SERVICE ONBOARDING / VALUES                      │
│   - GitHub Actions UI: Automated Resource Onboarding (onboard.yaml)         │
│   - Modular Values: Team.yaml | GrafanaFolder.yaml | ServiceAccount.yaml    │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (PR Policy Guardrails / Conftest)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AUTOMATED GOVERNANCE & CHECKS                         │
│   - Conftest / OPA Security Rules (policy/security.rego)                    │
│   - Dependabot Operator Upgrade Watch (.github/dependabot.yml)              │
│   - Nightly Drift & Integrity Detection (.github/workflows/drift-detection)│
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

## 2. Automated Resource Onboarding (Zero YAML Editing)

You do **not** need to manually edit YAML files to add, update, or remove resources. 

### Method A: Via GitHub Actions UI
1. Go to **Actions** $\rightarrow$ **Automated Resource Onboarding**.
2. Click **Run workflow**.
3. Select the `action` (`add_or_update` or `remove`) and `resource_type` (`team`, `folder`, `service_account`, `lbac_rule`).
4. Enter the details (e.g., Name: `Payments Team`, Roles: `fixed:dashboards:reader,fixed:datasources:explorer`).
5. The workflow automatically updates the values file, passes Conftest policy checks, commits the change, and triggers Argo CD synchronization!

### Method B: Via CLI / Makefile
```bash
# Onboard a new team:
make onboard-team NAME="Payments" SLUG="payments" ROLES="fixed:dashboards:reader,fixed:datasources:explorer" GROUPS="guid-1,guid-2"

# Onboard a new folder under Osttra with team Admin ownership:
make onboard-folder NAME="Payments" SLUG="folder-payments" ADMIN_TEAM="payments"

# Onboard a service account (base role None + fine-grained fixed roles):
make onboard-sa NAME="payments-ci" ROLES="fixed:dashboards:reader"
```

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
├── scripts/
│   └── onboard.py                      # Automated resource onboarding engine
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
│       ├── validate.yaml               # Consolidated PR lint, Conftest policy, & dry-run
│       ├── deploy.yaml                 # GitOps deployment pipeline
│       ├── drift-detection.yaml        # Nightly drift & integrity check
│       └── onboard.yaml                # Self-service UI onboarding workflow
├── Makefile                            # make validate, make render, make onboard-*
└── README.md                           # Master platform documentation
```

---

## 4. Local Commands

```bash
# Validate YAML syntax and lint Helm chart against all values files:
make validate

# Render final Kubernetes manifests to stdout:
make render

# Local bootstrap:
make install
```
