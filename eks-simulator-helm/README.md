# Simulator Platform Helm Chart

EKS Hybrid Node 기반 시뮬레이터 플랫폼을 배포하기 위한 Helm Chart입니다.

## 아키텍처

```
                    ┌──────────────────────────────────────────────┐
                    │      AWS ALB  (OEM별 group으로 공유)            │
                    │      alb.ingress.kubernetes.io               │
                    └──────────┬──────────────┬────────────────────┘
                               │              │
         user-a.oem.example.com    user-b.oem.example.com
                               │              │
                        ┌──────┴──────┐ ┌─────┴───────┐
                        │ Nginx Proxy │ │ Nginx Proxy │  ...
                        │  (user-a)   │ │  (user-b)   │
                        └──────┬──────┘ └──────┬──────┘
                               │               │
               ┌───────────────┼───────────────┤
               │    /can/   /server/  /vehicle/ │ /android/  /cluster/
               ▼        ▼        ▼        ▼         ▼
         ┌──────┐ ┌────────┐ ┌───────┐ ┌───────┐ ┌───────┐
         │ CAN  │ │ Server │ │Vehicle│ │Android│ │Cluster│
         │ Pod  │ │  Pod   │ │  Pod  │ │  Pod  │ │  Pod  │
         │:8001 │ │ :8002  │ │ :8003 │ │ :8004 │ │ :8005 │
         └──────┘ └────────┘ └───────┘ └───────┘ └───────┘
               ▲        ▲        ▲        ▲         ▲
               └────────┴────────┴────────┴─────────┘
                     EKS Hybrid Node (On-Prem)
```

## 사전 요구사항

- Kubernetes 1.25+
- Helm 3.x
- AWS Load Balancer Controller 설치
- EKS Hybrid Node 구성 완료
- ACM 와일드카드 인증서 (*.oem.example.com)

## 설치

### 기본 설치 (Terraform 통합)

이 차트는 일반적으로 Terraform `helm_release` 리소스를 통해 배포됩니다:

```hcl
module "helm_release" {
  source   = "./modules/helm-release"
  for_each = local.oem_user_flat

  oem_id  = each.value.oem_id
  user_id = each.value.user_id
  # ... 기타 설정
}
```

### 수동 설치

```bash
# Hyundai OEM - User A
helm install hyundai-user-a ./eks-simulator-helm \
  --namespace sim-hyundai-user-a \
  --create-namespace \
  -f examples/values-hyundai-user-a.yaml

# KIA OEM - User B (Production)
helm install kia-user-b ./eks-simulator-helm \
  --namespace sim-kia-user-b \
  --create-namespace \
  -f examples/values-kia-user-b.yaml \
  -f examples/values-production.yaml
```

## 설정 값

### 필수 설정

| 파라미터 | 설명 | 기본값 |
|----------|------|--------|
| `userId` | 사용자 ID | `user-a` |
| `oemId` | OEM ID (hyundai, kia 등) | `hyundai` |
| `imageRegistry` | ECR 레지스트리 주소 | `""` |
| `ingress.baseDomain` | 기본 도메인 | `example.com` |
| `ingress.annotations."alb.ingress.kubernetes.io/certificate-arn"` | ACM 인증서 ARN | `""` |

### 컴포넌트 설정

각 컴포넌트는 다음 설정을 지원합니다:

| 파라미터 | 설명 | 기본값 |
|----------|------|--------|
| `{component}.enabled` | 컴포넌트 활성화 | `true` |
| `{component}.image.tag` | 이미지 태그 | `latest` |
| `{component}.replicas` | 레플리카 수 | `1` |
| `{component}.resources` | 리소스 요청/제한 | 컴포넌트별 상이 |
| `{component}.env` | 환경 변수 | `[]` |

**컴포넌트 목록:**
- `simulatorCan` (port: 8001)
- `simulatorServer` (port: 8002)
- `simulatorVehicle` (port: 8003)
- `targetAndroid` (port: 8004)
- `targetCluster` (port: 8005)
- `nginxProxy` (port: 80)

### Hybrid Node 설정

```yaml
hybridNode:
  enabled: true
  nodeSelector:
    eks.amazonaws.com/compute-type: hybrid
  tolerations:
    - key: "eks.amazonaws.com/compute-type"
      operator: "Equal"
      value: "hybrid"
      effect: "NoSchedule"
```

## 도메인 규칙

도메인은 다음 형식으로 생성됩니다:

```
{userId}.{oemId}.{baseDomain}
```

예시:
- `user-a.hyundai.example.com`
- `user-b.kia.example.com`
- `test-user.genesis.example.com`

## ALB 그룹 공유

같은 OEM의 모든 사용자는 하나의 ALB를 공유합니다:

- ALB Group Name: `ajt-{oemId}` (예: `ajt-hyundai`, `ajt-kia`)
- 와일드카드 인증서: `*.{oemId}.{baseDomain}`

## 업그레이드

```bash
helm upgrade hyundai-user-a ./eks-simulator-helm \
  --namespace sim-hyundai-user-a \
  -f examples/values-hyundai-user-a.yaml
```

## 삭제

```bash
helm uninstall hyundai-user-a --namespace sim-hyundai-user-a
kubectl delete namespace sim-hyundai-user-a
```

## 트러블슈팅

### Pod가 Pending 상태인 경우

```bash
# Hybrid Node 상태 확인
kubectl get nodes -l eks.amazonaws.com/compute-type=hybrid

# Pod 이벤트 확인
kubectl describe pod -n sim-hyundai-user-a -l simulator-platform/user=user-a
```

### Ingress/ALB 문제

```bash
# Ingress 상태 확인
kubectl get ingress -n sim-hyundai-user-a

# ALB Controller 로그 확인
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## 라이선스

Copyright (c) 2024. All rights reserved.
