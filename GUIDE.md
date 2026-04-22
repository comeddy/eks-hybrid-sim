# Simulator Platform 통합 배포 가이드

## 1. 개요

OEM별 시뮬레이터 환경을 EKS 클러스터 위에 Terraform + Helm으로 자동 프로비저닝하는 플랫폼입니다.

**한 번의 `terraform apply`로 아래가 자동 생성됩니다:**
- OEM별 ACM 와일드카드 인증서 (`*.{oem}.example.com`)
- OEM별 Route 53 DNS Alias 레코드 → ALB
- User별 Kubernetes namespace + Helm 릴리스 (6개 컴포넌트)

### 아키텍처

```
terraform apply
 │
 ├─ module.acm["hyundai"]           → *.hyundai.example.com 인증서
 ├─ module.acm["kia"]               → *.kia.example.com 인증서
 │
 ├─ module.route53["hyundai"]       → *.hyundai.example.com → ALB Alias
 ├─ module.route53["kia"]           → *.kia.example.com     → ALB Alias
 │
 ├─ module.helm_release["hyundai/user-a"]  → ns: sim-hyundai-user-a
 ├─ module.helm_release["hyundai/user-b"]  → ns: sim-hyundai-user-b
 ├─ module.helm_release["hyundai/user-c"]  → ns: sim-hyundai-user-c
 └─ module.helm_release["kia/user-a"]      → ns: sim-kia-user-a
```

### 각 User namespace 내 컴포넌트

| 컴포넌트 | Deployment | Service Port | 역할 |
|----------|-----------|-------------|------|
| nginx    | `{oem}-{user}-nginx` | 80 | 리버스 프록시 |
| simulator-server | `{oem}-{user}-server` | 8002 | 시뮬레이터 메인 서버 |
| simulator-can | `{oem}-{user}-can` | 8001 | CAN 통신 시뮬레이터 |
| simulator-vehicle | `{oem}-{user}-vehicle` | 8003 | 차량 시뮬레이터 |
| target-android | `{oem}-{user}-android` | 8004 | Android 타겟 |
| target-cluster | `{oem}-{user}-cluster` | 8005 | 클러스터 타겟 |

---

## 2. 사전 요구사항

| 항목 | 최소 버전 | 확인 명령어 |
|------|----------|------------|
| Terraform | >= 1.5 | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| kubectl | >= 1.27 | `kubectl version --client` |
| Helm | >= 3.12 | `helm version` |
| EKS 클러스터 | 생성 완료 | `aws eks describe-cluster --name <name>` |
| AWS Load Balancer Controller | 설치 완료 | `kubectl get deploy -n kube-system aws-load-balancer-controller` |
| Route 53 Hosted Zone | `example.com` | `aws route53 list-hosted-zones` |
| ECR 이미지 | Push 완료 | `aws ecr list-images --repository-name <repo>` |

### 2.1 EKS 클러스터가 없는 경우

```bash
# IAM Role 생성
aws iam create-role \
  --role-name <cluster-name>-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{"Effect":"Allow","Principal":{"Service":"eks.amazonaws.com"},"Action":"sts:AssumeRole"}]
  }'

aws iam attach-role-policy --role-name <cluster-name>-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# 클러스터 생성
aws eks create-cluster \
  --name <cluster-name> \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/<cluster-name>-role \
  --resources-vpc-config subnetIds=<subnet-1>,<subnet-2>

# 활성화 대기 (~15분)
aws eks wait cluster-active --name <cluster-name>

# kubeconfig 설정
aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2

# 노드 그룹 생성
aws iam create-role --role-name <cluster-name>-node-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]
  }'

aws iam attach-role-policy --role-name <cluster-name>-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name <cluster-name>-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name <cluster-name>-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws eks create-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <cluster-name>-nodes \
  --node-role arn:aws:iam::<ACCOUNT_ID>:role/<cluster-name>-node-role \
  --subnets <subnet-1> <subnet-2> \
  --scaling-config minSize=2,maxSize=4,desiredSize=2 \
  --instance-types t3.medium
```

### 2.2 AWS Load Balancer Controller 설치

Ingress → ALB 자동 생성에 필요합니다. [공식 가이드](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)를 참고하세요.

