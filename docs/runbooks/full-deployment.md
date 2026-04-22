# Runbook: 전체 배포 (Full Deployment)

## Overview

Simulator Platform을 EKS 클러스터에 처음부터 배포하는 전체 절차입니다. Terraform을 통해 ACM 인증서, Helm 릴리스, Route 53 레코드를 프로비저닝합니다.

## When to Use

- 신규 환경(dev/staging/prod)에 Simulator Platform을 최초 배포할 때
- 기존 환경을 `terraform destroy` 후 재구축할 때

## Prerequisites

- [ ] AWS CLI v2 인증 완료 (`aws sts get-caller-identity`)
- [ ] Terraform >= 1.5 설치
- [ ] kubectl 설치
- [ ] Helm >= 3.12 설치
- [ ] EKS 클러스터 생성 및 ACTIVE 상태
- [ ] EKS 노드 그룹 생성 및 Ready 상태
- [ ] AWS Load Balancer Controller 설치 완료
- [ ] Route 53 Hosted Zone (`example.com`) 존재
- [ ] ECR에 컨테이너 이미지 Push 완료
- [ ] Helm Chart 경로 확인 (`eks-simulator-helm/`)

## Procedure

### 1. 환경 변수 설정

`envs/dev/terraform.tfvars`를 환경에 맞게 편집합니다.

```bash
cd eks-hybrid-sim
vi envs/dev/terraform.tfvars
```

필수 변경 항목:

```hcl
eks_cluster_name = "<실제 클러스터 이름>"
ecr_registry     = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com"
```

**검증:**

```bash
# 클러스터 존재 확인
aws eks describe-cluster --name <클러스터 이름> --query 'cluster.status'

# ECR 이미지 존재 확인
aws ecr list-images --repository-name simulator-server --query 'imageIds[*].imageTag'
```

### 2. Terraform Init

```bash
cd envs/dev
terraform init
```

**검증:** `Terraform has been successfully initialized!` 메시지 확인

### 3. Terraform Plan

```bash
terraform plan
```

**검증 항목:**
- `Plan: N to add, 0 to change, 0 to destroy` 출력 확인
- ACM 인증서 도메인이 올바른지 확인 (`*.{oem}.example.com`)
- Helm release namespace가 `sim-{oem}-{user}` 형식인지 확인
- ECR registry 주소가 올바른 계정 ID인지 확인

### 4. 1차 Terraform Apply (ACM + Helm)

```bash
terraform apply
```

`yes` 입력하여 적용합니다.

**예상 소요 시간:** 1~2분 (ACM 검증 제외)

**검증:**

```bash
# Terraform output 확인
terraform output

# Helm 릴리스 상태 확인
helm list -A

# Namespace 확인
kubectl get namespaces -l managed-by=terraform

# Pod 상태 확인
kubectl get pods -A -l simulator-platform/oem
```

모든 Pod가 `Running` 상태여야 합니다. `ImagePullBackOff`인 경우 ECR 이미지를 확인하세요.

### 5. ALB DNS 확인 (Load Balancer Controller 필요)

Ingress가 생성되면 ALB Controller가 자동으로 ALB를 프로비저닝합니다.

```bash
# OEM별 ALB DNS 확인
kubectl get ingress -A -l simulator-platform/oem=hyundai \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
echo

kubectl get ingress -A -l simulator-platform/oem=kia \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
echo
```

ADDRESS가 비어있으면 ALB Controller 설치 상태를 확인하세요:

```bash
kubectl get deploy -n kube-system aws-load-balancer-controller
```

### 6. 2차 Terraform Apply (Route 53 Alias)

ALB DNS를 `terraform.tfvars`에 추가합니다:

```hcl
alb_dns_overrides = {
  hyundai = "<hyundai ALB DNS>"
  kia     = "<kia ALB DNS>"
}
```

```bash
terraform apply
```

**검증:**

```bash
# Route 53 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --query "ResourceRecordSets[?Type=='A']"

# 엔드포인트 접속 테스트
curl -k https://user-a.hyundai.example.com/health
```

## Verification

- [ ] `terraform output`에 모든 user_endpoints가 표시됨
- [ ] `helm list -A`에 모든 릴리스가 `deployed` 상태
- [ ] `kubectl get pods -A -l simulator-platform/oem` — 모든 Pod `Running`
- [ ] `kubectl get ingress -A` — ADDRESS에 ALB DNS 할당됨
- [ ] `curl -k https://<user>.<oem>.example.com/health` — 200 응답

## Rollback

배포 중 문제가 발생한 경우:

1. **Helm 릴리스만 롤백:**
   ```bash
   helm rollback <release-name> <revision> -n <namespace>
   # 예: helm rollback hyundai-user-a 1 -n sim-hyundai-user-a
   ```

2. **전체 인프라 롤백:**
   ```bash
   terraform destroy
   ```

3. **특정 리소스만 제거 후 재생성:**
   ```bash
   terraform destroy -target='module.simulator_platform.module.helm_release["hyundai/user-a"]'
   terraform apply
   ```

## Notes

- Last verified: 2026-04-19
- ACM DNS 검증은 도메인 NS 위임이 완료되어야 ISSUED 상태로 전환됩니다
- `hybrid_node_enabled = true` 사용 시 Hybrid Node가 클러스터에 등록되어 있어야 합니다
- Helm chart 경로(`helm_chart_path`)는 `envs/dev/` 기준 상대 경로입니다
