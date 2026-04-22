# eks-simulator-helm

OEM/User별 시뮬레이터 스택을 배포하는 Helm 차트.

## Components (6)

| Deployment | Port | Scalable | Purpose |
|-----------|------|----------|---------|
| nginx-proxy | 80 | No | 리버스 프록시, Ingress 백엔드 |
| simulator-server | 8002 | Yes | 메인 시뮬레이션 엔진 |
| simulator-can | 8001 | No | CAN 버스 통신 |
| simulator-vehicle | 8003 | No | 차량 모델 |
| target-android | 8004 | No | Android 타겟 |
| target-cluster | 8005 | No | 클러스터 타겟 |

## Key Values

- `userId`, `oemId`: Terraform에서 주입, 모든 리소스 명명에 사용
- `imageRegistry`: ECR 레지스트리 주소
- `ingress.baseDomain`: FQDN 생성에 사용 (`{userId}.{oemId}.{baseDomain}`)
- `hybridNode.enabled`: Hybrid Node nodeSelector/toleration 토글

## Ingress Pattern

- 같은 OEM의 모든 User가 `group.name: ajt-{oemId}`로 하나의 ALB 공유
- HTTPS 443 리스닝, ACM 인증서 자동 연결
- Health check: `/health` 경로, 30초 간격

## Security Defaults

- `runAsNonRoot: true`, `runAsUser: 1000`
- `readOnlyRootFilesystem: true`
- `capabilities.drop: [ALL]`
