# Onboarding Guide

## Prerequisites

| Tool | Version | Installation |
|------|---------|-------------|
| Terraform | >= 1.5.0 | `brew install terraform` or [tfenv](https://github.com/tfutils/tfenv) |
| Helm | >= 3.12 | `brew install helm` |
| kubectl | latest | `brew install kubectl` |
| AWS CLI | v2 | [Install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |

## AWS Access Setup

```bash
aws configure
aws sts get-caller-identity
```

Required IAM permissions:
- EKS: `DescribeCluster`, `ListClusters`
- ACM: `RequestCertificate`, `DescribeCertificate`, `DeleteCertificate`
- Route 53: `ChangeResourceRecordSets`, `ListHostedZones`
- Helm/K8s: Cluster admin or namespace-scoped RBAC

## EKS Cluster Access

```bash
aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2
kubectl get nodes
```

## Project Setup

```bash
git clone https://github.com/comeddy/eks-hybrid-sim.git
cd eks-hybrid-sim

# Setup environment
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # Fill in required values

# Initialize
terraform init
terraform plan
```

## Key Concepts

### OEM / User Model

Each OEM (e.g., hyundai, kia) has multiple users. Each user gets:
- Dedicated Kubernetes namespace: `sim-{oem}-{user}`
- Full simulator stack (6 pods)
- Unique FQDN: `{user}.{oem}.{domain}`

### Two-Phase Apply

First apply creates ACM certs + Helm releases. Second apply (after ALB is provisioned) creates Route 53 DNS records.

### Module Structure

```
main.tf           → Orchestration (ACM → Route53 → Helm)
modules/acm/      → Wildcard TLS certificates
modules/route53/  → DNS alias records
modules/helm-release/ → K8s namespace + Helm release
```

## Daily Operations

| Task | Command |
|------|---------|
| Check pod status | `kubectl get pods -A -l simulator-platform/oem` |
| Check Helm releases | `helm list -A` |
| Preview changes | `cd envs/dev && terraform plan` |
| Apply changes | `cd envs/dev && terraform apply` |
| View endpoints | `terraform output user_endpoints` |

## Further Reading

- [Architecture](architecture.md)
- [Full Deployment Runbook](runbooks/full-deployment.md)
- [Troubleshooting](runbooks/troubleshooting.md)