```bash
# OIDC Provider 생성
eksctl utils associate-iam-oidc-provider --cluster <cluster-name> --approve

# IAM Policy 생성
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

# Service Account + Controller 설치
eksctl create iamserviceaccount \
  --cluster=<cluster-name> \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

---

## 3. 디렉토리 구조

```
eks-hybrid-sim/
├── main.tf                  # 모듈 오케스트레이션
├── variables.tf             # 입력 변수 정의
├── outputs.tf               # 출력값
├── locals.tf                # oem_users flatten 로직
├── providers.tf             # AWS / Kubernetes / Helm provider
├── versions.tf              # terraform & provider 버전
│
├── modules/
│   ├── acm/                 # OEM별 ACM 와일드카드 인증서 + DNS 검증
│   ├── route53/             # OEM별 와일드카드 DNS Alias → ALB
│   └── helm-release/        # User별 Helm 릴리스 + namespace 생성
│
├── envs/
│   └── dev/
│       ├── backend.tf       # Root module wrapper (여기서 실행)
│       └── terraform.tfvars # 환경별 변수값
│
└── ../eks-simulator-helm/   # Helm Chart (별도 디렉토리)
```

---

## 4. 배포 (2단계 Apply)

### 4.1 환경 변수 설정

`envs/dev/terraform.tfvars`를 환경에 맞게 수정합니다:

```hcl
aws_region       = "ap-northeast-2"
base_domain      = "example.com"
eks_cluster_name = "my-eks-cluster"      # ← 실제 클러스터 이름
ecr_registry     = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com"
helm_chart_path  = "../../eks-simulator-helm"

hybrid_node_enabled = false    # Hybrid Node 사용 시 true

oem_users = {
  hyundai = {
    users = {
      user-a = {
        simulator_server_tag = "v1.3.0"
        simulator_can_tag    = "v1.2.0"
      }
      user-b = {}
      user-c = {
        simulator_server_replicas = 2
      }
    }
  }
  kia = {
    users = {
      user-a = {
        simulator_vehicle_tag = "v2.0.0"
      }
    }
  }
}
```

### 4.2 1단계 — ACM 인증서 + Helm 배포

```bash
cd envs/dev

terraform init
terraform plan
terraform apply
```

이 단계에서 생성되는 리소스:
- ACM 와일드카드 인증서 (OEM당 1개)
- Route 53 DNS 검증 레코드
- Kubernetes namespace (User당 1개)
- Helm 릴리스 (User당 1개, 각 6개 컴포넌트)

### 4.3 2단계 — ALB DNS 확인 후 Route 53 연결

AWS Load Balancer Controller가 Ingress를 감지하면 ALB가 자동 생성됩니다.

```bash
# OEM별 ALB DNS 확인
kubectl get ingress -A -l simulator-platform/oem=hyundai \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

kubectl get ingress -A -l simulator-platform/oem=kia \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

확인한 ALB DNS를 `terraform.tfvars`에 추가:

```hcl
alb_dns_overrides = {
  hyundai = "k8s-ajthyundai-xxxx.ap-northeast-2.elb.amazonaws.com"
  kia     = "k8s-ajtkia-yyyy.ap-northeast-2.elb.amazonaws.com"
}
```

```bash
terraform apply
```

---

## 5. 배포 확인

```bash
# Terraform 상태 확인
terraform output

# Helm 릴리스 확인
helm list -A

# Namespace 확인
kubectl get namespaces -l managed-by=terraform

# 전체 Pod 상태
kubectl get pods -A -l simulator-platform/oem

# 특정 User의 리소스 상세
kubectl get deploy,svc,ingress -n sim-hyundai-user-a

# Ingress/ALB 상태
kubectl get ingress -A -l simulator-platform/oem

# 접속 테스트
curl -k https://user-a.hyundai.example.com/health
```

---

## 6. 운영 가이드

### 6.1 OEM 추가

`terraform.tfvars`에 블록 하나만 추가:

```hcl
oem_users = {
  hyundai = { ... }   # 기존
  kia     = { ... }   # 기존

  # 신규 OEM
  toyota = {
    users = {
      user-a = {}
      user-b = { simulator_server_tag = "v3.0.0" }
    }
  }
}
```

```bash
terraform apply
# → ACM 인증서 (*.toyota.example.com) 자동 발급
# → Helm 릴리스 (toyota/user-a, toyota/user-b) 자동 배포
```

