# Grafana Administration Platform

Production-oriented, 100% declarative GitOps platform managing **Teams**, **Azure AD (Entra ID) Group Sync**, **Parent/Child Folders & Permissions**, **Fine-Grained Fixed RBAC Roles**, **Loki Log-Based Access Control (LBAC)**, **Service Accounts**, and **Automated Self-Service Resource Onboarding** via **Flux CD**, **Helm**, and the **Grafana Operator** (with zero custom scripts).

---

## 1. Core GitOps Architecture

In pure GitOps, GitHub Actions validates pull requests and commits in seconds, while **Flux CD** running inside your Kubernetes cluster synchronizes the desired state to Grafana Cloud:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SELF-SERVICE ONBOARDING / VALUES                      │
│   - GitHub Actions UI: Automated Resource Onboarding (onboard.yaml via yq)  │
│   - Modular Values: Team.yaml | GrafanaFolder.yaml | ServiceAccount.yaml    │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (PR Policy Guardrails / Conftest - 5s)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AUTOMATED CI GOVERNANCE & CHECKS                      │
│   - Conftest / OPA Security Rules (policy/security.rego)                    │
│   - Dependabot Operator Upgrade Watch (.github/dependabot.yml)              │
│   - Nightly Drift & Integrity Detection (.github/workflows/drift-detection)│
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Git Commit & Push to main)
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB GITOPS REPOSITORY                           │
│              https://github.com/cosmicsatish/grafana-admin-platform         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Flux CD In-Cluster Automated Sync)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       FLUX CD / KUBERNETES CLUSTER                          │
│   - Namespace: grafana-operator-configs                                     │
│   - HelmRelease: grafana-admin-platform (via GitRepository source)          │
│   - Instance: grafanacloud-osttra (Selector: dashboards: osttra)            │
│   - Secret: grafanacloud-credentials (Key: GRAFANA_API_KEY)                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Reconciles against Grafana API)
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

## 2. Automated Resource Onboarding (Zero Custom Code)

To onboard, update, or remove resources without manually editing YAML files:

1. Go to **Actions** $\rightarrow$ **Automated Resource Onboarding**.
2. Click **Run workflow**.
3. Choose `action` (`add_or_update` or `remove`) and `resource_type` (`team`, `folder`, `service_account`, `lbac_rule`).
4. Fill in the details. *(Note: If selecting `remove`, you must type `DELETE` in the confirmation box for safety).*
5. The workflow updates the values file using native `yq`, validates security policies, commits to `main`, and triggers Flux CD synchronization!

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
│       ├── Grafana.yaml                # External Grafana instance CR (grafanacloud-osttra)
│       ├── GrafanaDashboard.yaml       # Official Operator Dashboard CR (ID: 22785)
│       ├── GrafanaFolder.yaml          # GrafanaFolder CRs (with parentFolderUID)
│       ├── GrafanaServiceAccount.yaml  # GrafanaServiceAccount CRs
│       ├── Team.yaml                   # GrafanaManifest Team CRs
│       ├── TeamLBACRule.yaml           # GrafanaManifest TeamLBACRule CRs
│       └── ResourcePermission.yaml     # GrafanaManifest ResourcePermission CRs
├── policy/
│   └── security.rego                   # Conftest / OPA security & compliance guardrails
├── deploy/
│   ├── install.sh                      # Cluster bootstrap script (Grafana Operator + HelmRelease)
│   ├── operator-values.yaml            # Grafana Operator Helm configuration
│   └── flux/
│       ├── kustomization.yaml          # Flux Kustomization
│       ├── helm-release.yaml           # Flux HelmRelease applying the chart
│       └── sources/
│           └── git-repository.yaml     # Flux GitRepository source
├── .github/
│   ├── dependabot.yml                  # Operator & GitHub Actions upgrade watch
│   └── workflows/
│       ├── validate.yaml               # Fast 5s PR lint, Conftest policy, & template validation
│       ├── drift-detection.yaml        # Nightly drift & integrity check
│       └── onboard.yaml                # Native yq self-service UI onboarding workflow
├── Makefile                            # make validate, make render, make install
└── README.md                           # Master platform documentation
```

---

## 4. Local & Cluster Commands

```bash
# Validate YAML syntax and lint Helm chart against all values files:
make validate

# Render final Kubernetes manifests to stdout:
make render

# Deploy / Bootstrap to cluster:
make install
```
