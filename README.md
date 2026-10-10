# TWN Online Boutique — GitOps on EKS

A portfolio project that takes Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) microservices demo and wraps it in a full, self-service **CI/CD + GitOps + IaC** pipeline: Jenkins builds and scans container images, a Helm chart is generated and versioned automatically, and ArgoCD reconciles everything onto an AWS EKS cluster that is itself provisioned by Terraform — infra, platform, and application, each as its own layer.

The point of this repo isn't the shopping app (that's Google's demo) — it's everything *around* it: how images get built and scanned, how a Helm chart is produced instead of hand-maintained, how an app-of-apps GitOps pattern is bootstrapped from Terraform, and how ingress/networking is kept decoupled from the application pipeline.

## Table of contents

- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [CI pipeline (Jenkins)](#ci-pipeline-jenkins)
- [CD pipeline (ArgoCD)](#cd-pipeline-argocd)
- [Infrastructure (Terraform)](#infrastructure-terraform)
- [Networking](#networking)
- [Getting started](#getting-started)
- [Security notes](#security-notes)
- [Credits](#credits)

## Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                Jenkins (CI)                                │
│                                                                            │
│ clone boutique src --> build images (Podman) --> Trivy CVE scan            │
│      |                                                                     │
│      v                                                                     │
│ push images to ECR --> generate/refresh boutique-helm chart                │
│      |                                                                     │
│      v                                                                     │
│ commit + push updated chart to this repo  [skip ci]                        │
└────────────────────────────────────────────────────────────────────────────┘
                                 |  git push
                                 v
┌────────────────────────────────────────────────────────────────────────────┐
│                                ArgoCD (CD)                                 │
│                                                                            │
│ app-of-apps (argocd/apps)                                                  │
│   +- gateway-api-crds        (wave 10)                                     │
│   +- aws-load-balancer-ctrl  (wave 20)                                     │
│   +- platform app            (wave 30) --> argocd/platform                 │
│   |     +- GatewayClass / LoadBalancerConfiguration                        │
│   |     +- Gateway + HTTPRoute + TargetGroupConfiguration                  │
│   +- boutique-helm app       (wave 50) --> boutique-helm/                  │
│         +- 11 microservices + redis-cart                                   │
└────────────────────────────────────────────────────────────────────────────┘
                                 ^
                                 |  provisions / bootstraps
┌────────────────────────────────────────────────────────────────────────────┐
│                         Terraform (IaC, 3 layers)                          │
│                                                                            │
│ 00-infra              VPC + EKS cluster + node group + addons              │
│ 10-bootstrap-argocd   Installs ArgoCD via Helm onto the new cluster        │
│ 20-platform           Renders the ArgoCD Application/platform YAML         │
│                       that the app-of-apps root points at                  │
└────────────────────────────────────────────────────────────────────────────┘
```

**Design intent:** CI only ever produces artifacts (images + a Helm chart) and commits them to Git. CD (ArgoCD) is the only thing that talks to the cluster. Ingress/Gateway API wiring is deliberately kept out of the application pipeline and lives in its own ArgoCD-managed `platform` app, so the boutique chart stays cloud-agnostic.

## Repository layout

| Path | Purpose |
|---|---|
| `Jenkinsfile` | CI pipeline definition (declarative, calls into `libs/utils.groovy`) |
| `libs/utils.groovy` | Shared pipeline logic: clone source, build/push images, generate the Helm chart, CVE scan, commit chart bump |
| `boutique-helm/` | The generated Helm chart for the Online Boutique app (deployments, services, `redis-cart`, and Gateway API `HTTPRoute`/`TargetGroupConfiguration` templates) |
| `argocd/apps/` | App-of-apps child `Application` manifests, rendered by Terraform (`20-platform`) |
| `argocd/platform/` | Platform-level Gateway API resources, also rendered by Terraform |
| `terraform-IaC/00-infra/` | VPC + EKS cluster + node group + core addons (modular: `vpc/`, `eks/`) |
| `terraform-IaC/10-bootstrap-argocd/` | Installs ArgoCD onto the freshly created cluster via the `argo-cd` Helm chart |
| `terraform-IaC/20-platform/` | Renders the app-of-apps root + child Application YAMLs and platform/ingress manifests |
| `extras/cluster.yaml` | Alternative `eksctl` cluster definition (quick spin-up path outside Terraform) |
| `Makefile` | Convenience wrapper to run the three Terraform layers in order (and tear them down in reverse) |

## CI pipeline (Jenkins)

Defined in [`Jenkinsfile`](Jenkinsfile), stages run on a single Jenkins agent:

1. **Download Source** — shallow-clones a pinned branch/release of `GoogleCloudPlatform/microservices-demo`.
2. **Build Images** — builds each of the 11 boutique microservices with **Podman**, labels images with the source SCM version, and (if `CVE_SCAN_ENABLED`) runs a **Trivy** scan per image for `HIGH`/`CRITICAL` CVEs, archiving the JSON report as a build artifact. The scan is a hard gate, not just a report: `CVE_FAILED_SCAN_EXT_CODE` controls Trivy's own exit code and is set to fail the build on any `HIGH`/`CRITICAL` finding, so a vulnerable image never reaches ECR.
3. **Push Images to ECR** — creates the ECR repository if missing, pushes, then prunes the local image.
4. **Helm Chart Creation** — regenerates `boutique-helm/` from scratch for every build: one `Deployment`/`Service` manifest per microservice plus `redis-cart`, with image URIs and env vars (service discovery addresses) templated in via `values.yaml`.
5. **Helm Chart Linting** — runs `helm lint` against the freshly generated chart; a bad template render fails the build here instead of surfacing later as an ArgoCD sync failure on the live cluster.
6. **Helm Chart Version Bump Up** — commits the regenerated chart back to this repo (authored as the CI bot identity) and pushes to `main` with `[skip ci]` in the message to avoid a build loop. The push authenticates with a **GitHub deploy key scoped to this one repository**, not a personal or account-wide credential, so a leaked Jenkins credential can't reach anything beyond this repo.

Image tags follow `<boutique-branch>-<short-sha>-b<build-number>` (e.g. `release-v0.10.7-5018f0d-b218`), and the Helm chart version is stamped the same way, so every deployed chart is traceable back to the exact Jenkins build and upstream commit that produced it.

**Jenkins agent prerequisites:**

- `awscli`
- `helm`
- `podman` — required for image building/pushing. If Jenkins itself runs as a container, the host's Podman socket needs to be mounted in and the `podman` binaries installed in the Jenkins image. Example container run command (note: mounting the host socket like this is Podman-in-Podman-ish and not best practice — it's a pragmatic shortcut for a single-node portfolio setup, not a prescription):

  ```bash
  podman run -d --name jenkins \
    --userns=keep-id \
    -v jenkins_home:/var/jenkins_home \
    -v /run/user/$(id -u)/podman/podman.sock:/run/podman/podman.sock:z \
    --restart=always \
    -e "CONTAINER_HOST=unix:///run/podman/podman.sock" \
    -e "TZ=America/Chicago" \
    -p 8080:8080 \
    docker.io/jenkins/jenkins:2.568.3-lts
  ```

  Run this directly as the user whose rootless Podman session you want Jenkins talking to — not via `sudo` or as root — since `$(id -u)` resolves to whoever evaluates the command, and `/run/user/0/podman/podman.sock` won't exist for root's session.

## CD pipeline (ArgoCD)

CD follows the **app-of-apps** pattern, with sync waves controlling order:

| Wave | Application | Source |
|---|---|---|
| 10 | `gateway-api-crds` | Upstream `kubernetes-sigs/gateway-api` CRDs |
| 20 | `aws-load-balancer-controller` | `aws/eks-charts` Helm chart, with Gateway API feature gate enabled |
| 30 | `platform` | `argocd/platform` — GatewayClass, LoadBalancerConfiguration, Gateway, ArgoCD UI HTTPRoute |
| 50 | `boutique-helm` | `boutique-helm/` — the generated application chart |

The root `app-of-apps` Application and every child Application/platform manifest are **not hand-written** — they're rendered by Terraform (`terraform-IaC/20-platform`) as `local_file` resources into `argocd/apps/` and `argocd/platform/`, then committed. This keeps the GitOps source of truth in Git while letting Terraform own templating logic (hosted zone, VPC name, environment, ACM certificate lookup, etc.) that would otherwise be duplicated by hand in YAML.

A custom Argo CD health check (installed in `10-bootstrap-argocd`) teaches Argo how to assess the health of both `Application` and `Gateway` resources, so later sync waves correctly wait for earlier ones to actually become `Healthy` rather than just "created."

## Infrastructure (Terraform)

Three independent state layers, applied in order (`terraform-IaC/00-infra` → `10-bootstrap-argocd` → `20-platform`):

- **`00-infra`** — VPC module (public/private subnets across multiple AZs) + EKS module (cluster, IAM roles, managed node group, core addons: `vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent`, `external-dns`). Supports a `dev`/`prod` `environment` switch:
  - `prod`: private subnets egress through a regional NAT Gateway (normal internet access).
  - `dev`: private subnets have **no internet egress at all** — only VPC interface/gateway endpoints to specific AWS services (ECR, STS, EC2, ELB, etc.), to keep a scratch dev cluster cheap and locked down.
- **`10-bootstrap-argocd`** — installs ArgoCD via the official `argo-cd` Helm chart and wires up the resource health customizations mentioned above.
- **`20-platform`** — reads outputs from `00-infra` via `terraform_remote_state`, then renders every ArgoCD Application/platform YAML described in the table above, plus the boutique chart's `HTTPRoute`/`TargetGroupConfiguration` templates.

`make help` in the repo root documents the build order:

```
1 - make infra      : VPC + EKS
2 - make bootstrap  : Argo CD on EKS
3 - make platform   : root app (platform + apps via Argo CD)
    make clean      : ordered teardown
```

An alternative, Terraform-free path exists via [`extras/cluster.yaml`](extras/cluster.yaml) — an `eksctl` `ClusterConfig` for quickly spinning up a disposable test cluster.

> **Creating a node group via the AWS EKS console instead of Terraform/eksctl?** At the node group creation step, the console expects an instance IAM role (e.g. named `AmazonEKSNodeRole`). `eksctl` and this repo's Terraform create that role for you automatically; if you're clicking through the console by hand, create it yourself with these AWS-managed policies attached so node instances can reach AWS service endpoints (and pull from ECR without any credential/login step):
> - `AmazonEKS_CNI_Policy`
> - `AmazonEC2ContainerRegistryReadOnly`
> - `AmazonEKSWorkerNodePolicy`
> - `AmazonElasticContainerRegistryPublicReadOnly`

## Networking

Ingress is deliberately **not** part of the application Helm chart's day-1 scope. It's layered on via:

- **Gateway API** (not classic Ingress) — `GatewayClass` → `Gateway` → `HTTPRoute`, backed by the **AWS Load Balancer Controller**'s Gateway API support (ALB).
- `LoadBalancerConfiguration` / `TargetGroupConfiguration` CRDs control ALB scheme and target-group health checks per route.
- TLS is wired up by looking up an existing **ACM certificate** for the configured hosted zone and attaching it to the Gateway's HTTPS listener.
- **ExternalDNS** (EKS addon, Pod Identity-authenticated) watches `Gateway`/`HTTPRoute` objects and manages the matching Route 53 records automatically.

Both the ArgoCD UI and the boutique `frontend` get their own `HTTPRoute`, sharing one public `Gateway`.

## Getting started

> Prerequisites: an AWS account, Terraform, Helm, `kubectl`, and (for CI) a Jenkins instance with Podman, awscli, and Helm installed.

**AWS credentials for Terraform:** none of the `provider "aws"` blocks under `terraform-IaC/` hardcode credentials. `make infra` / `make bootstrap` / `make platform` just shell out to `terraform`, which resolves AWS auth through the standard AWS SDK credential chain — so the shell you run `make` from needs one of: a default profile from `aws configure`, an exported `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` pair (plus `AWS_SESSION_TOKEN` if temporary), or an active `AWS_PROFILE`/SSO session. This is a separate credential from CI's: Jenkins authenticates with its own scoped `aws_devops_cred` for image pushes and never touches Terraform or cluster state.

```bash
# 1. Provision VPC + EKS
make infra

# 2. Install ArgoCD on the new cluster
make bootstrap

# 3. Render and apply the app-of-apps root + platform apps (also commits
#    the rendered manifests back to this repo)
make platform

# Fetch the ArgoCD initial admin password
make argo-password
```

Tear everything down in reverse with `make clean`.

Before the first run, update `terraform-IaC/00-infra/terraform.tfvars` for your own environment (CIDR ranges, `hosted_zone_name`, instance types, etc.) — defaults in this repo are specific to the author's sandbox AWS account and domain.

CI (Jenkins) is configured independently via the environment block at the top of [`Jenkinsfile`](Jenkinsfile) — the AWS credential ID, the GitHub deploy-key credential for the chart-bump push, target ECR region, and Trivy scan severity/behavior are all parameterized there.

## Security notes

- Every built image is scanned with **Trivy** for `HIGH`/`CRITICAL` CVEs, and the scan **gates the pipeline** (`CVE_FAILED_SCAN_EXT_CODE=1`) — a vulnerable image fails the build instead of just being reported; the full report is still archived as a Jenkins build artifact either way.
- The CI job's git push (Helm chart version bump) authenticates with a **GitHub deploy key scoped to this one repository**, not a personal or account-wide credential — compromising the Jenkins credential store can't leak push access beyond this repo.
- Node group and controller IAM roles/policies follow least-privilege, service-specific policies (`AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKSWorkerNodePolicy`, a dedicated AWS Load Balancer Controller policy, etc.) via **EKS Pod Identity** rather than broad node-instance permissions — and every such IAM role/policy name is suffixed with the cluster name (`${project_name}-${environment}`) so `dev` and `prod`, or a second project, can coexist in the same AWS account without an `EntityAlreadyExists` collision.
- In `dev`, node group egress is restricted to explicit VPC endpoints only — no default internet access.
- ECR authentication for pulled images relies on the node group's IAM role (no static credentials baked into manifests); Terraform itself takes no AWS credentials as input either — it resolves auth from the standard AWS SDK credential chain active in the operator's shell (see [Getting started](#getting-started)).

## Credits

- Application code and original Helm chart baseline: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) ("Online Boutique").
- Everything else (CI, CD/GitOps wiring, Terraform IaC, networking) is this project's own work, built as a hands-on DevOps/platform-engineering portfolio piece.
