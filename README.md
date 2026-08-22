# Grafana Administration Platform

Production-grade, 100% declarative GitOps platform managing **Teams**, **Azure AD Group Sync**, **Parent/Child Folders & Permissions**, **Fixed RBAC Roles**, **TeamLBACRule (Loki LBAC)**, and **Service Accounts** via **Argo CD**, **Helm**, and the **Grafana Operator** (with zero custom scripts).

---

## 1. Declarative Architecture

All resources are modeled as official Kubernetes Custom Resources rendered directly by Helm and managed by Argo CD:

- **`GrafanaFolder`** (`grafana.integreatly.org/v1beta1`): Manages the root parent folder **`Osttra`** and all 41 child folders with team ownership.
- **`GrafanaServiceAccount`** (`grafana.integreatly.org/v1beta1`): Manages service accounts and token Secrets.
- **`Team` (`GrafanaManifest`)** (`iam.grafana.app/v0alpha1`): Declarative teams and Azure AD group synchronization.
- **`TeamLBACRule` (`GrafanaManifest`)** (`iam.grafana.app/v0alpha1`): Declarative log stream access control rules on datasource `loki-lbac`.
- **`ResourcePermission` (`GrafanaManifest`)** (`iam.grafana.app/v0alpha1`): Declarative datasource permissions.

---

## 2. Directory Structure

```text
.
├── chart/                              # Pure declarative Helm Chart (0 custom scripts)
│   ├── Chart.yaml                      # Chart metadata
│   ├── values.yaml                     # Global instance settings
│   ├── values/                         # Modular values named by Kind
│   │   ├── Team.yaml                   # 39+ teams, Azure AD Object IDs, and roles
│   │   ├── GrafanaFolder.yaml          # Osttra root + 41 nested folders with team ownership
│   │   ├── TeamLBACRule.yaml           # 26+ Loki LBAC log stream selectors
│   │   ├── GrafanaServiceAccount.yaml  # Service accounts with fixedRoles
│   │   └── ResourcePermission.yaml     # Scoped loki-lbac permissions
│   └── templates/                      # Pure native templates
│       ├── _helpers.tpl
│       ├── Grafana.yaml                # External Grafana instance CR
│       ├── GrafanaFolder.yaml          # GrafanaFolder CRs
│       ├── GrafanaServiceAccount.yaml  # GrafanaServiceAccount CRs
│       ├── Team.yaml                   # GrafanaManifest Team CRs
│       ├── TeamLBACRule.yaml           # GrafanaManifest TeamLBACRule CRs
│       └── ResourcePermission.yaml     # GrafanaManifest ResourcePermission CRs
├── deploy/
│   ├── install.sh                      # Cluster bootstrap script
│   ├── operator-values.yaml            # Grafana Operator Helm configuration
│   └── argocd/
│       └── application.yaml            # Argo CD Application manifest
├── .github/
│   └── workflows/
│       ├── validate.yaml               # PR lint and template dry-run
│       └── deploy.yaml                 # GitOps deployment pipeline
├── Makefile                            # make validate, make render, make install
└── README.md                           # Platform documentation
```

---

## 3. Inspection & Verification

### Argo CD Dashboard
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- **URL**: [https://localhost:8080](https://localhost:8080)
- **Username**: `admin`
- **Password**: `3OAZNkNMS9vj7D57`

### Check Argo CD Status
```bash
kubectl get application -n argocd grafana-admin-platform
```
