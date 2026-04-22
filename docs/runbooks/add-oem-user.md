# Runbook: OEM / User 추가

## Overview

기존 Simulator Platform에 신규 OEM 또는 User를 추가하는 절차입니다. `terraform.tfvars`에 블록을 추가하고 `terraform apply`만 실행하면 ACM 인증서, namespace, Helm 릴리스가 자동 생성됩니다.

## When to Use

- 신규 OEM(자동차 제조사)을 플랫폼에 온보딩할 때
- 기존 OEM에 새로운 User 환경을 추가할 때
- User별 이미지 태그 또는 replicas를 변경할 때

## Prerequisites

- [ ] Terraform 배포가 정상 완료된 상태 (`terraform output` 확인)
- [ ] 신규 OEM 추가 시: ECR에 해당 OEM용 이미지가 준비되어 있어야 함
- [ ] `envs/dev/terraform.tfvars` 편집 권한

## Procedure

### 1. 신규 OEM 추가

`envs/dev/terraform.tfvars`의 `oem_users` 블록에 추가합니다:

```hcl
oem_users = {
  hyundai = { ... }   # 기존 — 수정하지 않음
  kia     = { ... }   # 기존 — 수정하지 않음

  # 신규 OEM 추가
  toyota = {
    users = {
      user-a = {}
      user-b = {
        simulator_server_tag = "v3.0.0"
      }
    }
  }
}
```

### 2. 기존 OEM에 User 추가

해당 OEM의 `users` 블록에 추가합니다:

```hcl
hyundai = {
  users = {
    user-a = { ... }   # 기존
    user-b = { ... }   # 기존
    user-c = { ... }   # 기존

    # 신규 User 추가
    user-d = {
      simulator_server_tag      = "v2.1.0"
      simulator_server_replicas = 2
    }
  }
}
```

### 3. 변경 사항 확인

```bash
cd envs/dev
terraform plan
```

**확인 항목:**
- 신규 OEM 추가 시: ACM 인증서 + namespace + Helm release가 Plan에 포함되는지 확인
- User 추가 시: namespace + Helm release만 Plan에 포함되는지 확인
- 기존 리소스에 `destroy` 또는 `change`가 없는지 확인

**예상 출력 (OEM 추가):**

```
Plan: 5 to add, 0 to change, 0 to destroy.
  # module.simulator_platform.module.acm["toyota"]...
  # module.simulator_platform.module.helm_release["toyota/user-a"]...
  # module.simulator_platform.module.helm_release["toyota/user-b"]...
```

**예상 출력 (User 추가):**

```
Plan: 2 to add, 0 to change, 0 to destroy.
  # module.simulator_platform.module.helm_release["hyundai/user-d"]...
```

### 4. Apply

```bash
terraform apply
```

### 5. 배포 확인

```bash
# 신규 namespace 확인
kubectl get namespaces -l managed-by=terraform

# 신규 Pod 확인
kubectl get pods -n sim-<oem>-<user>

# Helm 릴리스 확인
helm list -n sim-<oem>-<user>

# Ingress 확인
kubectl get ingress -n sim-<oem>-<user>
```

### 6. ALB DNS 업데이트 (OEM 추가 시만)

신규 OEM은 별도의 ALB Ingress Group이 생성됩니다. ALB DNS를 확인하고 `terraform.tfvars`에 추가합니다:

```bash
kubectl get ingress -A -l simulator-platform/oem=toyota \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

```hcl
alb_dns_overrides = {
  hyundai = "..."     # 기존
  kia     = "..."     # 기존
  toyota  = "<새 ALB DNS>"   # 추가
}
```

```bash
terraform apply
```

## Verification

- [ ] `terraform output user_endpoints`에 신규 엔드포인트 표시
- [ ] `kubectl get pods -n sim-<oem>-<user>` — 모든 Pod Running
- [ ] `helm list -n sim-<oem>-<user>` — STATUS: deployed
- [ ] `curl -k https://<user>.<oem>.example.com/health` — 정상 응답

## Rollback

추가한 OEM/User를 제거하려면:

1. `terraform.tfvars`에서 해당 블록을 삭제합니다.
2. ```bash
   terraform apply
   ```
   Terraform이 자동으로 namespace, Helm release, (OEM의 경우) ACM 인증서를 삭제합니다.

또는 특정 리소스만 제거:

```bash
# 특정 User만 제거
terraform destroy -target='module.simulator_platform.module.helm_release["toyota/user-a"]'
```

## Notes

- Last verified: 2026-04-19
- User 추가 시 기존 User의 다운타임은 없습니다 (독립적인 namespace)
- OEM 추가 시 ACM 인증서 발급에 DNS 검증이 필요합니다 (도메인 NS 위임 필요)
- User ID는 kebab-case를 사용합니다 (예: `user-a`, `team-alpha`)
- 사용 가능한 설정 옵션: `simulator_can_tag`, `simulator_server_tag`, `simulator_vehicle_tag`, `target_android_tag`, `target_cluster_tag`, `simulator_server_replicas`