### 6.2 User 추가 / 삭제

```hcl
hyundai = {
  users = {
    user-a = { ... }
    user-b = { ... }
    user-d = {}          # ← 추가
    # user-c 삭제       # ← 블록 제거
  }
}
```

```bash
terraform apply
# → user-d namespace + Helm 자동 생성
# → user-c namespace + Helm 자동 삭제
```

### 6.3 이미지 태그 업데이트 (배포 업그레이드)

```hcl
user-a = {
  simulator_server_tag = "v2.0.0"   # 변경
}
```

```bash
terraform apply
# → Helm upgrade 자동 실행, Pod rolling update
```

### 6.4 서버 스케일아웃

```hcl
user-c = {
  simulator_server_replicas = 3   # 1 → 3
}
```

```bash
terraform apply
```

---

## 7. User별 설정 가능 옵션

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `simulator_can_tag` | string | `"latest"` | CAN 시뮬레이터 이미지 태그 |
| `simulator_server_tag` | string | `"latest"` | 메인 서버 이미지 태그 |
| `simulator_vehicle_tag` | string | `"latest"` | 차량 시뮬레이터 이미지 태그 |
| `target_android_tag` | string | `"latest"` | Android 타겟 이미지 태그 |
| `target_cluster_tag` | string | `"latest"` | 클러스터 타겟 이미지 태그 |
| `simulator_server_replicas` | number | `1` | Server Pod 레플리카 수 |

---

## 8. ECR 이미지 준비

Helm 배포 후 Pod가 정상 실행되려면 ECR에 이미지가 존재해야 합니다.

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com

# 리포지토리 생성 (최초 1회)
for repo in simulator-server simulator-can simulator-vehicle target-android target-cluster; do
  aws ecr create-repository --repository-name $repo --region ap-northeast-2
done

# 이미지 빌드 & Push
docker build -t <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/simulator-server:v1.3.0 .
docker push <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/simulator-server:v1.3.0
```

이미지 Push 후 Pod가 `ImagePullBackOff` → `Running`으로 자동 전환됩니다.

---

## 9. 트러블슈팅

### Pod가 Pending 상태

```bash
kubectl describe pod <pod-name> -n <namespace>
```

| Events 메시지 | 원인 | 해결 |
|--------------|------|------|
| `didn't match Pod's node affinity/selector` | Hybrid Node 설정 불일치 | `hybrid_node_enabled = false` 또는 Hybrid Node 등록 |
| `Insufficient cpu/memory` | 노드 리소스 부족 | 노드 그룹 스케일업 |
| `no nodes available` | 노드 없음 | 노드 그룹 생성 확인 |

### Pod가 ImagePullBackOff

```bash
kubectl describe pod <pod-name> -n <namespace> | grep -A5 Events
```

| 원인 | 해결 |
|------|------|
| ECR에 이미지 없음 | 이미지 빌드 후 Push |
| ECR 권한 없음 | 노드 IAM Role에 `AmazonEC2ContainerRegistryReadOnly` 정책 연결 |
| 태그 불일치 | `terraform.tfvars`의 태그와 ECR 이미지 태그 확인 |

### ACM 인증서가 PENDING_VALIDATION

```bash
aws acm describe-certificate --certificate-arn <ARN> --query 'Certificate.DomainValidationOptions'
```

| 원인 | 해결 |
|------|------|
| 도메인 NS 미위임 | 도메인 등록 기관에서 Route 53 네임서버 설정 |
| DNS 전파 지연 | 최대 48시간 대기 |

### Ingress에 ADDRESS가 없음

| 원인 | 해결 |
|------|------|
| ALB Controller 미설치 | 섹션 2.2 참고하여 설치 |
| Controller 권한 부족 | IAM Policy 확인 |

---

## 10. 리소스 정리

```bash
cd envs/dev

# 전체 삭제 (Helm 릴리스 + ACM + Route53 + namespace)
terraform destroy
```

> EKS 클러스터와 노드 그룹은 Terraform 외부에서 생성한 경우 별도로 삭제해야 합니다.

```bash
aws eks delete-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>
aws eks wait nodegroup-deleted --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>
aws eks delete-cluster --name <cluster-name>
```
