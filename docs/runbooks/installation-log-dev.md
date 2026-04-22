# DEV 환경 설치 기록

> 설치일: 2026-04-22  
> AWS 계정: <ACCOUNT_ID>  
> 리전: ap-northeast-2 (서울)  
> EKS 클러스터: <EKS_CLUSTER_NAME> (v1.35)  
> 도메인: <BASE_DOMAIN>

## 변수 치환 안내

이 문서의 `< >` 변수는 실제 환경 값으로 치환해야 합니다.

| 변수 | 설명 | 예시 형식 |
|------|------|-----------|
| `<ACCOUNT_ID>` | AWS 계정 ID (12자리 숫자) | `123456789012` |
| `<IAM_USER_ID>` | IAM User 고유 ID | `AIDAEXAMPLE1234567890` |
| `<EKS_CLUSTER_NAME>` | EKS 클러스터 이름 | `my-simulator-cluster` |
| `<BASE_DOMAIN>` | Route 53에 등록된 기본 도메인 | `example.com` |
| `<OIDC_ID>` | EKS OIDC Provider ID (32자 hex) | `B5BAC3551767E46C1DA1D66CE30FEAD9` |
| `<ZONE_ID>` | Route 53 Hosted Zone ID | `Z0123456789ABCDEFGHIJ` |
| `<CERT_ID_1>` | hyundai OEM용 ACM 인증서 ID (UUID) | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| `<CERT_ID_2>` | kia OEM용 ACM 인증서 ID (UUID) | `f9e8d7c6-b5a4-3210-fedc-ba9876543210` |
| `<THUMBPRINT>` | OIDC Provider Thumbprint (40자 hex) | `9e99a48a9960b14926bb7f3b02e22da2b0ab7280` |
| `<NODE_1>`, `<NODE_2>` | EC2 노드 프라이빗 DNS 프리픽스 | `ip-10-0-1-100`, `ip-10-0-2-200` |

---

## 1. 사전 요구사항 확인

### 1.1 도구 버전 확인

```bash
$ terraform version
Terraform v1.14.7

$ kubectl version --client
Client Version: v1.35.4

$ helm version --short
v3.20.2+g8fb76d6

$ aws --version
aws-cli/2.32.25 Python/3.13.11 Linux/6.1.158-180.294.amzn2023.x86_64
```

### 1.2 AWS 인증 확인

```bash
$ aws sts get-caller-identity
{
    "UserId": "<IAM_USER_ID>",
    "Account": "<ACCOUNT_ID>",
    "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/admin"
}
```

### 1.3 EKS 클러스터 확인

```bash
$ aws eks list-clusters --region ap-northeast-2
{
    "clusters": ["<EKS_CLUSTER_NAME>"]
}

$ aws eks describe-cluster --name <EKS_CLUSTER_NAME> --region ap-northeast-2 \
    --query 'cluster.{Status:status,Endpoint:endpoint,Version:version}'
{
    "Status": "ACTIVE",
    "Endpoint": "https://<OIDC_ID>.gr7.ap-northeast-2.eks.amazonaws.com",
    "Version": "1.35"
}
```

### 1.4 Route 53 Hosted Zone 확인

```bash
$ aws route53 list-hosted-zones --query 'HostedZones[*].{Name:Name,Id:Id}'
[
    {
        "Name": "<BASE_DOMAIN>.",
        "Id": "/hostedzone/<ZONE_ID>"
    }
]
```

### 1.5 kubectl 연결

```bash
$ aws eks update-kubeconfig --name <EKS_CLUSTER_NAME> --region ap-northeast-2
Updated context arn:aws:eks:ap-northeast-2:<ACCOUNT_ID>:cluster/<EKS_CLUSTER_NAME> in ~/.kube/config

$ kubectl get nodes
NAME                                               STATUS   ROLES    AGE     VERSION
<NODE_1>.ap-northeast-2.compute.internal             Ready    <none>   5d15h   v1.35.3-eks-bbe087e
<NODE_2>.ap-northeast-2.compute.internal             Ready    <none>   5d15h   v1.35.3-eks-bbe087e
```

---

## 2. AWS Load Balancer Controller 설치

> ALB Controller는 Ingress 리소스를 감시하여 자동으로 ALB를 프로비저닝합니다.
> Simulator Platform의 Ingress가 ALB로 변환되려면 이 컨트롤러가 필수입니다.

### 2.1 OIDC Provider 생성

