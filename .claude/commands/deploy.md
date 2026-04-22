# Deploy

Terraform 배포를 실행합니다.

## Pre-Deploy Checks

1. 현재 환경 확인:
```bash
cd envs/dev
echo "Workspace: $(terraform workspace show 2>/dev/null || echo 'default')"
echo "Backend: $(grep -l 'backend' *.tf 2>/dev/null || echo 'local')"
```

2. Plan 실행 및 검토:
```bash
cd envs/dev && terraform plan -out=tfplan
```

3. Plan 결과를 사용자에게 보여주고 승인 요청

## Deploy (사용자 승인 후)

```bash
cd envs/dev && terraform apply tfplan
```

## Post-Deploy Verification

```bash
terraform output user_endpoints
kubectl get pods -A -l simulator-platform/oem
helm list -A | grep -v NAME
```

## Rollback (문제 발생 시)

```bash
# 특정 릴리스 롤백
terraform apply -replace='module.simulator_platform.module.helm_release["<oem>/<user>"].helm_release.simulator'
```