EKS 서비스 계정이 IAM Role을 사용하려면(IRSA) OIDC Provider가 필요합니다.

```bash
# OIDC URL 및 Thumbprint 추출
$ OIDC_URL=$(aws eks describe-cluster --name <EKS_CLUSTER_NAME> --region ap-northeast-2 \
    --query 'cluster.identity.oidc.issuer' --output text)
$ echo $OIDC_URL
https://oidc.eks.ap-northeast-2.amazonaws.com/id/<OIDC_ID>

$ THUMBPRINT=$(echo | openssl s_client -servername oidc.eks.ap-northeast-2.amazonaws.com \
    -connect oidc.eks.ap-northeast-2.amazonaws.com:443 2>/dev/null \
    | openssl x509 -fingerprint -noout \
    | sed 's/://g' | awk -F= '{print tolower($2)}')
$ echo $THUMBPRINT
<THUMBPRINT>

# OIDC Provider 생성
$ aws iam create-open-id-connect-provider \
    --url "$OIDC_URL" \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list "$THUMBPRINT"
{
    "OpenIDConnectProviderArn": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/<OIDC_ID>"
}
```

### 2.2 IAM Policy 생성

```bash
# 공식 IAM 정책 다운로드
$ curl -sL https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.12.0/docs/install/iam_policy.json \
    -o /tmp/alb-iam-policy.json

# IAM Policy 생성
$ aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file:///tmp/alb-iam-policy.json
{
    "Policy": {
        "PolicyName": "AWSLoadBalancerControllerIAMPolicy",
        "Arn": "arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy"
    }
}
```

### 2.3 IAM Role 생성 (IRSA)

Trust Policy 파일을 생성합니다. **OIDC ID와 계정 ID를 실제 환경에 맞게 변경하세요.**

```bash
$ cat > /tmp/alb-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/<OIDC_ID>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-northeast-2.amazonaws.com/id/<OIDC_ID>:aud": "sts.amazonaws.com",
          "oidc.eks.ap-northeast-2.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

# Role 생성 및 Policy 연결
$ aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file:///tmp/alb-trust-policy.json
{
    "Role": {
        "RoleName": "AmazonEKSLoadBalancerControllerRole",
        "Arn": "arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKSLoadBalancerControllerRole"
    }
}

$ aws iam attach-role-policy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy
```

### 2.4 보충 권한 추가

> 공식 IAM 정책에 `ec2:DescribeRouteTables`가 누락되어 있어 ALB 서브넷 자동 탐색이 실패합니다.
> 아래 보충 정책을 반드시 추가하세요.

```bash
$ aws iam put-role-policy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --policy-name ALBControllerSupplemental \
    --policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ec2:DescribeRouteTables",
            "ec2:DescribeVpcEndpoints"
          ],
          "Resource": "*"
        }
      ]
    }'
```

### 2.5 Kubernetes ServiceAccount 생성

```bash
$ kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKSLoadBalancerControllerRole
EOF
serviceaccount/aws-load-balancer-controller created
```

### 2.6 Helm으로 ALB Controller 설치

```bash
$ helm repo add eks https://aws.github.io/eks-charts
$ helm repo update

$ VPC_ID=$(aws eks describe-cluster --name <EKS_CLUSTER_NAME> --region ap-northeast-2 \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text)

$ helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=<EKS_CLUSTER_NAME> \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=ap-northeast-2 \
    --set vpcId=$VPC_ID
NAME: aws-load-balancer-controller
NAMESPACE: kube-system
STATUS: deployed
```

### 2.7 ALB Controller 검증

```bash
$ kubectl get deploy -n kube-system aws-load-balancer-controller
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           3m

$ kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
NAME                                            READY   STATUS    RESTARTS   AGE
aws-load-balancer-controller-566bb6db86-xc45p   1/1     Running   0          3m
aws-load-balancer-controller-566bb6db86-xd8l7   1/1     Running   0          3m
```

---

## 3. ECR 리포지토리 생성

시뮬레이터 컴포넌트 5개의 ECR 리포지토리를 생성합니다.

```bash
$ for repo in simulator-can simulator-server simulator-vehicle target-android target-cluster; do
    aws ecr create-repository --repository-name "$repo" --region ap-northeast-2 \
        --output text --query 'repository.repositoryUri'
  done
<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/simulator-can
<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/simulator-server
<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/simulator-vehicle
<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/target-android
<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/target-cluster
```

> **다음 단계**: 각 리포지토리에 컨테이너 이미지를 Push해야 합니다.
> 이미지가 없으면 시뮬레이터 Pod가 `ImagePullBackOff` 상태가 됩니다.

---

## 4. Terraform 배포

### 4.1 terraform.tfvars 설정

```bash
$ cd eks-hybrid-sim/envs/dev
$ cp terraform.tfvars.example terraform.tfvars
$ vi terraform.tfvars
```

실제 설정값:

```hcl
aws_region       = "ap-northeast-2"
base_domain      = "<BASE_DOMAIN>"
eks_cluster_name = "<EKS_CLUSTER_NAME>"
ecr_registry     = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com"
helm_chart_path  = "../../eks-simulator-helm"

hybrid_node_enabled = false

oem_users = {
  hyundai = {
    users = {
      user-a = {}
      user-b = {}
    }
  }
  kia = {
    users = {
      user-a = {}
    }
  }
}
```

### 4.2 Terraform Init

```bash
$ cd envs/dev
$ terraform init
Initializing modules...
- simulator_platform in ../..
- simulator_platform.acm in ../../modules/acm
- simulator_platform.helm_release in ../../modules/helm-release
- simulator_platform.route53 in ../../modules/route53

Initializing provider plugins...
- Installing hashicorp/kubernetes v3.1.0...
- Installing hashicorp/aws v6.41.0...
- Installing hashicorp/helm v3.1.1...

Terraform has been successfully initialized!
```

### 4.3 Terraform Plan

```bash
$ terraform plan
Plan: 10 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + acm_certificate_arns = {
      + hyundai = (known after apply)
      + kia     = (known after apply)
    }
  + user_endpoints = {
      + "hyundai/user-a" = "https://user-a.hyundai.<BASE_DOMAIN>"
      + "hyundai/user-b" = "https://user-b.hyundai.<BASE_DOMAIN>"
      + "kia/user-a"     = "https://user-a.kia.<BASE_DOMAIN>"
    }
```

생성 대상 리소스 (10개):

| # | 리소스 | 설명 |
|---|--------|------|
| 1 | `module.acm["hyundai"].aws_acm_certificate.wildcard` | `*.hyundai.<BASE_DOMAIN>` 인증서 |
| 2 | `module.acm["hyundai"].aws_route53_record.cert_validation` | ACM DNS 검증 CNAME |
| 3 | `module.acm["kia"].aws_acm_certificate.wildcard` | `*.kia.<BASE_DOMAIN>` 인증서 |
| 4 | `module.acm["kia"].aws_route53_record.cert_validation` | ACM DNS 검증 CNAME |
| 5 | `module.helm_release["hyundai/user-a"].kubernetes_namespace_v1.this` | `sim-hyundai-user-a` namespace |
| 6 | `module.helm_release["hyundai/user-a"].helm_release.simulator` | Helm 릴리스 |
| 7 | `module.helm_release["hyundai/user-b"].kubernetes_namespace_v1.this` | `sim-hyundai-user-b` namespace |
| 8 | `module.helm_release["hyundai/user-b"].helm_release.simulator` | Helm 릴리스 |
| 9 | `module.helm_release["kia/user-a"].kubernetes_namespace_v1.this` | `sim-kia-user-a` namespace |
| 10 | `module.helm_release["kia/user-a"].helm_release.simulator` | Helm 릴리스 |

### 4.4 1차 Terraform Apply (ACM + Helm)

```bash
$ terraform apply -auto-approve

module.acm["kia"].aws_acm_certificate.wildcard: Creation complete after 5s
module.acm["hyundai"].aws_acm_certificate.wildcard: Creation complete after 8s
module.acm["kia"].aws_route53_record.cert_validation: Creation complete after 32s
module.acm["hyundai"].aws_route53_record.cert_validation: Creation complete after 32s
module.helm_release["hyundai/user-a"].helm_release.simulator: Modifications complete after 1s
module.helm_release["kia/user-a"].helm_release.simulator: Modifications complete after 1s
module.helm_release["hyundai/user-b"].helm_release.simulator: Modifications complete after 1s

Apply complete! Resources: 0 added, 3 changed, 0 destroyed.

Outputs:

acm_certificate_arns = {
  "hyundai" = "arn:aws:acm:ap-northeast-2:<ACCOUNT_ID>:certificate/<CERT_ID_1>"
  "kia"     = "arn:aws:acm:ap-northeast-2:<ACCOUNT_ID>:certificate/<CERT_ID_2>"
}
user_endpoints = {
  "hyundai/user-a" = "https://user-a.hyundai.<BASE_DOMAIN>"
  "hyundai/user-b" = "https://user-b.hyundai.<BASE_DOMAIN>"
  "kia/user-a"     = "https://user-a.kia.<BASE_DOMAIN>"
}
```

### 4.5 배포 검증

```bash
# Helm 릴리스 상태
$ helm list -A --filter 'hyundai|kia'
NAME            NAMESPACE           REVISION  STATUS    CHART                      APP VERSION
hyundai-user-a  sim-hyundai-user-a  4         deployed  simulator-platform-0.1.0   1.0.0
hyundai-user-b  sim-hyundai-user-b  4         deployed  simulator-platform-0.1.0   1.0.0
kia-user-a      sim-kia-user-a      4         deployed  simulator-platform-0.1.0   1.0.0

# Namespace 확인
$ kubectl get ns -l managed-by=terraform
NAME                 STATUS   AGE
sim-hyundai-user-a   Active   5d15h
sim-hyundai-user-b   Active   5d15h
sim-kia-user-a       Active   5d15h

# Ingress 확인
$ kubectl get ingress -A -l simulator-platform/oem
NAMESPACE            NAME             CLASS   HOSTS                          PORTS   AGE
sim-hyundai-user-a   hyundai-user-a   alb     user-a.hyundai.<BASE_DOMAIN>   80      5d15h
sim-hyundai-user-b   hyundai-user-b   alb     user-b.hyundai.<BASE_DOMAIN>   80      5d15h
sim-kia-user-a       kia-user-a       alb     user-a.kia.<BASE_DOMAIN>       80      5d15h

# Pod 상태 (nginx만 Running, 시뮬레이터는 ECR 이미지 push 후 정상화)
$ kubectl get pods -A -l simulator-platform/oem --field-selector=status.phase=Running
NAMESPACE            NAME                                    READY   STATUS    AGE
sim-hyundai-user-a   hyundai-user-a-nginx-5bc4bfcccd-dmcll   1/1     Running   5d15h
sim-hyundai-user-b   hyundai-user-b-nginx-759f5d88fb-fvmws   1/1     Running   5d15h
sim-kia-user-a       kia-user-a-nginx-65659f7cfc-pgxsk       1/1     Running   5d15h
```

---

## 5. 트러블슈팅 기록

### 5.1 Namespace 이미 존재하는 경우 (terraform import)

이전 배포로 namespace가 이미 존재하면 `terraform apply`에서 에러가 발생합니다:

```
Error: namespaces "sim-hyundai-user-a" already exists
```

**해결**: 기존 리소스를 Terraform state로 import합니다.

```bash
# Namespace import
$ terraform import \
    'module.simulator_platform.module.helm_release["hyundai/user-a"].kubernetes_namespace_v1.this' \
    sim-hyundai-user-a

# Helm release import
$ terraform import \
    'module.simulator_platform.module.helm_release["hyundai/user-a"].helm_release.simulator' \
    sim-hyundai-user-a/hyundai-user-a
```

> 모든 OEM/User 조합에 대해 반복합니다.
> import 후 `terraform apply`를 재실행하면 state와 동기화됩니다.

### 5.2 ALB Controller — ec2:DescribeRouteTables 권한 오류

```
error: couldn't auto-discover subnets: failed to list subnets by reachability:
  operation error EC2: DescribeRouteTables ... UnauthorizedOperation
```

**원인**: 공식 IAM 정책(v2.12.0)에 `ec2:DescribeRouteTables` 권한이 누락되어 있습니다.

**해결**: 2.4절의 보충 정책을 추가한 뒤 Controller를 재시작합니다.

```bash
$ kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
$ kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=60s
deployment "aws-load-balancer-controller" successfully rolled out
```

### 5.3 ALB Ingress Group — tag 충돌

```
error: conflicting tag Environment: sim-hyundai-user-a | sim-hyundai-user-b
```

**원인**: 같은 ALB Group(`ajt-hyundai`)에 속하는 여러 Ingress가 서로 다른 `Environment` tag 값을 가지면 ALB Controller가 충돌로 처리합니다.

**해결**: `eks-simulator-helm/templates/ingress.yaml` 28번 줄을 수정합니다.

```yaml
# 변경 전 (user별로 다른 값 → 충돌)
alb.ingress.kubernetes.io/tags: "Environment={{ .Release.Namespace }},OEM={{ .Values.oemId }},User={{ .Values.userId }},ManagedBy=helm"

# 변경 후 (OEM 수준으로 통일)
alb.ingress.kubernetes.io/tags: "OEM={{ .Values.oemId }},ManagedBy=helm"
```

수정 후 Helm upgrade:

```bash
$ helm upgrade hyundai-user-a ./eks-simulator-helm -n sim-hyundai-user-a --reuse-values
$ helm upgrade hyundai-user-b ./eks-simulator-helm -n sim-hyundai-user-b --reuse-values
$ helm upgrade kia-user-a     ./eks-simulator-helm -n sim-kia-user-a     --reuse-values
```

### 5.4 ACM 인증서 PENDING_VALIDATION

```bash
$ aws acm describe-certificate \
    --certificate-arn arn:aws:acm:ap-northeast-2:<ACCOUNT_ID>:certificate/<CERT_ID_1> \
    --query 'Certificate.Status'
"PENDING_VALIDATION"
```

**원인**: 도메인 `<BASE_DOMAIN>`의 NS 레코드가 Route 53 네임서버로 위임되지 않았습니다.

**해결**: 도메인 등록기관에서 아래 네임서버를 설정합니다.

```
ns-715.awsdns-25.net
ns-184.awsdns-23.com
ns-1306.awsdns-35.org
ns-1650.awsdns-14.co.uk
```

NS 위임 후 ACM이 자동으로 ISSUED 상태로 전환됩니다 (최대 수십 분 소요).

---

## 6. 남은 작업

### 6.1 도메인 NS 위임 (필수)

도메인 등록기관(가비아, Route 53 Registrar 등)에서 Route 53 네임서버를 설정합니다.
ACM 인증서가 ISSUED로 전환되어야 ALB HTTPS Listener가 생성됩니다.

### 6.2 ECR 이미지 Push (필수)

```bash
# ECR 로그인
$ aws ecr get-login-password --region ap-northeast-2 \
    | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com

# 각 컴포넌트별 이미지 Push (예시)
$ docker tag simulator-server:latest <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/simulator-server:latest
$ docker push <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/simulator-server:latest

# 전체 컴포넌트: simulator-can, simulator-server, simulator-vehicle, target-android, target-cluster
```

이미지 Push 후 Pod가 자동으로 이미지를 Pull하여 Running 상태가 됩니다.

### 6.3 2차 Terraform Apply — Route 53 Alias (ACM ISSUED 후)

ACM이 ISSUED 되고 ALB가 프로비저닝되면:

```bash
# OEM별 ALB DNS 확인
$ kubectl get ingress -A -l simulator-platform/oem=hyundai \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

$ kubectl get ingress -A -l simulator-platform/oem=kia \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

`terraform.tfvars`에 추가:

```hcl
alb_dns_overrides = {
  hyundai = "<위에서 확인한 hyundai ALB DNS>"
  kia     = "<위에서 확인한 kia ALB DNS>"
}
```

```bash
$ terraform apply
```

### 6.4 최종 검증

```bash
$ terraform output user_endpoints
$ kubectl get pods -A -l simulator-platform/oem
$ curl -k https://user-a.hyundai.<BASE_DOMAIN>/health
```

---

## 생성된 AWS 리소스 요약

| 리소스 | 이름/ARN | 용도 |
|--------|----------|------|
| OIDC Provider | `arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/<OIDC_ID>` | IRSA |
| IAM Policy | `arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy` | ALB Controller 권한 |
| IAM Role | `arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKSLoadBalancerControllerRole` | ALB Controller ServiceAccount |
| ACM 인증서 | `arn:aws:acm:ap-northeast-2:<ACCOUNT_ID>:certificate/<CERT_ID_1>` | `*.hyundai.<BASE_DOMAIN>` |
| ACM 인증서 | `arn:aws:acm:ap-northeast-2:<ACCOUNT_ID>:certificate/<CERT_ID_2>` | `*.kia.<BASE_DOMAIN>` |
| ECR 리포지토리 | `simulator-can`, `simulator-server`, `simulator-vehicle`, `target-android`, `target-cluster` | 컨테이너 이미지 |
| Helm Release | `hyundai-user-a`, `hyundai-user-b`, `kia-user-a` | 시뮬레이터 배포 |
| K8s Namespace | `sim-hyundai-user-a`, `sim-hyundai-user-b`, `sim-kia-user-a` | 격리 환경 |
